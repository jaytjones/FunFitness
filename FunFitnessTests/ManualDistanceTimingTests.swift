//
//  ManualDistanceTimingTests.swift
//  FunFitnessTests
//
//  FB-0020: manual distance entries carry an optional duration and walk/run, and the entered
//  date is the start. Health gets a workout of the real length instead of a made-up minute.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

@Suite("Manual distance timing")
@MainActor
struct ManualDistanceTimingTests {
    // Kept as a property so the in-memory store outlives each test's context.
    let container: ModelContainer

    init() throws {
        let schema = Schema([UserProfile.self, ActivityLog.self, UnlockedAchievement.self, RouteSummary.self, WorkoutSession.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    @Test func parsesMinutes() {
        #expect(ManualDistanceTiming.parseMinutes("") == .none)
        #expect(ManualDistanceTiming.parseMinutes("  ") == .none)
        #expect(ManualDistanceTiming.parseMinutes("30") == .minutes(30))
        #expect(ManualDistanceTiming.parseMinutes("1440") == .minutes(1440))
        #expect(ManualDistanceTiming.parseMinutes("0") == .invalid)
        #expect(ManualDistanceTiming.parseMinutes("1441") == .invalid)
        #expect(ManualDistanceTiming.parseMinutes("abc") == .invalid)
    }

    @Test func untouchedDateMeansJustFinished() {
        let now = Date()
        let start = ManualDistanceTiming.start(entered: now, dateEdited: false, durationSeconds: 1800, now: now)
        #expect(start == now.addingTimeInterval(-1800))
        #expect(ManualDistanceTiming.start(entered: now, dateEdited: false, durationSeconds: nil, now: now) == now)
    }

    @Test func pickedDateIsTheStart() {
        let now = Date()
        let morning = now.addingTimeInterval(-6 * 3600)
        #expect(ManualDistanceTiming.start(entered: morning, dateEdited: true, durationSeconds: 1800, now: now) == morning)
    }

    @Test func pickedDateMovesEarlierRatherThanEndInTheFuture() {
        let now = Date()
        let tenMinutesAgo = now.addingTimeInterval(-600)
        let start = ManualDistanceTiming.start(entered: tenMinutesAgo, dateEdited: true, durationSeconds: 1800, now: now)
        #expect(start == now.addingTimeInterval(-1800))
    }

    @Test func durationAndKindAreStoredOnDistanceOnly() {
        let context = container.mainContext
        let vm = AppViewModel()
        _ = ActivityWriter.log(
            type: .distance, value: 3, reps: nil, date: Date(), durationSeconds: 1800, distanceKind: .run,
            context: context, viewModel: vm
        )
        _ = ActivityWriter.log(
            type: .duration, value: 20, reps: nil, date: Date(), durationSeconds: 1800, distanceKind: .run,
            context: context, viewModel: vm
        )
        let distance = vm.activities.first { $0.activityType == .distance }
        let timed = vm.activities.first { $0.activityType == .duration }
        #expect(distance?.durationSeconds == 1800)
        #expect(distance?.distanceKind == .run)
        #expect(timed?.durationSeconds == nil)
        #expect(timed?.distanceKind == nil)
    }

    @Test func repeatStartsDurationBeforeNow() {
        let now = Date()
        let walk = ActivityLog(type: .distance, value: 3)
        walk.durationSeconds = 2400
        #expect(ActivityWriter.repeatStart(for: walk, now: now) == now.addingTimeInterval(-2400))
        #expect(ActivityWriter.repeatStart(for: ActivityLog(type: .distance, value: 3), now: now) == now)
    }

    @Test func kindRawValuesAreStable() {
        // Persisted in ActivityLog.distanceKindRaw — renaming would orphan saved data.
        let entry = ActivityLog(type: .distance, value: 3)
        entry.distanceKind = .walk
        #expect(entry.distanceKindRaw == "walk")
        entry.distanceKind = .run
        #expect(entry.distanceKindRaw == "run")
    }
}
