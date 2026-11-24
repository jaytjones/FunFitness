//
//  ChallengeTests.swift
//  FunFitnessTests
//
//  Locks in the v2.2 monthly-challenge catalog + deterministic evaluation engine.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Monthly challenges")
@MainActor
struct ChallengeTests {

    // Fixed local date so evaluation never depends on the wall clock.
    private func date(year: Int, month: Int, day: Int = 15) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    // MARK: - Catalog invariants

    @Test func everyMonthHasExactlyOneChallenge() {
        let months = ChallengeCatalog.all.map(\.month).sorted()
        #expect(months == Array(1...12))
    }

    @Test func challengeIdsAreUnique() {
        let ids = ChallengeCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func challengeFieldsAreWellFormed() {
        for c in ChallengeCatalog.all {
            #expect(!c.id.isEmpty)
            #expect(!c.title.isEmpty)
            #expect(!c.blurb.isEmpty)
            #expect(!c.emoji.isEmpty)
            #expect(c.targetSI > 0, "Challenge \(c.id) has a non-positive target")
        }
    }

    @Test func byIdFindsEveryChallenge() {
        for c in ChallengeCatalog.all {
            #expect(ChallengeCatalog.challenge(id: c.id)?.id == c.id)
        }
        #expect(ChallengeCatalog.challenge(id: "does-not-exist") == nil)
    }

    // MARK: - Month gating

    @Test func activeChallengeMatchesItsMonth() {
        for c in ChallengeCatalog.all {
            let d = date(year: 2026, month: c.month)
            #expect(ChallengeEngine.activeChallenge(on: d)?.id == c.id)
        }
    }

    // MARK: - Progress

    @Test func progressCountsOnlyMatchingTypeMonthAndYear() {
        let hippo = ChallengeCatalog.challenge(id: "hippo-march")! // weight, 1500 kg, March
        let activities = [
            ActivityLog(type: .weight,   value: 100, reps: 5,  loggedAt: date(year: 2026, month: 3, day: 5)),   // 500 (counts)
            ActivityLog(type: .weight,   value: 100, reps: 10, loggedAt: date(year: 2026, month: 3, day: 20)),  // 1000 (counts)
            ActivityLog(type: .weight,   value: 999,           loggedAt: date(year: 2026, month: 4, day: 1)),   // wrong month
            ActivityLog(type: .weight,   value: 999, reps: 9,  loggedAt: date(year: 2025, month: 3, day: 1)),   // wrong year
            ActivityLog(type: .distance, value: 999,           loggedAt: date(year: 2026, month: 3, day: 6)),   // wrong type
        ]
        let march = date(year: 2026, month: 3, day: 28)
        let progress = ChallengeEngine.progress(for: hippo, in: activities, on: march)
        #expect(abs(progress - 1500) < 0.001)
        #expect(ChallengeEngine.isComplete(hippo, in: activities, on: march))
        #expect(abs(ChallengeEngine.fractionComplete(hippo, in: activities, on: march) - 1.0) < 0.001)
    }

    @Test func incompleteChallengeReportsPartialFraction() {
        let hippo = ChallengeCatalog.challenge(id: "hippo-march")! // target 1500 kg
        let activities = [
            ActivityLog(type: .weight, value: 150, reps: 5, loggedAt: date(year: 2026, month: 3, day: 5)), // 750
        ]
        let march = date(year: 2026, month: 3, day: 10)
        #expect(!ChallengeEngine.isComplete(hippo, in: activities, on: march))
        #expect(abs(ChallengeEngine.fractionComplete(hippo, in: activities, on: march) - 0.5) < 0.001)
    }

    @Test func fractionCompleteIsCappedAtOne() {
        let hippo = ChallengeCatalog.challenge(id: "hippo-march")!
        let activities = [
            ActivityLog(type: .weight, value: 5000, loggedAt: date(year: 2026, month: 3, day: 5)),
        ]
        let march = date(year: 2026, month: 3, day: 10)
        #expect(ChallengeEngine.fractionComplete(hippo, in: activities, on: march) == 1.0)
    }

    @Test func emptyActivitiesProduceZeroProgress() {
        let hippo = ChallengeCatalog.challenge(id: "hippo-march")!
        #expect(ChallengeEngine.progress(for: hippo, in: [], on: date(year: 2026, month: 3)) == 0)
        #expect(!ChallengeEngine.isComplete(hippo, in: [], on: date(year: 2026, month: 3)))
    }

    // MARK: - Time and rep challenges count every source (FB-0021)

    @Test func timeChallengeCountsMinutesFromWalksStrengthAndTimeLogs() {
        let gobble = ChallengeCatalog.challenge(id: "gobble-wobble")! // duration, 600 min, November
        let nov = date(year: 2026, month: 11, day: 20)

        let tracked = ActivityLog(type: .distance, value: 4, loggedAt: date(year: 2026, month: 11, day: 3))
        let route = EffortEngine.RouteFacts(activityID: tracked.id, movingSeconds: 45 * 60, kind: .walk)

        let manual = ActivityLog(type: .distance, value: 2, loggedAt: date(year: 2026, month: 11, day: 4))
        manual.durationSeconds = 20 * 60

        let sessionID = UUID()
        let session = EffortEngine.SessionFacts(
            id: sessionID, startedAt: date(year: 2026, month: 11, day: 5), durationSeconds: 50 * 60)
        let sets = (0..<3).map { _ in
            let set = ActivityLog(type: .weight, value: 40, reps: 10, loggedAt: date(year: 2026, month: 11, day: 5))
            set.sessionID = sessionID
            return set
        }

        let yoga = ActivityLog(type: .duration, value: 30, loggedAt: date(year: 2026, month: 11, day: 6))
        let october = ActivityLog(type: .duration, value: 500, loggedAt: date(year: 2026, month: 10, day: 30))

        let progress = ChallengeEngine.progress(
            for: gobble, in: [tracked, manual, yoga, october] + sets,
            routes: [route], sessions: [session], on: nov)
        // 45 (route) + 20 (manual time) + 50 (session, once, not per set) + 30 (Time log)
        #expect(abs(progress - 145) < 0.001)
    }

    @Test func timeChallengeEstimatesEntriesWithoutRecordedTime() {
        let gobble = ChallengeCatalog.challenge(id: "gobble-wobble")!
        let nov = date(year: 2026, month: 11, day: 20)
        let walk = ActivityLog(type: .distance, value: 1, loggedAt: nov)                 // 12 min estimate
        let set = ActivityLog(type: .weight, value: 20, reps: 8, loggedAt: nov)          // 2 min estimate
        let progress = ChallengeEngine.progress(for: gobble, in: [walk, set], on: nov)
        #expect(abs(progress - (EffortEngine.estimatedMinutesPerKm + EffortEngine.estimatedMinutesPerSet)) < 0.001)
    }

    @Test func repChallengeCountsRepsInsideWeightSets() {
        let deck = ChallengeCatalog.challenge(id: "deck-the-reps")! // reps, December
        let dec = date(year: 2026, month: 12, day: 10)
        let activities = [
            ActivityLog(type: .reps,     value: 50,          loggedAt: dec),  // 50
            ActivityLog(type: .weight,   value: 60, reps: 12, loggedAt: dec), // 12 reps, not 720 kg
            ActivityLog(type: .weight,   value: 80,          loggedAt: dec),  // single rep
            ActivityLog(type: .distance, value: 5,           loggedAt: dec),  // doesn't count
        ]
        #expect(abs(ChallengeEngine.progress(for: deck, in: activities, on: dec) - 63) < 0.001)
    }

    // MARK: - Unlock key

    @Test func unlockKeyEncodesIdAndYear() {
        #expect(ChallengeEngine.unlockKey(id: "hippo-march", year: 2026) == "hippo-march#2026")
        // Distinct years are distinct badges.
        #expect(ChallengeEngine.unlockKey(id: "hippo-march", year: 2026)
                != ChallengeEngine.unlockKey(id: "hippo-march", year: 2027))
    }

    @Test func unlockedChallengeDerivesItsKey() {
        let unlocked = UnlockedChallenge(challengeId: "hippo-march", year: 2026)
        #expect(unlocked.challengeKey == "hippo-march#2026")
    }
}
