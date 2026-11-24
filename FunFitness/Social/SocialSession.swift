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
    }

    /// Saves edits (name, emoji, style, sharing). Shows the change at once and puts it back if
    /// saving fails.
    func update(_ profile: SocialProfile) async {
        guard let service, case .ready(let previous) = state, previous != profile else { return }
        state = .ready(profile)
        await perform { try await service.saveProfile(profile) } onFailure: { self.state = .ready(previous) }
    }

    /// Forgets the Apple ID on this device. The Friends profile stays for when they sign back in.
    func signOut() {
        idStore.appleUserID = nil
        service = nil
        state = .signedOut
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

    static func message(for error: Error) -> String {
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
