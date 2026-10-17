//
//  SurfaceTests.swift
//  FunFitnessTests
//
//  3.1 / feedback C9: optional distance surface (road, track, trail, treadmill).
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

@Suite("Distance surface")
@MainActor
struct SurfaceTests {
    // Kept as a property so the in-memory store outlives each test's context.
    let container: ModelContainer

    init() throws {
        let schema = Schema([UserProfile.self, ActivityLog.self, UnlockedAchievement.self, RouteSummary.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    @Test func rawValuesAreStable() {
        // Persisted in ActivityLog.surfaceRaw and exports — renaming would orphan saved data.
        #expect(DistanceSurface.allCases.map(\.rawValue) == ["road", "track", "trail", "treadmill"])
        #expect(DistanceSurface.outdoor == [.road, .track, .trail])
    }

    @Test func surfaceIsKeptOnlyForDistance() {
        let context = container.mainContext
        let run = ActivityWriter.log(
            type: .distance, value: 5, reps: nil, date: Date(), surface: .trail,
            existingActivities: [], unlockedIds: [], context: context
        )
        let lift = ActivityWriter.log(
            type: .weight, value: 50, reps: 10, date: Date(), surface: .trail,
            existingActivities: [], unlockedIds: [], context: context
        )
        #expect(run.activity.surface == .trail)
        #expect(lift.activity.surface == nil)
    }

    @Test func surfaceIsOptional() {
        let entry = ActivityLog(type: .distance, value: 3)
        #expect(entry.surface == nil)
        entry.surface = .treadmill
        #expect(entry.surfaceRaw == "treadmill")
        entry.surface = nil
        #expect(entry.surfaceRaw == nil)
    }

    @Test func lastSurfaceComesFromTheNewestDistanceEntryWithOne() {
        let vm = AppViewModel()
        let now = Date()
        vm.activities = [
            ActivityLog(type: .distance, value: 5, loggedAt: now.addingTimeInterval(-7200), surface: .road),
            ActivityLog(type: .distance, value: 5, loggedAt: now.addingTimeInterval(-3600), surface: .trail),
            ActivityLog(type: .distance, value: 5, loggedAt: now),   // none recorded — skipped
        ]
        #expect(vm.lastSurface == .trail)
        #expect(AppViewModel().lastSurface == nil)
    }

    @Test func trackedRunsSaveTheirSurface() throws {
        let context = container.mainContext
        let result = TrackedWorkoutResult(
            kind: .run, startedAt: Date(timeIntervalSince1970: 0), endedAt: Date(timeIntervalSince1970: 600),
            distanceMeters: 2_000, movingSeconds: 600, points: [], pauseIntervals: []
        )
        ActivityWriter.logTracked(result, surface: .track, context: context, viewModel: AppViewModel(), writeBackToHealth: false)
        let log = try #require(try context.fetch(FetchDescriptor<ActivityLog>()).first)
        #expect(log.surface == .track)
    }

    @Test func exportsIncludeTheSurface() {
        let activities = [
            ActivityLog(type: .distance, value: 5, loggedAt: Date(timeIntervalSince1970: 0), surface: .trail),
            ActivityLog(type: .weight, value: 50, reps: 10, loggedAt: Date(timeIntervalSince1970: 60)),
        ]
        let csv = ExportManager.generateCSV(activities: activities, pref: .metric).split(separator: "\n")
        #expect(csv[0] == "Type,Value,Unit,Reps,Date,Notes,Surface")
        #expect(csv[1].hasSuffix(",trail"))
        #expect(csv[2].hasSuffix(","))   // no surface → empty last column

        let json = ExportManager.generateJSON(activities: activities)
        #expect(json.contains("\"surface\" : \"trail\""))
        #expect(json.contains("\"schemaVersion\" : \"1.3\""))
    }
}
