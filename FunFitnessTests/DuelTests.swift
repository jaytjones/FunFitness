//
//  DuelTests.swift
//  FunFitnessTests
//
//  3.4 step 5: duels scored in Effort Points and the friends leaderboard: assembling duels from
//  everyone's records, week keys, the session flow, and the friendly copy.
//

#if INTERNAL_SOCIAL
import Testing
import Foundation
import CloudKit
@testable import FunFitness

@Suite("Friends duels (3.4)")
@MainActor
struct DuelTests {

    private let ana = PersonID(appleUserID: "duel-ana")
    private let ben = PersonID(appleUserID: "duel-ben")
    private let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date(timeIntervalSince1970: 1_800_000_000))!

    @Test func assembledDuelsTakeStatusFromTheOpponentAndPointsFromSharers() {
        let challenge = Duel(id: UUID(), challenger: ana, opponent: ben, weekStart: week.start, status: .pending)
        let key = SocialWeek.key(for: week.start)

        let pending = SocialRecords.assembleDuels(challenges: [challenge], responses: [:], efforts: [:], sharesEffort: [:])
        #expect(pending.first?.status == .pending)

        let active = SocialRecords.assembleDuels(
            challenges: [challenge],
            responses: [ben: [challenge.id: true]],
            efforts: [ana: [key: 120], ben: [key: 95]],
            sharesEffort: [ana: true, ben: false]       // Ben stopped sharing: his points don't count
        )
        #expect(active.first?.status == .active)
        #expect(active.first?.points == [ana: 120])

        let declined = SocialRecords.assembleDuels(challenges: [challenge], responses: [ben: [challenge.id: false]],
                                                   efforts: [:], sharesEffort: [:])
        #expect(declined.first?.status == .declined)
    }

    @Test func duelAndEffortRecordsRoundTrip() {
        let duel = Duel(id: UUID(), challenger: ana, opponent: ben, weekStart: week.start, status: .pending, createdAt: week.start + 60)
        let record = CKRecord(recordType: SocialRecords.duelType)
        SocialRecords.apply(duel, to: record)
        #expect(SocialRecords.duel(from: record) == duel)

        let response = CKRecord(recordType: SocialRecords.duelResponseType)
        SocialRecords.apply(duelResponse: duel.id, accepted: true, date: week.start, to: response)
        #expect(SocialRecords.duelResponse(from: response)?.accepted == true)

        let effort = CKRecord(recordType: SocialRecords.effortType)
        SocialRecords.apply(effort: 87.5, week: "2026-W48", weekStart: week.start, to: effort)
        #expect(SocialRecords.effort(from: effort)?.points == 87.5)
    }

    @Test func weekKeysAreStableWithinAWeek() {
        #expect(SocialWeek.key(for: week.start) == SocialWeek.key(for: week.end - 1))
        #expect(SocialWeek.key(for: week.start) != SocialWeek.key(for: week.end + 1))
        #expect(SocialWeek.key(for: week.start).contains("-W"))
    }

    @Test func copyIsFriendlyAndStablePerDuel() {
        let id = UUID()
        #expect(DuelCopy.consolation(winnerName: "Sam", duelID: id) == DuelCopy.consolation(winnerName: "Sam", duelID: id))
        #expect(DuelCopy.consolation(winnerName: "Sam", duelID: id).hasPrefix("Sam"))
        #expect(DuelCopy.victory(loserName: "Sam") == "You out-moved Sam! 🏆")
    }

    // MARK: Session flow

    private func readySession(_ appleID: String, _ name: String, store: InMemorySocialStore, effort: Bool) async -> SocialSession {
        let s = SocialSession(
            idStore: TestIDStore(),
            makeService: { InMemorySocialService(me: $0, store: store) },
            isICloudAvailable: { true }, isCredentialValid: { _ in true }
        )
        await s.signedIn(appleUserID: appleID)
        await s.createProfile(name: name, emoji: "🦛", styleID: "playful-bold")
        if effort, case .ready(var profile) = s.state {
            profile.sharing.shareWeeklyEffort = true
            await s.update(profile)
        }
        return s
    }

    @Test func duelFromChallengeToScoreboard() async throws {
        let store = InMemorySocialStore()
        let a = await readySession("duel-ana", "Ana", store: store, effort: true)
        let b = await readySession("duel-ben", "Ben", store: store, effort: true)
        await a.createInvite()
        await b.acceptInvite(code: try #require(a.newInvite?.code))
        await a.refreshFriends()

        await a.challenge(ben)
        #expect(a.hasDuelThisWeek(with: ben))
        await b.refreshFriends()
        let incoming = try #require(b.duels.first)
        #expect(incoming.status == .pending && incoming.opponent == ben)
        #expect(FeedText.newsLines(highFives: [], events: [], duels: b.duels, me: ben, names: [ana: "Ana"], since: .distantPast)
                == ["⚔️ Ana challenged you to a duel this week!"])

        await b.respond(to: incoming, accept: true)
        await a.postEffort(thisWeek: 120, lastWeek: 0)
        await b.postEffort(thisWeek: 95, lastWeek: 0)
        await a.refreshFriends()
        let duel = try #require(a.duels.first)
        #expect(duel.status == .active)
        #expect(duel.points == [ana: 120, ben: 95])
        #expect(a.leaderboard == [ana: 120, ben: 95])
    }

    @Test func challengingWithoutSharingEffortExplainsWhy() async throws {
        let store = InMemorySocialStore()
        let a = await readySession("duel-ana", "Ana", store: store, effort: false)
        let b = await readySession("duel-ben", "Ben", store: store, effort: false)
        await a.createInvite()
        await b.acceptInvite(code: try #require(a.newInvite?.code))
        await a.refreshFriends()
        await a.challenge(ben)
        #expect(a.inviteMessage == SocialSession.message(for: SocialError.sharingOff))
        #expect(a.duels.isEmpty)
    }
}

private final class TestIDStore: AppleIDStoring {
    var appleUserID: String?
}
#endif
