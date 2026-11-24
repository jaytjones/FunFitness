//
//  SocialService.swift
//  FunFitness
//
//  The one door to Friends data (3.4). Screens talk only to `SocialService`; CloudKit lives behind
//  `CloudKitSocialService` (next step) and a cross-platform backend can replace it later without
//  touching the UI. `InMemorySocialService` is a complete, rule-enforcing stand-in for tests and
//  previews: several people can share one `InMemorySocialStore` to act out invites and duels.
//
//  UNRELEASED — compiled only with INTERNAL_SOCIAL (Debug + Internal builds, never Release).
//

#if INTERNAL_SOCIAL
import Foundation

nonisolated enum SocialError: Error, Equatable, Sendable {
    /// No social profile yet (sign in and create one first).
    case noProfile
    case inviteNotFound
    case inviteExpired
    /// Accepting your own invite.
    case ownInvite
    case alreadyFriends
    case notFriends
    /// The other person blocked you, or you blocked them.
    case blocked
    /// The action needs a sharing setting that's off (e.g. weekly effort for duels).
    case sharingOff
    case duelNotFound
    /// Built in a later 3.4 step (the CloudKit service grows step by step).
    case notAvailableYet
}

/// The result of entering someone's invite code or link.
nonisolated enum InviteAcceptance: Equatable, Sendable {
    /// Friends right away (the in-memory service; or the inviter's app already finished its side).
    case friends(SocialProfile)
    /// Our side is done; it completes when the inviter's app next syncs (shared zones need both
    /// people to add each other to their own share).
    case waitingForInviter
}

/// Everything Friends can do. Every call acts as the signed-in person (`me`).
protocol SocialService: Sendable {
    var me: PersonID { get }

    // Profile
    func profile() async throws -> SocialProfile?
    func saveProfile(_ profile: SocialProfile) async throws
    /// Removes the profile and everything it published; friends no longer see this person.
    func deleteProfile() async throws

    // Friends
    func createInvite() async throws -> FriendInvite
    func acceptInvite(code: String) async throws -> InviteAcceptance
    /// My invites nobody has used yet (unexpired), newest first.
    func openInvites() async throws -> [FriendInvite]
    /// Finishes any half-done invite handshakes (both directions). Call on refresh.
    func syncInvites() async throws
    /// Friends who aren't blocked in either direction, by name.
    func friends() async throws -> [SocialProfile]
    func removeFriend(_ person: PersonID) async throws
    func block(_ person: PersonID) async throws

    // Feed
    /// Publishes an event (dated when it happened) if my sharing allows its kind; returns whether
    /// it was published. The same kind again replaces the earlier one.
    @discardableResult func publish(_ kind: FeedEvent.Kind, at date: Date) async throws -> Bool
    /// Friends' events from the last 30 days, newest first, only kinds each friend currently shares.
    func feed() async throws -> [FeedEvent]
    /// At most one per friend and feed item (sending again changes nothing).
    func sendHighFive(to person: PersonID, for eventKey: String?) async throws
    func receivedHighFives() async throws -> [HighFive]
    /// Sets up "a friend's Friends data changed" pushes (no-op where there are none).
    func prepareNotifications() async throws

    // Duels (Effort Points)
    func challenge(_ person: PersonID, weekStart: Date) async throws -> Duel
    func respond(to duelID: UUID, accept: Bool) async throws -> Duel
    /// Posts my Effort Points for a week to each of my active duels that week.
    func postWeeklyEffort(_ points: Double, weekStart: Date) async throws
    func duels() async throws -> [Duel]
}

extension SocialService {
    @discardableResult
    func publish(_ kind: FeedEvent.Kind) async throws -> Bool { try await publish(kind, at: Date()) }
}

// MARK: - In-memory implementation

/// The shared "server" for `InMemorySocialService`: one per test or preview.
actor InMemorySocialStore {
    var profiles: [PersonID: SocialProfile] = [:]
    var invites: [String: FriendInvite] = [:]
    var friendships: [Friendship] = []
    var events: [FeedEvent] = []
    var highFives: [HighFive] = []
    var duels: [UUID: Duel] = [:]

    init() {}

    func friendship(between a: PersonID, and b: PersonID) -> Friendship? {
        friendships.first { $0.includes(a) && $0.includes(b) }
    }

    func setProfile(_ profile: SocialProfile) { profiles[profile.id] = profile }

    func removeEverything(of person: PersonID) {
        profiles[person] = nil
        invites = invites.filter { $0.value.from != person }
        friendships.removeAll { $0.includes(person) }
        events.removeAll { $0.author == person }
        highFives.removeAll { $0.from == person || $0.to == person }
        duels = duels.filter { !$0.value.people.contains(person) }
    }

    func addInvite(_ invite: FriendInvite) { invites[invite.code] = invite }
    func removeInvite(_ code: String) { invites[code] = nil }
    func addFriendship(_ friendship: Friendship) { friendships.append(friendship) }
    func removeFriendship(between a: PersonID, and b: PersonID) {
        friendships.removeAll { $0.includes(a) && $0.includes(b) }
    }
    func setBlocked(between a: PersonID, and b: PersonID, by blocker: PersonID) {
        guard let index = friendships.firstIndex(where: { $0.includes(a) && $0.includes(b) }) else { return }
        friendships[index].blockedBy = blocker
    }
    func addEvent(_ event: FeedEvent) {
        events.removeAll { $0.id == event.id }
        events.append(event)
    }
    func addHighFive(_ highFive: HighFive) {
        guard !highFives.contains(where: { $0.id == highFive.id }) else { return }
        highFives.append(highFive)
    }
    func setDuel(_ duel: Duel) { duels[duel.id] = duel }
}

/// Applies every Friends rule over an `InMemorySocialStore`, acting as `me`.
struct InMemorySocialService: SocialService {
    let me: PersonID
    let store: InMemorySocialStore
    var now: @Sendable () -> Date = { Date() }

    init(me: PersonID, store: InMemorySocialStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.me = me
        self.store = store
        self.now = now
    }

    func profile() async throws -> SocialProfile? { await store.profiles[me] }

    func saveProfile(_ profile: SocialProfile) async throws {
        precondition(profile.id == me, "Only your own profile can be saved")
        await store.setProfile(profile)
    }

    func deleteProfile() async throws { await store.removeEverything(of: me) }

    func createInvite() async throws -> FriendInvite {
        try await requireProfile()
        var generator = SystemRandomNumberGenerator()
        var code = FriendInvite.makeCode(using: &generator)
        while await store.invites[code] != nil { code = FriendInvite.makeCode(using: &generator) }
        let created = now()
        let invite = FriendInvite(code: code, from: me, createdAt: created, expiresAt: created + FriendInvite.lifetime)
        await store.addInvite(invite)
        return invite
    }

    func acceptInvite(code input: String) async throws -> InviteAcceptance {
        try await requireProfile()
        guard let code = FriendInvite.normalizedCode(input), let invite = await store.invites[code] else {
            throw SocialError.inviteNotFound
        }
        guard !invite.isExpired(at: now()) else { throw SocialError.inviteExpired }
        guard invite.from != me else { throw SocialError.ownInvite }
        if let existing = await store.friendship(between: me, and: invite.from) {
            throw existing.isBlocked ? SocialError.blocked : SocialError.alreadyFriends
        }
        guard let friend = await store.profiles[invite.from] else { throw SocialError.inviteNotFound }
        await store.addFriendship(Friendship(id: UUID(), people: [me, invite.from], since: now()))
        await store.removeInvite(code)   // one use
        return .friends(friend)
    }

    func openInvites() async throws -> [FriendInvite] {
        let date = now()
        return await store.invites.values
            .filter { $0.from == me && !$0.isExpired(at: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Nothing to finish: the in-memory store completes invites at once.
    func syncInvites() async throws {}

    func friends() async throws -> [SocialProfile] {
        let ids = await activeFriendIDs()
        let profiles = await store.profiles
        return ids.compactMap { profiles[$0] }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func removeFriend(_ person: PersonID) async throws {
        await store.removeFriendship(between: me, and: person)
    }

    func block(_ person: PersonID) async throws {
        if await store.friendship(between: me, and: person) == nil {
            // Blocking someone you aren't friends with still stops future invites between you.
            await store.addFriendship(Friendship(id: UUID(), people: [me, person], since: now()))
        }
        await store.setBlocked(between: me, and: person, by: me)
    }

    @discardableResult
    func publish(_ kind: FeedEvent.Kind, at date: Date) async throws -> Bool {
        let profile = try await requireProfile()
        guard kind.isShared(by: profile.sharing) else { return false }
        await store.addEvent(FeedEvent(author: me, kind: kind, date: date))
        return true
    }

    func feed() async throws -> [FeedEvent] {
        let friends = Set(await activeFriendIDs())
        let profiles = await store.profiles
        // Sharing is checked again at read time, so turning a setting off hides older events too.
        let cutoff = now() - FeedEvent.feedWindow
        return await store.events
            .filter { event in
                event.date >= cutoff && friends.contains(event.author)
                    && profiles[event.author].map { event.kind.isShared(by: $0.sharing) } == true
            }
            .sorted { $0.date > $1.date }
    }

    func sendHighFive(to person: PersonID, for eventKey: String?) async throws {
        try await requireFriend(person)
        await store.addHighFive(HighFive(from: me, to: person, eventKey: eventKey, date: now()))
    }

    func prepareNotifications() async throws {}

    func receivedHighFives() async throws -> [HighFive] {
        let friends = Set(await activeFriendIDs())
        return await store.highFives
            .filter { $0.to == me && friends.contains($0.from) }
            .sorted { $0.date > $1.date }
    }

    func challenge(_ person: PersonID, weekStart: Date) async throws -> Duel {
        let profile = try await requireProfile()
        try await requireFriend(person)
        guard profile.sharing.shareWeeklyEffort else { throw SocialError.sharingOff }
        let duel = Duel(id: UUID(), challenger: me, opponent: person, weekStart: weekStart, status: .pending)
        await store.setDuel(duel)
        return duel
    }

    func respond(to duelID: UUID, accept: Bool) async throws -> Duel {
        guard var duel = await store.duels[duelID], duel.opponent == me, duel.status == .pending else {
            throw SocialError.duelNotFound
        }
        if accept {
            guard try await requireProfile().sharing.shareWeeklyEffort else { throw SocialError.sharingOff }
        }
        duel.status = accept ? .active : .declined
        await store.setDuel(duel)
        return duel
    }

    func postWeeklyEffort(_ points: Double, weekStart: Date) async throws {
        guard try await requireProfile().sharing.shareWeeklyEffort else { throw SocialError.sharingOff }
        let calendar = Calendar.current
        for var duel in await store.duels.values
        where duel.people.contains(me) && duel.status == .active
            && calendar.isDate(duel.weekStart, equalTo: weekStart, toGranularity: .weekOfYear) {
            duel.points[me] = max(0, points)
            await store.setDuel(duel)
        }
    }

    func duels() async throws -> [Duel] {
        let friends = Set(await activeFriendIDs())
        return await store.duels.values
            .filter { $0.people.contains(me) && $0.people.subtracting([me]).isSubset(of: friends) }
            .sorted { $0.weekStart > $1.weekStart }
    }

    // MARK: Helpers

    @discardableResult
    private func requireProfile() async throws -> SocialProfile {
        guard let profile = await store.profiles[me] else { throw SocialError.noProfile }
        return profile
    }

    private func requireFriend(_ person: PersonID) async throws {
        guard let friendship = await store.friendship(between: me, and: person) else { throw SocialError.notFriends }
        guard !friendship.isBlocked else { throw SocialError.blocked }
    }

    private func activeFriendIDs() async -> [PersonID] {
        await store.friendships
            .filter { $0.includes(me) && !$0.isBlocked }
            .compactMap { $0.other(than: me) }
    }
}
#endif
