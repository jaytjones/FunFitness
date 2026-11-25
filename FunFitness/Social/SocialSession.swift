//
//  SocialSession.swift
//  FunFitness
//
//  The signed-in state of Friends (3.4 step 2): Sign in with Apple, the person's Friends profile,
//  sign-out, delete, and what happens when someone stops using their Apple ID with FunFitness.
//  Screens read `state`; all data goes through a `SocialService`, so tests drive this with
//  `InMemorySocialService` and fakes for the Apple ID store, credential check and iCloud status.
//
//  UNRELEASED — compiled only with INTERNAL_SOCIAL (Debug + Internal builds, never Release).
//

#if INTERNAL_SOCIAL
import Foundation
import AuthenticationServices
import CloudKit
import Security
import UserNotifications
import os

/// Where the Sign in with Apple user ID is kept on this device.
protocol AppleIDStoring: AnyObject {
    var appleUserID: String? { get set }
}

/// The Keychain (this device only): the user ID is an account identifier, so it isn't kept in
/// UserDefaults or synced.
final class KeychainAppleIDStore: AppleIDStoring {
    private let service = "com.jaytjones.FunFitness.friends"
    private let account = "appleUserID"

    var appleUserID: String? {
        get {
            var query = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
                  let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(baseQuery as CFDictionary)
            guard let newValue else { return }
            var item = baseQuery
            item[kSecValueData as String] = Data(newValue.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}

@MainActor
@Observable
final class SocialSession {
    enum State: Equatable {
        case checking
        case signedOut
        /// Signed in with Apple, but iCloud isn't available (Friends data lives in iCloud).
        case iCloudUnavailable
        case needsProfile
        case ready(SocialProfile)
        case failed(String)
    }

    static let shared = SocialSession(
        idStore: KeychainAppleIDStore(),
        makeService: { CloudKitSocialService(me: $0, containerIdentifier: PersistenceController.cloudKitContainerID) },
        isICloudAvailable: {
            let status = try? await CKContainer(identifier: PersistenceController.cloudKitContainerID).accountStatus()
            return status == .available
        },
        isCredentialValid: { userID in
            let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
            // Unknown (offline, error) counts as valid; only Apple saying revoked/not found signs out.
            return state != .revoked && state != .notFound
        }
    )

    private(set) var state: State = .checking
    private(set) var isWorking = false
    private(set) var service: (any SocialService)?

    // Friends and invites (step 3)
    private(set) var friends: [SocialProfile] = []
    private(set) var openInvites: [FriendInvite] = []
    /// The latest invite I created, to show its code and share it.
    private(set) var newInvite: FriendInvite?
    /// A short result line after entering a code ("You're friends with Sam!").
    private(set) var inviteMessage: String?
    /// A code from an invite link opened before Friends was ready; used once the profile exists.
    private(set) var pendingInviteCode: String?

    // Feed and high fives (step 4)
    private(set) var feed: [FeedEvent] = []
    private(set) var receivedHighFives: [HighFive] = []
    /// `HighFive.id`s sent from this device, to show them as sent.
    private(set) var sentHighFiveIDs: Set<String> = []
    /// The latest unlocks handed to `publishRecent`, re-used when sharing is turned on.
    private var lastPublishInput: FeedPublishing.Input?
    private var notificationsPrepared = false

    // Duels and leaderboard (step 5)
    private(set) var duels: [Duel] = []
    /// This week's Effort Points for me and friends who share theirs.
    private(set) var leaderboard: [PersonID: Double] = [:]
    /// Last weekly totals sent, by week key, so unchanged numbers aren't re-sent.
    private var postedEffort: [String: Double] = [:]
    private var lastEffortInput: (thisWeek: Double, lastWeek: Double)?

    /// Per person, so two Apple IDs on one device (or parallel tests) never share them.
    private enum Keys {
        static func sentHighFives(_ me: PersonID) -> String { "friends.sentHighFives.\(me.rawValue.prefix(16))" }
        static func published(_ me: PersonID) -> String { "friends.publishedKeys.\(me.rawValue.prefix(16))" }
        static func lastSeenNews(_ me: PersonID) -> String { "friends.lastSeenNews.\(me.rawValue.prefix(16))" }
    }

    private let idStore: AppleIDStoring
    private let makeService: (PersonID) -> any SocialService
    private let isICloudAvailable: () async -> Bool
    private let isCredentialValid: (String) async -> Bool
    private var revocationTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.jaytjones.FunFitness", category: "Friends")

    init(
        idStore: AppleIDStoring,
        makeService: @escaping (PersonID) -> any SocialService,
        isICloudAvailable: @escaping () async -> Bool,
        isCredentialValid: @escaping (String) async -> Bool
    ) {
        self.idStore = idStore
        self.makeService = makeService
        self.isICloudAvailable = isICloudAvailable
        self.isCredentialValid = isCredentialValid
    }

    /// At launch and whenever Friends is shown: re-checks the Apple credential, iCloud and profile.
    func refresh() async {
        guard let userID = idStore.appleUserID else {
            service = nil
            state = .signedOut
            return
        }
        guard await isCredentialValid(userID) else {
            await handleRevocation()
            return
        }
        await load(appleUserID: userID)
    }

    /// Listens for "Stop Using Apple ID" while the app runs (once; safe to call again).
    func observeRevocation() {
        guard revocationTask == nil else { return }
        revocationTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: ASAuthorizationAppleIDProvider.credentialRevokedNotification) {
                await self?.handleRevocation()
            }
        }
    }

    /// After a successful Sign in with Apple. Only the user ID is kept: no name or email.
    func signedIn(appleUserID: String) async {
        idStore.appleUserID = appleUserID
        await load(appleUserID: appleUserID)
    }

    func createProfile(name: String, emoji: String, styleID: String) async {
        guard let service, let displayName = SocialProfile.cleanedName(name) else { return }
        let profile = SocialProfile(id: service.me, displayName: displayName, avatarEmoji: emoji, styleID: styleID)
        await perform { try await service.saveProfile(profile) } onSuccess: { self.state = .ready(profile) }
        if case .ready = state, let code = pendingInviteCode {
            await acceptInvite(code: code)
        }
    }

    // MARK: Friends and invites (step 3)

    /// Finishes half-done invites, then reloads friends and open invites. Quiet on failure: the
    /// lists keep their last values (Friends refreshes again next time it's shown).
    func refreshFriends() async {
        guard let service, case .ready = state else { return }
        do {
            try await service.syncInvites()
            friends = try await service.friends()
            openInvites = try await service.openInvites()
            feed = try await service.feed()
            receivedHighFives = try await service.receivedHighFives()
            duels = try await service.duels()
            leaderboard = try await service.weeklyEffort(weekStart: Self.weekStart(of: Date()))
            // Seen in the app, so a later push doesn't announce it again.
            UserDefaults.standard.set(Date(), forKey: Keys.lastSeenNews(service.me))
            if !notificationsPrepared {
                try await service.prepareNotifications()
                notificationsPrepared = true
            }
        } catch {
            logger.error("Couldn't refresh friends: \(String(describing: error), privacy: .public)")
        }
    }

    func createInvite() async {
        guard let service else { return }
        inviteMessage = nil
        await perform {
            let invite = try await service.createInvite()
            self.newInvite = invite
            self.openInvites.insert(invite, at: 0)
        }
    }

    func dismissNewInvite() { newInvite = nil }

    /// A typed code or an opened invite link. Before Friends is ready, the code waits.
    func acceptInvite(code: String) async {
        guard let normalized = FriendInvite.normalizedCode(code) else {
            inviteMessage = "That doesn't look like an invite code. Codes are 6 letters and numbers."
            return
        }
        guard let service, case .ready = state else {
            pendingInviteCode = normalized
            return
        }
        pendingInviteCode = nil
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await service.acceptInvite(code: normalized) {
            case .friends(let friend):
                inviteMessage = "You're friends with \(friend.displayName)!"
                friends = try await service.friends()
            case .waitingForInviter:
                inviteMessage = "Invite accepted! You'll be friends as soon as they next open FunFitness."
            }
        } catch let error as SocialError {
            inviteMessage = Self.message(for: error)
        } catch {
            logger.error("Couldn't accept invite: \(String(describing: error), privacy: .public)")
            inviteMessage = Self.message(for: error)
        }
    }

    /// Opened from a funfitness://friend/<code> link.
    func handleInviteLink(_ url: URL) async {
        guard url.scheme == "funfitness", url.host() == "friend" else { return }
        await acceptInvite(code: url.absoluteString)
    }

    // MARK: Feed and high fives (step 4)

    /// Publishes recent unlocks and streak milestones (only kinds the person shares; each once).
    /// Called whenever badges, challenges or the streak change, and again when sharing is turned on.
    func publishRecent(_ input: FeedPublishing.Input) async {
        lastPublishInput = input
        guard let service, case .ready = state else { return }
        var published = Set(UserDefaults.standard.stringArray(forKey: Keys.published(service.me)) ?? [])
        published = FeedPublishing.forgetBrokenStreaks(published, currentStreak: input.currentStreak)
        for (kind, date) in FeedPublishing.toPublish(input, alreadyPublished: published) {
            do {
                if try await service.publish(kind, at: date) { published.insert(kind.key) }
            } catch {
                logger.error("Couldn't publish \(kind.key, privacy: .public): \(String(describing: error), privacy: .public)")
                break
            }
        }
        UserDefaults.standard.set(Array(published), forKey: Keys.published(service.me))
    }

    func sendHighFive(to person: PersonID, for eventKey: String?) async {
        guard let service else { return }
        let id = HighFive(from: service.me, to: person, eventKey: eventKey, date: Date()).id
        sentHighFiveIDs.insert(id)
        do {
            try await service.sendHighFive(to: person, for: eventKey)
            UserDefaults.standard.set(Array(sentHighFiveIDs), forKey: Keys.sentHighFives(service.me))
        } catch {
            sentHighFiveIDs.remove(id)
            inviteMessage = Self.message(for: error)
        }
    }

    func hasSentHighFive(to person: PersonID, for eventKey: String?) -> Bool {
        guard let me = service?.me else { return false }
        return sentHighFiveIDs.contains(HighFive(from: me, to: person, eventKey: eventKey, date: Date()).id)
    }

    /// A friend's Friends data changed (silent push) or the app is checking in. Loads the feed and
    /// high fives; in the background, posts a local notification for each new item (at most 3),
    /// since iCloud can't put names in its own alerts. Returns whether anything was new.
    @discardableResult
    func checkForNews(postNotifications: Bool) async -> Bool {
        if service == nil { await refresh() }
        guard let service, case .ready = state else { return false }
        do {
            friends = try await service.friends()
            feed = try await service.feed()
            receivedHighFives = try await service.receivedHighFives()
            duels = try await service.duels()
        } catch {
            logger.error("Couldn't check Friends news: \(String(describing: error), privacy: .public)")
            return false
        }
        let lastSeen = UserDefaults.standard.object(forKey: Keys.lastSeenNews(service.me)) as? Date ?? Date() - 86_400
        let names = Dictionary(friends.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        let lines = FeedText.newsLines(highFives: receivedHighFives, events: feed, duels: duels, me: service.me,
                                       names: names, since: lastSeen)
        UserDefaults.standard.set(Date(), forKey: Keys.lastSeenNews(service.me))
        if postNotifications {
            for (index, line) in lines.prefix(3).enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "FunFitness Friends"
                content.body = line
                content.sound = .default
                try? await UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: "friends-news-\(Date().timeIntervalSince1970)-\(index)", content: content, trigger: nil))
            }
        }
        return !lines.isEmpty
    }

    // MARK: Duels and leaderboard (step 5)

    static func weekStart(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    /// Publishes this week's and last week's Effort Points (last week too, so late entries still
    /// count toward a duel that just ended). Only when weekly effort is shared and the number moved.
    func postEffort(thisWeek: Double, lastWeek: Double, now: Date = Date()) async {
        lastEffortInput = (thisWeek, lastWeek)
        guard let service, case .ready(let profile) = state, profile.sharing.shareWeeklyEffort else { return }
        let weeks = [(Self.weekStart(of: now), thisWeek), (Self.weekStart(of: now - 7 * 86_400), lastWeek)]
        for (start, points) in weeks {
            let key = SocialWeek.key(for: start)
            let rounded = (points * 10).rounded() / 10
            guard postedEffort[key] != rounded else { continue }
            do {
                try await service.postWeeklyEffort(rounded, weekStart: start)
                postedEffort[key] = rounded
            } catch {
                logger.error("Couldn't post weekly effort: \(String(describing: error), privacy: .public)")
                return
            }
        }
        leaderboard[service.me] = (thisWeek * 10).rounded() / 10
    }

    /// A duel for this week. Needs weekly effort shared (it's the score).
    func challenge(_ person: PersonID) async {
        guard let service, case .ready(let profile) = state else { return }
        guard profile.sharing.shareWeeklyEffort else {
            inviteMessage = Self.message(for: SocialError.sharingOff)
            return
        }
        await perform {
            let duel = try await service.challenge(person, weekStart: Self.weekStart(of: Date()))
            self.duels.insert(duel, at: 0)
        }
    }

    func respond(to duel: Duel, accept: Bool) async {
        guard let service else { return }
        if accept, case .ready(let profile) = state, !profile.sharing.shareWeeklyEffort {
            inviteMessage = Self.message(for: SocialError.sharingOff)
            return
        }
        await perform {
            let updated = try await service.respond(to: duel.id, accept: accept)
            if let index = self.duels.firstIndex(where: { $0.id == duel.id }) { self.duels[index] = updated }
        }
    }

    /// Duels worth showing: this week's and last week's (last week's show their result).
    func visibleDuels(now: Date = Date()) -> [Duel] {
        let lastWeek = Self.weekStart(of: now - 7 * 86_400)
        return duels.filter { $0.weekStart >= lastWeek }
    }

    func hasDuelThisWeek(with person: PersonID, now: Date = Date()) -> Bool {
        let week = SocialWeek.key(for: Self.weekStart(of: now))
        return duels.contains { $0.people.contains(person) && $0.status != .declined
            && SocialWeek.key(for: $0.weekStart) == week }
    }

    func removeFriend(_ person: PersonID) async {
        guard let service else { return }
        await perform { try await service.removeFriend(person) } onSuccess: {
            self.friends.removeAll { $0.id == person }
        }
    }

    func block(_ person: PersonID) async {
        guard let service else { return }
        await perform { try await service.block(person) } onSuccess: {
            self.friends.removeAll { $0.id == person }
        }
    }

    /// Saves edits (name, emoji, style, sharing). Shows the change at once and puts it back if
    /// saving fails.
    func update(_ profile: SocialProfile) async {
        guard let service, case .ready(let previous) = state, previous != profile else { return }
        state = .ready(profile)
        await perform { try await service.saveProfile(profile) } onFailure: { self.state = .ready(previous) }
        // Sharing just turned on: publish recent unlocks and this week's effort now.
        if profile.sharing != previous.sharing {
            if let input = lastPublishInput { await publishRecent(input) }
            if let effort = lastEffortInput {
                postedEffort = [:]
                await postEffort(thisWeek: effort.thisWeek, lastWeek: effort.lastWeek)
            }
        }
    }

    /// Forgets the Apple ID on this device. The Friends profile stays for when they sign back in.
    func signOut() {
        idStore.appleUserID = nil
        service = nil
        state = .signedOut
        friends = []
        openInvites = []
        newInvite = nil
        inviteMessage = nil
        feed = []
        receivedHighFives = []
        duels = []
        leaderboard = [:]
        postedEffort = [:]
    }

    /// Removes the Friends profile and everything shared from it, then signs out.
    func deleteProfile() async {
        guard let service else { return }
        await perform { try await service.deleteProfile() } onSuccess: { self.signOut() }
    }

    /// Apple says the person stopped using their Apple ID with FunFitness: treat it like deleting
    /// the Friends profile (best effort; iCloud may be unreachable), then sign out.
    func handleRevocation() async {
        if let userID = idStore.appleUserID {
            let service = self.service ?? makeService(PersonID(appleUserID: userID))
            do { try await service.deleteProfile() } catch {
                logger.error("Couldn't remove the Friends profile after revocation: \(String(describing: error), privacy: .public)")
            }
        }
        signOut()
    }

    // MARK: Private

    private func load(appleUserID: String) async {
        state = .checking
        guard await isICloudAvailable() else {
            service = nil
            state = .iCloudUnavailable
            return
        }
        let service = makeService(PersonID(appleUserID: appleUserID))
        self.service = service
        sentHighFiveIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.sentHighFives(service.me)) ?? [])
        do {
            state = try await service.profile().map(State.ready) ?? .needsProfile
        } catch {
            logger.error("Couldn't load the Friends profile: \(String(describing: error), privacy: .public)")
            state = .failed(Self.message(for: error))
        }
    }

    private func perform(
        _ work: () async throws -> Void,
        onSuccess: () -> Void = {},
        onFailure: () -> Void = {}
    ) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
            onSuccess()
        } catch {
            logger.error("Friends request failed: \(String(describing: error), privacy: .public)")
            onFailure()
            state = .failed(Self.message(for: error))
        }
    }

    #if DEBUG
    /// Development-schema setup (see `CloudKitSocialService.initializeSchema`). Needs iCloud, not
    /// Sign in with Apple. The result goes to the console under the "Friends" category.
    static func initializeFriendsSchema() async {
        let logger = Logger(subsystem: "com.jaytjones.FunFitness", category: "Friends")
        let service = CloudKitSocialService(me: PersonID(appleUserID: "schema"),
                                            containerIdentifier: PersistenceController.cloudKitContainerID)
        do {
            try await service.initializeSchema()
            logger.notice("Friends schema initialized: 11 record types saved and removed in Development")
        } catch {
            logger.error("Friends schema init failed: \(String(describing: error), privacy: .public)")
        }
    }
    #endif

    static func message(for error: Error) -> String {
        if let social = error as? SocialError {
            switch social {
            case .inviteNotFound: return "That code didn't work. It may have been used already. Ask for a new one."
            case .inviteExpired: return "That invite has expired. Ask for a new one."
            case .ownInvite: return "That's your own invite. Send it to a friend instead."
            case .alreadyFriends: return "You're already friends."
            case .blocked: return "You can't add this person."
            case .sharingOff: return "Turn on Weekly Effort Points in What Friends See to duel. It's the score."
            case .duelNotFound: return "That duel isn't waiting on you any more."
            default: break
            }
        }
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure: return "No connection. Friends needs the internet."
            case .notAuthenticated: return "Sign in to iCloud in Settings to use Friends."
            case .quotaExceeded: return "Your iCloud storage is full."
            default: break
            }
        }
        return "Something went wrong. Try again in a moment."
    }
}
#endif
