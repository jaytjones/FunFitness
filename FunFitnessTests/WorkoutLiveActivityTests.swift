//
//  WorkoutLiveActivityTests.swift
//  FunFitnessTests
//
//  3.1 B1b: the Live Activity's content (clock reference, formatted stats, comparison line) and
//  its update throttle.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Workout Live Activity content")
@MainActor
struct WorkoutLiveActivityTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    @Test func clockReferenceExcludesPausedTime() {
        let state = WorkoutLiveActivityContent.state(
            isPaused: false, isFinished: false, movingSeconds: 725, distanceMeters: 1_609.34,
            now: now, pref: .imperial, packId: ThemePackCatalog.default.id
        )
        // The live clock shows now − timerStart, so it must equal moving time, not wall time.
        #expect(now.timeIntervalSince(state.timerStart) == 725)
        #expect(state.elapsedText == "12:05")
    }

    @Test func statsAreFormattedInTheUsersUnits() {
        let imperial = WorkoutLiveActivityContent.state(
            isPaused: false, isFinished: false, movingSeconds: 600, distanceMeters: 1_609.34,
            now: now, pref: .imperial, packId: ThemePackCatalog.default.id
        )
        #expect(imperial.primaryValue == UnitConverter.distanceString(1.60934, pref: .imperial))
        #expect(imperial.secondaryValue == "10:00 /mi")

        let metric = WorkoutLiveActivityContent.state(
            isPaused: true, isFinished: false, movingSeconds: 300, distanceMeters: 1_000,
            now: now, pref: .metric, packId: ThemePackCatalog.default.id
        )
        #expect(metric.isPaused)
        #expect(metric.secondaryValue == "5:00 /km")
    }

    @Test func comparisonAppearsOnceThereIsDistance() {
        let none = WorkoutLiveActivityContent.state(
            isPaused: false, isFinished: false, movingSeconds: 5, distanceMeters: 0,
            now: now, pref: .metric, packId: ThemePackCatalog.default.id
        )
        #expect(none.comparison == nil)

        let some = WorkoutLiveActivityContent.state(
            isPaused: false, isFinished: false, movingSeconds: 900, distanceMeters: 2_300,
            now: now, pref: .metric, packId: ThemePackCatalog.default.id
        )
        #expect(some.comparison == ReferenceUnitEngine.distancePhrase(
            distanceKm: 2.3, pref: .metric, packId: ThemePackCatalog.default.id))
        #expect(some.comparison != nil)
    }

    @Test func finishedStateAsksToOpenTheApp() {
        let state = WorkoutLiveActivityContent.state(
            isPaused: false, isFinished: true, movingSeconds: 1_800, distanceMeters: 3_000,
            now: now, pref: .metric, packId: ThemePackCatalog.default.id
        )
        #expect(state.isFinished)
        #expect(state.comparison == "Open FunFitness to save it")
    }

    @Test func routineUpdatesAreThrottledButStateChangesAreNot() {
        #expect(WorkoutLiveActivityContent.shouldUpdate(lastUpdate: nil, now: now, force: false))
        #expect(!WorkoutLiveActivityContent.shouldUpdate(lastUpdate: now.addingTimeInterval(-3), now: now, force: false))
        #expect(WorkoutLiveActivityContent.shouldUpdate(lastUpdate: now.addingTimeInterval(-10), now: now, force: false))
        #expect(WorkoutLiveActivityContent.shouldUpdate(lastUpdate: now.addingTimeInterval(-1), now: now, force: true))
    }
}
