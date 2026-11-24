//
//  SocialTests.swift
//  FunFitnessTests
//
//  3.4 Friends rules (Jay, 2026-11-24), exercised through InMemorySocialService with two or
//  three people sharing one store: nothing shared by default, invites by link or code, block
//  hides both ways, duels scored in Effort Points.
//

#if INTERNAL_SOCIAL
import Testing
import Foundation
@testable import FunFitness

@Suite("Friends (3.4)")
@MainActor
struct SocialTests {

    private let ana = PersonID(appleUserID: "apple-ana")
    private let ben = PersonID(appleUserID: "apple-ben")
    private let cat = PersonID(appleUserID: "apple-cat")

    private func profile(_ id: PersonID, _ name: String, sharing: SharingSettings = .nothingShared) -> SocialProfile {
        SocialProfile(id: id, displayName: name, avatarEmoji: "🦛", styleID: "playfulBold", sharing: sharing)
    }

    private var everything: SharingSettings {
        SharingSettings(shareUnlocks: true, shareStreak: true, shareWeeklyEffort: true)
    }

    /// Two people with profiles who are already friends.
    private func friends(
        anaSharing: SharingSettings = .nothingShared, benSharing: SharingSettings = .nothingShared
    ) async throws -> (InMemorySocialService, InMemorySocialService) {
        let store = InMemorySocialStore()
        let a = InMemorySocialService(me: ana, store: store)
        let b = InMemorySocialService(me: ben, store: store)
        try await a.saveProfile(profile(ana, "Ana", sharing: anaSharing))
        try await b.saveProfile(profile(ben, "Ben", sharing: benSharing))
        let invite = try await a.createInvite()
        _ = try await b.acceptInvite(code: invite.code)
        return (a, b)
    }

    // MARK: Identity and profile

    @Test func personIDHashesTheAppleIDStably() {
        #expect(PersonID(appleUserID: "abc") == PersonID(appleUserID: "abc"))
        #expect(PersonID(appleUserID: "abc") != PersonID(appleUserID: "abd"))
        #expect(PersonID(appleUserID: "abc").rawValue.count == 64)
        #expect(!PersonID(appleUserID: "abc").rawValue.contains("abc"))
    }

    @Test func newProfilesShareNothing() {
        #expect(SharingSettings() == .nothingShared)
        #expect(!SharingSettings().shareUnlocks && !SharingSettings().shareStreak && !SharingSettings().shareWeeklyEffort)
    }

    @Test func displayNamesAreTrimmedAndCapped() {
        #expect(SocialProfile.cleanedName("  Jay  ") == "Jay")
        #expect(SocialProfile.cleanedName("   ") == nil)
        #expect(SocialProfile.cleanedName(String(repeating: "x", count: 50))?.count == SocialProfile.displayNameLimit)
    }

    // MARK: Invites

    @Test func inviteCodesAreReadableAndNormalized() {
        var generator = SystemRandomNumberGenerator()
        let code = FriendInvite.makeCode(using: &generator)
        #expect(code.count == 6)
        #expect(code.allSatisfy(FriendInvite.alphabet.contains))
        #expect(FriendInvite.normalizedCode(" abc-234 ") == "ABC234")
        #expect(FriendInvite.normalizedCode("funfitness://friend/ABC234") == "ABC234")
        #expect(FriendInvite.normalizedCode("ABC10O") == nil)   // 0, 1, O aren't used
        #expect(FriendInvite.normalizedCode("ABC23") == nil)
    }

    @Test func acceptingAnInviteMakesBothFriendsOnce() async throws {
        let (a, b) = try await friends()
        #expect(try await a.friends().map(\.displayName) == ["Ben"])
        #expect(try await b.friends().map(\.displayName) == ["Ana"])
    }

    @Test func invitesAreSingleUseAndNotForYourself() async throws {
        let store = InMemorySocialStore()
        let a = InMemorySocialService(me: ana, store: store)
        let b = InMemorySocialService(me: ben, store: store)
        let c = InMemorySocialService(me: cat, store: store)
        for (service, name) in [(a, "Ana"), (b, "Ben"), (c, "Cat")] {
            try await service.saveProfile(profile(service.me, name))
        }
        let invite = try await a.createInvite()
        await #expect(throws: SocialError.ownInvite) { _ = try await a.acceptInvite(code: invite.code) }
        _ = try await b.acceptInvite(code: invite.code)
        await #expect(throws: SocialError.inviteNotFound) { _ = try await c.acceptInvite(code: invite.code) }
    }

    @Test func expiredInvitesAreRefused() async throws {
        let store = InMemorySocialStore()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let a = InMemorySocialService(me: ana, store: store, now: { start })
        let lateBen = InMemorySocialService(me: ben, store: store, now: { start + FriendInvite.lifetime + 1 })
        try await a.saveProfile(profile(ana, "Ana"))
        try await lateBen.saveProfile(profile(ben, "Ben"))
        let invite = try await a.createInvite()
        await #expect(throws: SocialError.inviteExpired) { _ = try await lateBen.acceptInvite(code: invite.code) }
    }

    @Test func noProfileMeansNoFriendsActions() async throws {
        let service = InMemorySocialService(me: ana, store: InMemorySocialStore())
        await #expect(throws: SocialError.noProfile) { _ = try await service.createInvite() }
    }

    // MARK: Block, remove, delete

    @Test func blockingHidesEachFromTheOtherAndStopsReinvites() async throws {
        let (a, b) = try await friends(anaSharing: everything, benSharing: everything)
        try await a.publish(.streakMilestone(weeks: 4))
        try await b.block(ana)
        #expect(try await a.friends().isEmpty)
        #expect(try await b.friends().isEmpty)
        #expect(try await b.feed().isEmpty)
        await #expect(throws: SocialError.blocked) { try await a.sendHighFive(to: ben, for: nil) }
        let invite = try await a.createInvite()
        await #expect(throws: SocialError.blocked) { _ = try await b.acceptInvite(code: invite.code) }
    }

    @Test func deletingAProfileRemovesItFromFriends() async throws {
        let (a, b) = try await friends(anaSharing: everything)
        try await a.publish(.badgeUnlocked(milestoneID: "D2"))
        try await a.deleteProfile()
        #expect(try await b.friends().isEmpty)
        #expect(try await b.feed().isEmpty)
        #expect(try await a.profile() == nil)
    }

    // MARK: Feed and high fives

    @Test func nothingIsPublishedUntilSharingIsOn() async throws {
        let (a, b) = try await friends()
        #expect(try await a.publish(.badgeUnlocked(milestoneID: "D2")) == false)
        #expect(try await b.feed().isEmpty)

        var sharing = SharingSettings.nothingShared
        sharing.shareUnlocks = true
        try await a.saveProfile(profile(ana, "Ana", sharing: sharing))
        #expect(try await a.publish(.badgeUnlocked(milestoneID: "D2")))
        #expect(try await a.publish(.streakMilestone(weeks: 4)) == false)   // streak still off
        #expect(try await b.feed().map(\.kind) == [.badgeUnlocked(milestoneID: "D2")])
    }

    @Test func turningSharingOffHidesOlderEvents() async throws {
        let (a, b) = try await friends(anaSharing: everything)
        try await a.publish(.streakMilestone(weeks: 8))
        try await a.saveProfile(profile(ana, "Ana", sharing: .nothingShared))
        #expect(try await b.feed().isEmpty)
    }

    @Test func highFivesGoOnlyToFriends() async throws {
        let (a, b) = try await friends()
        try await b.sendHighFive(to: ana, for: nil)
        #expect(try await a.receivedHighFives().map(\.from) == [ben])
        await #expect(throws: SocialError.notFriends) { try await a.sendHighFive(to: cat, for: nil) }
    }

    // MARK: Duels (Effort Points)

    private let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date(timeIntervalSince1970: 1_800_000_000))!

    @Test func duelsNeedWeeklyEffortSharedOnBothSides() async throws {
        let (a, b) = try await friends(anaSharing: .nothingShared, benSharing: .nothingShared)
        await #expect(throws: SocialError.sharingOff) { _ = try await a.challenge(ben, weekStart: week.start) }

        try await a.saveProfile(profile(ana, "Ana", sharing: everything))
        let duel = try await a.challenge(ben, weekStart: week.start)
        await #expect(throws: SocialError.sharingOff) { _ = try await b.respond(to: duel.id, accept: true) }
        #expect(try await b.respond(to: duel.id, accept: false).status == .declined)
    }

    @Test func duelRunsEndToEndAndBothSidesAgree() async throws {
        let (a, b) = try await friends(anaSharing: everything, benSharing: everything)
        let duel = try await a.challenge(ben, weekStart: week.start)
        _ = try await b.respond(to: duel.id, accept: true)
        try await a.postWeeklyEffort(120, weekStart: week.start)
        try await b.postWeeklyEffort(95, weekStart: week.start)

        let fromAna = try #require(try await a.duels().first)
        let fromBen = try #require(try await b.duels().first)
        #expect(fromAna == fromBen)
        #expect(DuelEngine.outcome(of: fromAna, now: week.start + 3600) == .inProgress(leader: ana))
        #expect(DuelEngine.outcome(of: fromAna, now: week.end) == .won(by: ana))
    }

    @Test func duelOutcomes() {
        var duel = Duel(id: UUID(), challenger: ana, opponent: ben, weekStart: week.start, status: .pending)
        #expect(DuelEngine.outcome(of: duel, now: week.end) == .waiting)
        duel.status = .active
        #expect(DuelEngine.outcome(of: duel, now: week.start) == .inProgress(leader: nil))
        #expect(DuelEngine.outcome(of: duel, now: week.end) == .tie)          // nobody posted
        duel.points[ben] = 10
        #expect(DuelEngine.outcome(of: duel, now: week.end) == .won(by: ben)) // missing side = 0
    }

    // MARK: Leaderboard

    @Test func leaderboardRanksWithTies() {
        let rows = FriendsLeaderboard.rows(
            points: [ana: 80, ben: 120, cat: 80],
            names: [ana: "Ana", ben: "Ben", cat: "Cat"]
        )
        #expect(rows.map(\.person) == [ben, ana, cat])
        #expect(rows.map(\.rank) == [1, 2, 2])
    }
}
#endif
