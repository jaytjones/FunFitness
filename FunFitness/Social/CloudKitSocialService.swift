//
//  CloudKitSocialService.swift
//  FunFitness
//
//  Friends on CloudKit with shared zones (Jay, 2026-11-24): each person keeps a "Friends" zone in
//  their own private database and shares the whole zone (one zone-wide CKShare, no public access)
//  with each friend, so iCloud itself decides who can read it. SwiftData's own sync zone is
//  untouched. A second, unshared zone ("FriendsLocal") holds bookkeeping friends must never see:
//  open invites, invites waiting on the other side, and blocked people.
//
//  Invites (step 3) are a handshake, because each side must add the other to its own share:
//  1. Ana creates an invite: a public `FriendInvite` record named after the code, holding only the
//     code, expiry, her CloudKit user record name and her share URL (useless to anyone she hasn't
//     added as a participant).
//  2. Bob enters the code: his app adds Ana to his share and writes a public `InviteResponse`
//     (same code) with his user record name and share URL.
//  3. Ana's app, on its next sync, adds Bob to her share, accepts Bob's share and deletes the
//     invite. Bob's app then accepts Ana's share and deletes the response.
//  Every lookup is by record ID, so no public-database indexes are needed.
//  Feed, high fives and duels arrive in steps 4–5 and throw `.notAvailableYet` until then.
//
//  UNRELEASED — compiled only with INTERNAL_SOCIAL (Debug + Internal builds, never Release).
//

#if INTERNAL_SOCIAL
import Foundation
import CloudKit

/// Record names, field names and mappings, kept pure so they're unit-tested without iCloud.
nonisolated enum SocialRecords {
    static let zoneName = "Friends"
    static let localZoneName = "FriendsLocal"
    static let profileType = "SocialProfile"
    static let profileRecordName = "profile"
    static let shareTitle = "FunFitness Friends"

    // Public database (step 3)
    static let inviteType = "FriendInvite"
    static let responseType = "InviteResponse"
    // FriendsLocal zone (step 3)
    static let outgoingType = "OutgoingInvite"
    static let pendingType = "PendingAcceptance"
    static let blockedType = "BlockedPerson"

    static func inviteRecordName(_ code: String) -> String { "invite-\(code)" }
    static func responseRecordName(_ code: String) -> String { "response-\(code)" }
    static func pendingRecordName(_ code: String) -> String { "pending-\(code)" }
    static func blockedRecordName(_ userRecordName: String) -> String { "blocked-\(userRecordName)" }

    enum Field {
        static let personID = "personID"
        static let displayName = "displayName"
        static let avatarEmoji = "avatarEmoji"
        static let styleID = "styleID"
        static let shareUnlocks = "shareUnlocks"
        static let shareStreak = "shareStreak"
        static let shareWeeklyEffort = "shareWeeklyEffort"
        static let code = "code"
        static let createdAt = "createdAt"
        static let expiresAt = "expiresAt"
        static let userRecordName = "userRecordName"
        static let shareURL = "shareURL"
    }

    static func apply(_ profile: SocialProfile, to record: CKRecord) {
        record[Field.personID] = profile.id.rawValue
        record[Field.displayName] = profile.displayName
        record[Field.avatarEmoji] = profile.avatarEmoji
        record[Field.styleID] = profile.styleID
        record[Field.shareUnlocks] = profile.sharing.shareUnlocks
        record[Field.shareStreak] = profile.sharing.shareStreak
        record[Field.shareWeeklyEffort] = profile.sharing.shareWeeklyEffort
    }

    /// nil for a record that isn't a usable profile. Missing sharing fields read as off.
    static func profile(from record: CKRecord) -> SocialProfile? {
        guard record.recordType == profileType,
              let id = record[Field.personID] as? String,
              let name = record[Field.displayName] as? String else { return nil }
        return SocialProfile(
            id: PersonID(rawValue: id),
            displayName: name,
            avatarEmoji: record[Field.avatarEmoji] as? String ?? "🙂",
            styleID: record[Field.styleID] as? String ?? StyleID.default.rawValue,
            sharing: SharingSettings(
                shareUnlocks: record[Field.shareUnlocks] as? Bool ?? false,
                shareStreak: record[Field.shareStreak] as? Bool ?? false,
                shareWeeklyEffort: record[Field.shareWeeklyEffort] as? Bool ?? false
            )
        )
    }

    /// The public half of an invite or response: who it's from and where their share is.
    struct Handshake: Equatable, Sendable {
        let code: String
        let userRecordName: String
        let shareURL: URL
        var createdAt: Date?
        var expiresAt: Date?
    }

    static func apply(_ handshake: Handshake, to record: CKRecord) {
        record[Field.code] = handshake.code
        record[Field.userRecordName] = handshake.userRecordName
        record[Field.shareURL] = handshake.shareURL.absoluteString
        if let createdAt = handshake.createdAt { record[Field.createdAt] = createdAt }
        if let expiresAt = handshake.expiresAt { record[Field.expiresAt] = expiresAt }
    }

    static func handshake(from record: CKRecord) -> Handshake? {
        guard let code = record[Field.code] as? String,
              let user = record[Field.userRecordName] as? String,
              let urlString = record[Field.shareURL] as? String,
              let url = URL(string: urlString) else { return nil }
        return Handshake(
            code: code, userRecordName: user, shareURL: url,
            createdAt: record[Field.createdAt] as? Date, expiresAt: record[Field.expiresAt] as? Date
        )
    }
}

struct CloudKitSocialService: SocialService {
    let me: PersonID
    private let container: CKContainer
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    private static let zoneID = CKRecordZone.ID(zoneName: SocialRecords.zoneName, ownerName: CKCurrentUserDefaultName)
    private static let localZoneID = CKRecordZone.ID(zoneName: SocialRecords.localZoneName, ownerName: CKCurrentUserDefaultName)
    private static let profileID = CKRecord.ID(recordName: SocialRecords.profileRecordName, zoneID: zoneID)
    private static let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)

    init(me: PersonID, containerIdentifier: String) {
        self.me = me
        container = CKContainer(identifier: containerIdentifier)
    }

    // MARK: Profile (step 2)

    func profile() async throws -> SocialProfile? {
        guard let record = try await existingRecord(Self.profileID, in: privateDB) else { return nil }
        return SocialRecords.profile(from: record)
    }

    func saveProfile(_ profile: SocialProfile) async throws {
        precondition(profile.id == me, "Only your own profile can be saved")
        _ = try await ensureZoneAndShare()
        let record = try await existingRecord(Self.profileID, in: privateDB)
            ?? CKRecord(recordType: SocialRecords.profileType, recordID: Self.profileID)
        SocialRecords.apply(profile, to: record)
        try await save([record], in: privateDB, policy: .changedKeys)
    }

    /// Withdraws open invites, leaves every friend's share, then deletes both zones (deleting the
    /// Friends zone deletes its share, so every friend loses access at once).
    func deleteProfile() async throws {
        for record in try await localRecords(ofType: SocialRecords.outgoingType) {
            if let code = record[SocialRecords.Field.code] as? String {
                try? await delete([CKRecord.ID(recordName: SocialRecords.inviteRecordName(code))], in: publicDB)
            }
        }
        for zone in try await friendZones() {
            try? await delete([CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone)], in: sharedDB)
        }
        do {
            _ = try await privateDB.modifyRecordZones(saving: [], deleting: [Self.zoneID, Self.localZoneID])
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem || error.code == .partialFailure {
            // Nothing (or not everything) to delete.
        }
    }

    // MARK: Invites (step 3)

    func createInvite() async throws -> FriendInvite {
        guard try await profile() != nil else { throw SocialError.noProfile }
        let share = try await ensureZoneAndShare()
        guard let shareURL = share.url else { throw SocialError.inviteNotFound }
        let myRecordName = try await container.userRecordID().recordName

        var generator = SystemRandomNumberGenerator()
        let created = Date()
        let invite = FriendInvite(
            code: FriendInvite.makeCode(using: &generator), from: me,
            createdAt: created, expiresAt: created + FriendInvite.lifetime
        )
        let publicRecord = CKRecord(recordType: SocialRecords.inviteType,
                                    recordID: CKRecord.ID(recordName: SocialRecords.inviteRecordName(invite.code)))
        SocialRecords.apply(SocialRecords.Handshake(code: invite.code, userRecordName: myRecordName, shareURL: shareURL,
                                                    createdAt: created, expiresAt: invite.expiresAt), to: publicRecord)
        try await save([publicRecord], in: publicDB, policy: .ifServerRecordUnchanged)

        try await ensureLocalZone()
        let local = CKRecord(recordType: SocialRecords.outgoingType,
                             recordID: CKRecord.ID(recordName: SocialRecords.inviteRecordName(invite.code), zoneID: Self.localZoneID))
        local[SocialRecords.Field.code] = invite.code
        local[SocialRecords.Field.createdAt] = created
        local[SocialRecords.Field.expiresAt] = invite.expiresAt
        try await save([local], in: privateDB, policy: .ifServerRecordUnchanged)
        return invite
    }

    func acceptInvite(code input: String) async throws -> InviteAcceptance {
        guard try await profile() != nil else { throw SocialError.noProfile }
        guard let code = FriendInvite.normalizedCode(input),
              let record = try await existingRecord(CKRecord.ID(recordName: SocialRecords.inviteRecordName(code)), in: publicDB),
              let invite = SocialRecords.handshake(from: record) else {
            throw SocialError.inviteNotFound
        }
        if let expires = invite.expiresAt, expires <= Date() { throw SocialError.inviteExpired }
        let myRecordName = try await container.userRecordID().recordName
        guard invite.userRecordName != myRecordName else { throw SocialError.ownInvite }
        guard try await !isBlocked(invite.userRecordName) else { throw SocialError.blocked }
        guard try await !friendZones().contains(where: { $0.ownerName == invite.userRecordName }) else {
            throw SocialError.alreadyFriends
        }

        // Our side: let the inviter read our Friends zone, then tell them where it is.
        let share = try await ensureZoneAndShare()
        try await addParticipant(invite.userRecordName, to: share)
        guard let myShareURL = share.url else { throw SocialError.inviteNotFound }
        let response = CKRecord(recordType: SocialRecords.responseType,
                                recordID: CKRecord.ID(recordName: SocialRecords.responseRecordName(code)))
        SocialRecords.apply(SocialRecords.Handshake(code: code, userRecordName: myRecordName, shareURL: myShareURL,
                                                    createdAt: Date()), to: response)
        do {
            try await save([response], in: publicDB, policy: .ifServerRecordUnchanged)
        } catch let error as CKError where error.code == .serverRecordChanged {
            throw SocialError.inviteNotFound   // someone else already used this code
        }

        // Remember to accept the inviter's share once they've added us.
        try await ensureLocalZone()
        let pending = CKRecord(recordType: SocialRecords.pendingType,
                               recordID: CKRecord.ID(recordName: SocialRecords.pendingRecordName(code), zoneID: Self.localZoneID))
        SocialRecords.apply(SocialRecords.Handshake(code: code, userRecordName: invite.userRecordName,
                                                    shareURL: invite.shareURL, createdAt: Date()), to: pending)
        try await save([pending], in: privateDB, policy: .allKeys)
        return .waitingForInviter
    }

    func openInvites() async throws -> [FriendInvite] {
        let now = Date()
        return try await localRecords(ofType: SocialRecords.outgoingType).compactMap { record -> FriendInvite? in
            guard let code = record[SocialRecords.Field.code] as? String,
                  let created = record[SocialRecords.Field.createdAt] as? Date,
                  let expires = record[SocialRecords.Field.expiresAt] as? Date, expires > now else { return nil }
            return FriendInvite(code: code, from: me, createdAt: created, expiresAt: expires)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func syncInvites() async throws {
        guard try await existingRecord(Self.profileID, in: privateDB) != nil else { return }
        let now = Date()

        // Invites I sent: finish any a friend has answered; withdraw expired ones.
        for record in try await localRecords(ofType: SocialRecords.outgoingType) {
            guard let code = record[SocialRecords.Field.code] as? String else { continue }
            let inviteID = CKRecord.ID(recordName: SocialRecords.inviteRecordName(code))
            if let expires = record[SocialRecords.Field.expiresAt] as? Date, expires <= now {
                try? await delete([inviteID], in: publicDB)
                try await delete([record.recordID], in: privateDB)
                continue
            }
            guard let responseRecord = try await existingRecord(
                CKRecord.ID(recordName: SocialRecords.responseRecordName(code)), in: publicDB),
                  let response = SocialRecords.handshake(from: responseRecord) else { continue }
            if try await !isBlocked(response.userRecordName) {
                try await addParticipant(response.userRecordName, to: ensureZoneAndShare())
                try await acceptShare(at: response.shareURL)
            }
            try? await delete([inviteID], in: publicDB)
            try await delete([record.recordID], in: privateDB)
        }

        // Invites I accepted: join the inviter's share once they've added me.
        for record in try await localRecords(ofType: SocialRecords.pendingType) {
            guard let pending = SocialRecords.handshake(from: record) else { continue }
            do {
                try await acceptShare(at: pending.shareURL)
            } catch {
                // Not added yet (the inviter hasn't opened the app). Give up after the invite lifetime.
                if let created = pending.createdAt, now.timeIntervalSince(created) > FriendInvite.lifetime {
                    try? await delete([CKRecord.ID(recordName: SocialRecords.responseRecordName(pending.code))], in: publicDB)
                    try await delete([record.recordID], in: privateDB)
                }
                continue
            }
            try? await delete([CKRecord.ID(recordName: SocialRecords.responseRecordName(pending.code))], in: publicDB)
            try await delete([record.recordID], in: privateDB)
        }
    }

    // MARK: Friends (step 3)

    /// Friends = the Friends zones others have shared with me, minus anyone I've blocked.
    func friends() async throws -> [SocialProfile] {
        let blocked = try await blockedRecordNames()
        var result: [SocialProfile] = []
        for zone in try await friendZones() where !blocked.contains(zone.ownerName) {
            let id = CKRecord.ID(recordName: SocialRecords.profileRecordName, zoneID: zone)
            if let record = try? await sharedDB.record(for: id), let profile = SocialRecords.profile(from: record) {
                result.append(profile)
            }
        }
        return result.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Both directions: they leave my share, I leave theirs.
    func removeFriend(_ person: PersonID) async throws {
        guard let zone = try await zone(of: person) else { throw SocialError.notFriends }
        try await removeParticipant(zone.ownerName)
        try await delete([CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone)], in: sharedDB)
    }

    /// Removes the friend and remembers them, so invites between you are refused from now on.
    func block(_ person: PersonID) async throws {
        guard let zone = try await zone(of: person) else { throw SocialError.notFriends }
        try await ensureLocalZone()
        let record = CKRecord(recordType: SocialRecords.blockedType,
                              recordID: CKRecord.ID(recordName: SocialRecords.blockedRecordName(zone.ownerName), zoneID: Self.localZoneID))
        record[SocialRecords.Field.userRecordName] = zone.ownerName
        record[SocialRecords.Field.personID] = person.rawValue
        try await save([record], in: privateDB, policy: .allKeys)
        try await removeFriend(person)
    }

    // MARK: Later steps

    func publish(_ kind: FeedEvent.Kind) async throws -> Bool { false }
    func feed() async throws -> [FeedEvent] { [] }
    func sendHighFive(to person: PersonID, for eventID: UUID?) async throws { throw SocialError.notAvailableYet }
    func receivedHighFives() async throws -> [HighFive] { [] }
    func challenge(_ person: PersonID, weekStart: Date) async throws -> Duel { throw SocialError.notAvailableYet }
    func respond(to duelID: UUID, accept: Bool) async throws -> Duel { throw SocialError.notAvailableYet }
    func postWeeklyEffort(_ points: Double, weekStart: Date) async throws {}
    func duels() async throws -> [Duel] { [] }

    // MARK: Helpers

    /// The record, or nil if it (or its zone) doesn't exist yet.
    private func existingRecord(_ id: CKRecord.ID, in database: CKDatabase) async throws -> CKRecord? {
        do {
            return try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }

    private func save(_ records: [CKRecord], in database: CKDatabase, policy: CKModifyRecordsOperation.RecordSavePolicy) async throws {
        let result = try await database.modifyRecords(saving: records, deleting: [], savePolicy: policy)
        for record in records { _ = try result.saveResults[record.recordID]?.get() }
    }

    /// Deletes, treating "already gone" as success.
    private func delete(_ ids: [CKRecord.ID], in database: CKDatabase) async throws {
        do {
            let result = try await database.modifyRecords(saving: [], deleting: ids)
            for id in ids {
                do { try result.deleteResults[id]?.get() } catch let error as CKError where error.code == .unknownItem {}
            }
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {}
    }

    /// Creates the Friends zone and its zone-wide share (private: no public permission) once.
    @discardableResult
    private func ensureZoneAndShare() async throws -> CKShare {
        let zones = try await privateDB.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
        _ = try zones.saveResults[Self.zoneID]?.get()
        if let existing = try await existingRecord(Self.shareID, in: privateDB) as? CKShare { return existing }
        let share = CKShare(recordZoneID: Self.zoneID)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = SocialRecords.shareTitle
        let result = try await privateDB.modifyRecords(saving: [share], deleting: [])
        guard let saved = try result.saveResults[Self.shareID]?.get() as? CKShare else { return share }
        return saved
    }

    @discardableResult
    private func ensureLocalZone() async throws -> CKRecordZone.ID {
        let zones = try await privateDB.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.localZoneID)], deleting: [])
        _ = try zones.saveResults[Self.localZoneID]?.get()
        return Self.localZoneID
    }

    /// Every record of a type in the FriendsLocal zone (a full zone read: no query index needed).
    private func localRecords(ofType type: String) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        var more = true
        do {
            while more {
                let changes = try await privateDB.recordZoneChanges(inZoneWith: Self.localZoneID, since: token)
                records += changes.modificationResultsByID.values.compactMap { try? $0.get().record }
                token = changes.changeToken
                more = changes.moreComing
            }
        } catch let error as CKError where error.code == .zoneNotFound {
            return []
        }
        return records.filter { $0.recordType == type }
    }

    private func blockedRecordNames() async throws -> Set<String> {
        Set(try await localRecords(ofType: SocialRecords.blockedType)
            .compactMap { $0[SocialRecords.Field.userRecordName] as? String })
    }

    private func isBlocked(_ userRecordName: String) async throws -> Bool {
        try await blockedRecordNames().contains(userRecordName)
    }

    /// Friends zones other people have shared with me.
    private func friendZones() async throws -> [CKRecordZone.ID] {
        try await sharedDB.allRecordZones().map(\.zoneID).filter { $0.zoneName == SocialRecords.zoneName }
    }

    private func zone(of person: PersonID) async throws -> CKRecordZone.ID? {
        for zone in try await friendZones() {
            let id = CKRecord.ID(recordName: SocialRecords.profileRecordName, zoneID: zone)
            if let record = try? await sharedDB.record(for: id), SocialRecords.profile(from: record)?.id == person {
                return zone
            }
        }
        return nil
    }

    private func addParticipant(_ userRecordName: String, to share: CKShare) async throws {
        let participant = try await container.shareParticipant(forUserRecordID: CKRecord.ID(recordName: userRecordName))
        participant.permission = .readOnly
        share.addParticipant(participant)
        try await save([share], in: privateDB, policy: .changedKeys)
    }

    private func removeParticipant(_ userRecordName: String) async throws {
        guard let share = try await existingRecord(Self.shareID, in: privateDB) as? CKShare else { return }
        let matches = share.participants.filter { $0.userIdentity.userRecordID?.recordName == userRecordName }
        guard !matches.isEmpty else { return }
        matches.forEach(share.removeParticipant)
        try await save([share], in: privateDB, policy: .changedKeys)
    }

    private func acceptShare(at url: URL) async throws {
        let metadata = try await container.shareMetadata(for: url)
        if metadata.participantStatus == .accepted { return }
        _ = try await container.accept(metadata)
    }
}
#endif
