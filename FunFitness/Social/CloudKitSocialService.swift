//
//  CloudKitSocialService.swift
//  FunFitness
//
//  Friends on CloudKit with shared zones (Jay, 2026-11-24): each person keeps a "Friends" zone in
//  their own private database and shares the whole zone (one zone-wide CKShare, no public access)
//  with each friend, so iCloud itself decides who can read it. SwiftData's own sync zone is
//  untouched. Step 2 covers the profile; invites (adding share participants), feed, high fives and
//  duels arrive in steps 3–5 and throw `.notAvailableYet` until then.
//
//  UNRELEASED — compiled only with INTERNAL_SOCIAL (Debug + Internal builds, never Release).
//

#if INTERNAL_SOCIAL
import Foundation
import CloudKit

/// Field names and record mapping, kept pure so they're unit-tested without iCloud.
nonisolated enum SocialRecords {
    static let zoneName = "Friends"
    static let profileType = "SocialProfile"
    static let profileRecordName = "profile"
    static let shareTitle = "FunFitness Friends"

    enum Field {
        static let personID = "personID"
        static let displayName = "displayName"
        static let avatarEmoji = "avatarEmoji"
        static let styleID = "styleID"
        static let shareUnlocks = "shareUnlocks"
        static let shareStreak = "shareStreak"
        static let shareWeeklyEffort = "shareWeeklyEffort"
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
}

struct CloudKitSocialService: SocialService {
    let me: PersonID
    private let database: CKDatabase

    private static let zoneID = CKRecordZone.ID(zoneName: SocialRecords.zoneName, ownerName: CKCurrentUserDefaultName)
    private static let profileID = CKRecord.ID(recordName: SocialRecords.profileRecordName, zoneID: zoneID)
    private static let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)

    init(me: PersonID, containerIdentifier: String) {
        self.me = me
        database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
    }

    // MARK: Profile (step 2)

    func profile() async throws -> SocialProfile? {
        guard let record = try await existingRecord(Self.profileID) else { return nil }
        return SocialRecords.profile(from: record)
    }

    func saveProfile(_ profile: SocialProfile) async throws {
        precondition(profile.id == me, "Only your own profile can be saved")
        try await ensureZoneAndShare()
        let record = try await existingRecord(Self.profileID)
            ?? CKRecord(recordType: SocialRecords.profileType, recordID: Self.profileID)
        SocialRecords.apply(profile, to: record)
        let result = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
        try result.saveResults[Self.profileID]?.get()
    }

    /// Deleting the zone deletes its share too, so every friend loses access at once.
    func deleteProfile() async throws {
        do {
            let result = try await database.modifyRecordZones(saving: [], deleting: [Self.zoneID])
            try result.deleteResults[Self.zoneID]?.get()
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            // Nothing to delete.
        }
    }

    // MARK: Later steps

    func createInvite() async throws -> FriendInvite { throw SocialError.notAvailableYet }
    func acceptInvite(code: String) async throws -> SocialProfile { throw SocialError.notAvailableYet }
    func friends() async throws -> [SocialProfile] { [] }
    func removeFriend(_ person: PersonID) async throws { throw SocialError.notAvailableYet }
    func block(_ person: PersonID) async throws { throw SocialError.notAvailableYet }
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
    private func existingRecord(_ id: CKRecord.ID) async throws -> CKRecord? {
        do {
            return try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }

    /// Creates the Friends zone and its zone-wide share (private: no public permission) once.
    private func ensureZoneAndShare() async throws {
        let zones = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
        _ = try zones.saveResults[Self.zoneID]?.get()
        guard try await existingRecord(Self.shareID) == nil else { return }
        let share = CKShare(recordZoneID: Self.zoneID)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = SocialRecords.shareTitle
        let result = try await database.modifyRecords(saving: [share], deleting: [])
        _ = try result.saveResults[Self.shareID]?.get()
    }
}
#endif
