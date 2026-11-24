//
//  SocialSessionTests.swift
//  FunFitnessTests
//
//  3.4 step 2: the Friends sign-in flow (SocialSession over InMemorySocialService with fake
//  Apple ID store, credential check and iCloud status) and the CloudKit record mapping.
//

#if INTERNAL_SOCIAL
import Testing
import Foundation
import CloudKit
@testable import FunFitness

private final class FakeIDStore: AppleIDStoring {
    var appleUserID: String?
    init(_ id: String? = nil) { appleUserID = id }
}

@Suite("Friends session (3.4)")
@MainActor
struct SocialSessionTests {

    private func session(
        store: InMemorySocialStore? = nil,
        ids: FakeIDStore? = nil,
        iCloud: Bool = true,
        credentialValid: Bool = true
    ) -> SocialSession {
        let store = store ?? InMemorySocialStore()
        return SocialSession(
            idStore: ids ?? FakeIDStore(),
            makeService: { InMemorySocialService(me: $0, store: store) },
            isICloudAvailable: { iCloud },
            isCredentialValid: { _ in credentialValid }
        )
    }

    @Test func startsSignedOutWithoutAnAppleID() async {
        let s = session()
        await s.refresh()
        #expect(s.state == .signedOut)
    }

    @Test func signInThenCreateProfileSharingNothing() async throws {
        let ids = FakeIDStore()
        let s = session(ids: ids)
        await s.signedIn(appleUserID: "apple-jay")
        #expect(s.state == .needsProfile)
        #expect(ids.appleUserID == "apple-jay")

        await s.createProfile(name: "  Jay ", emoji: "🦛", styleID: "arcade")
        guard case .ready(let profile) = s.state else { Issue.record("expected ready"); return }
        #expect(profile.displayName == "Jay")
        #expect(profile.styleID == "arcade")
        #expect(profile.sharing == .nothingShared)
        #expect(profile.id == PersonID(appleUserID: "apple-jay"))
    }

    @Test func profileIsFoundAgainOnTheNextLaunch() async {
        let store = InMemorySocialStore()
        let first = session(store: store, ids: FakeIDStore())
        await first.signedIn(appleUserID: "apple-jay")
        await first.createProfile(name: "Jay", emoji: "🦛", styleID: "playfulBold")

        let relaunched = session(store: store, ids: FakeIDStore("apple-jay"))
        await relaunched.refresh()
        guard case .ready(let profile) = relaunched.state else { Issue.record("expected ready"); return }
        #expect(profile.displayName == "Jay")
    }

    @Test func noICloudMeansFriendsStaysOff() async {
        let s = session(ids: FakeIDStore("apple-jay"), iCloud: false)
        await s.refresh()
        #expect(s.state == .iCloudUnavailable)
    }

    @Test func sharingChangesAreSaved() async throws {
        let store = InMemorySocialStore()
        let s = session(store: store)
        await s.signedIn(appleUserID: "apple-jay")
        await s.createProfile(name: "Jay", emoji: "🦛", styleID: "playfulBold")
        guard case .ready(var profile) = s.state else { Issue.record("expected ready"); return }
        profile.sharing.shareWeeklyEffort = true
        await s.update(profile)
        let saved = await store.profiles[PersonID(appleUserID: "apple-jay")]
        #expect(saved?.sharing.shareWeeklyEffort == true)
    }

    @Test func signOutKeepsTheProfileForNextTime() async {
        let store = InMemorySocialStore()
        let ids = FakeIDStore()
        let s = session(store: store, ids: ids)
        await s.signedIn(appleUserID: "apple-jay")
        await s.createProfile(name: "Jay", emoji: "🦛", styleID: "playfulBold")
        s.signOut()
        #expect(s.state == .signedOut)
        #expect(ids.appleUserID == nil)
        #expect(await store.profiles[PersonID(appleUserID: "apple-jay")] != nil)
    }

    @Test func deleteRemovesTheProfileAndSignsOut() async {
        let store = InMemorySocialStore()
        let s = session(store: store)
        await s.signedIn(appleUserID: "apple-jay")
        await s.createProfile(name: "Jay", emoji: "🦛", styleID: "playfulBold")
        await s.deleteProfile()
        #expect(s.state == .signedOut)
        #expect(await store.profiles.isEmpty)
    }

    @Test func revokedAppleIDDeletesTheProfileAndSignsOut() async {
        let store = InMemorySocialStore()
        let first = session(store: store, ids: FakeIDStore())
        await first.signedIn(appleUserID: "apple-jay")
        await first.createProfile(name: "Jay", emoji: "🦛", styleID: "playfulBold")

        let ids = FakeIDStore("apple-jay")
        let revoked = session(store: store, ids: ids, credentialValid: false)
        await revoked.refresh()
        #expect(revoked.state == .signedOut)
        #expect(ids.appleUserID == nil)
        #expect(await store.profiles.isEmpty)
    }

    // MARK: CloudKit record mapping

    @Test func profileRecordRoundTrips() {
        let profile = SocialProfile(
            id: PersonID(appleUserID: "apple-jay"), displayName: "Jay", avatarEmoji: "🦖", styleID: "fieldGuide",
            sharing: SharingSettings(shareUnlocks: true, shareStreak: false, shareWeeklyEffort: true)
        )
        let record = CKRecord(recordType: SocialRecords.profileType)
        SocialRecords.apply(profile, to: record)
        #expect(SocialRecords.profile(from: record) == profile)
    }

    @Test func recordsWithoutSharingFieldsShareNothing() {
        let record = CKRecord(recordType: SocialRecords.profileType)
        record[SocialRecords.Field.personID] = "abc"
        record[SocialRecords.Field.displayName] = "Sam"
        #expect(SocialRecords.profile(from: record)?.sharing == .nothingShared)
        #expect(SocialRecords.profile(from: CKRecord(recordType: "Other")) == nil)
    }
}
#endif
