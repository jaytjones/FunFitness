//
//  EffortEngineTests.swift
//  FunFitnessTests
//
//  Locks in Effort Points (3.1, C7): minutes × intensity, estimates for untimed entries, and
//  the weekly total. Fixed reference dates so bucketing never depends on the wall clock.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("EffortEngine")
@MainActor
struct EffortEngineTests {

    private let cal = Calendar.current

    private func fixedNow() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 17; c.hour = 12
        return cal.date(from: c)!
    }

    private func log(_ type: ActivityType, _ value: Double, at date: Date, session: UUID? = nil, hr: Double? = nil) -> EffortEngine.LogFacts {
        EffortEngine.LogFacts(id: UUID(), type: type, value: value, date: date, sessionID: session, averageHeartRate: hr)
    }

    @Test func heartRateZonesFollowPercentOfMax() {
        // age 40 → max 180
        #expect(EffortEngine.heartRateZone(averageBPM: 90, age: 40) == 1)    // 50%
        #expect(EffortEngine.heartRateZone(averageBPM: 108, age: 40) == 2)   // 60%
        #expect(EffortEngine.heartRateZone(averageBPM: 130, age: 40) == 3)   // 72%
        #expect(EffortEngine.heartRateZone(averageBPM: 150, age: 40) == 4)   // 83%
        #expect(EffortEngine.heartRateZone(averageBPM: 175, age: 40) == 5)   // 97%
    }

    @Test func trackedRunUsesMovingTimeAndRunIntensity() {
        let now = fixedNow()
        let run = log(.distance, 5, at: now)
        let route = EffortEngine.RouteFacts(activityID: run.id, movingSeconds: 30 * 60, kind: .run)
        let entries = EffortEngine.entries(logs: [run], routes: [route], sessions: [])

        #expect(entries.count == 1)
        #expect(entries[0].kind == .run)
        #expect(entries[0].isEstimated == false)
        #expect(abs(EffortEngine.points(for: entries[0], age: nil) - 30 * 4.9) < 0.001)
    }

    @Test func heartRateOverridesMETWhenAgeKnown() {
        let now = fixedNow()
        let walk = log(.distance, 3, at: now, hr: 130)   // zone 3 at age 40
        let route = EffortEngine.RouteFacts(activityID: walk.id, movingSeconds: 40 * 60, kind: .walk)
        let entry = EffortEngine.entries(logs: [walk], routes: [route], sessions: [])[0]

        #expect(abs(EffortEngine.points(for: entry, age: 40) - 40 * 3) < 0.001)
        // No age → falls back to walking MET.
        #expect(abs(EffortEngine.points(for: entry, age: nil) - 40 * 1.75) < 0.001)
    }

    @Test func untimedDistanceIsEstimatedAsAWalk() {
        let entry = EffortEngine.entries(logs: [log(.distance, 2, at: fixedNow())], routes: [], sessions: [])[0]
        #expect(entry.isEstimated)
        #expect(abs(entry.minutes - 24) < 0.001)
        #expect(abs(EffortEngine.points(for: entry, age: nil) - 24 * 1.75) < 0.001)
    }

    @Test func durationLogCountsItsMinutes() {
        let entry = EffortEngine.entries(logs: [log(.duration, 45, at: fixedNow())], routes: [], sessions: [])[0]
        #expect(entry.isEstimated == false)
        #expect(abs(EffortEngine.points(for: entry, age: nil) - 90) < 0.001)
    }

    @Test func timedSessionCountsOnceAndLooseSetsAreEstimated() {
        let now = fixedNow()
        let sessionID = UUID()
        let session = EffortEngine.SessionFacts(id: sessionID, startedAt: now, durationSeconds: 40 * 60)
        let logs = [
            log(.weight, 60, at: now, session: sessionID),
            log(.weight, 60, at: now, session: sessionID),
            log(.reps, 20, at: now, session: sessionID),
            log(.reps, 15, at: now),                       // loose set
        ]
        let entries = EffortEngine.entries(logs: logs, routes: [], sessions: [session])

        #expect(entries.count == 2)
        let timed = entries.first { !$0.isEstimated }
        #expect(timed.map { abs($0.minutes - 40) < 0.001 } == true)
        let loose = entries.first { $0.isEstimated }
        #expect(loose.map { abs($0.minutes - EffortEngine.estimatedMinutesPerSet) < 0.001 } == true)
    }

    @Test func untimedSessionFallsBackToPerSetEstimate() {
        let now = fixedNow()
        let sessionID = UUID()
        // Sets logged together from the log sheet: a few seconds apart, not a real timing.
        let session = EffortEngine.SessionFacts(id: sessionID, startedAt: now, durationSeconds: 3)
        let logs = [log(.weight, 60, at: now, session: sessionID), log(.weight, 60, at: now, session: sessionID)]
        let entries = EffortEngine.entries(logs: logs, routes: [], sessions: [session])

        #expect(entries.count == 2)
        #expect(entries.filter { !$0.isEstimated }.isEmpty)
    }

    @Test func weeklySummaryOnlyCountsThisWeek() {
        let now = fixedNow()
        let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: now)!
        let entries = EffortEngine.entries(
            logs: [log(.duration, 50, at: now), log(.duration, 100, at: lastWeek)],
            routes: [], sessions: []
        )
        let summary = EffortEngine.weeklySummary(entries: entries, age: nil, now: now)

        #expect(abs(summary.points - 100) < 0.001)
        #expect(summary.target == 150)
        #expect(abs(summary.fraction - 100.0 / 150) < 0.001)
        #expect(summary.isComplete == false)
        #expect(summary.includesEstimates == false)
        #expect(summary.pointsText == "100")
    }

    @Test func weeklySummaryCapsFractionAndFlagsEstimates() {
        let now = fixedNow()
        let entries = EffortEngine.entries(
            logs: [log(.duration, 100, at: now), log(.distance, 1, at: now)],
            routes: [], sessions: []
        )
        let summary = EffortEngine.weeklySummary(entries: entries, age: nil, now: now)

        #expect(summary.isComplete)
        #expect(summary.fraction == 1)
        #expect(summary.includesEstimates)
    }
}
