//
//  HealthKitImporterTests.swift
//  FunFitnessTests
//
//  Covers HealthKit import dedup logic and the shared repeat/log path.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

@Suite("HealthKitImporter")
struct HealthKitImporterTests {

    private func workout(_ uuid: UUID = UUID(), km: Double, at date: Date) -> ImportedWorkout {
        ImportedWorkout(uuid: uuid, distanceKm: km, date: date)
    }

    @Test func brandNewWorkoutIsImported() {
        let w = workout(km: 5.0, at: Date(timeIntervalSince1970: 1_000_000))
        let pending = HealthKitImporter.pendingImports(from: [w], existing: [])
        #expect(pending.count == 1)
        #expect(pending.first?.distanceKm == 5.0)
    }

    @Test func alreadyImportedUUIDIsSkipped() {
        let uuid = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let w = workout(uuid, km: 5.0, at: date)
        let existing = [
            HealthKitImporter.ExistingEntry(
                healthKitUUID: uuid, distanceKm: 5.0, date: date, isManualDistance: false
            )
        ]
        #expect(HealthKitImporter.pendingImports(from: [w], existing: existing).isEmpty)
    }

    @Test func writeBackEchoIsSkippedByUUID() {
        // A manual entry we previously wrote to Health carries its UUID; the
        // import of that same workout must be recognized and skipped.
        let uuid = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let w = workout(uuid, km: 3.2, at: date)
        let existing = [
            HealthKitImporter.ExistingEntry(
                healthKitUUID: uuid, distanceKm: 3.2, date: date, isManualDistance: true
            )
        ]
        #expect(HealthKitImporter.pendingImports(from: [w], existing: existing).isEmpty)
    }

    @Test func fuzzyManualDuplicateIsSkipped() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let w = workout(km: 5.0, at: date)
        // Manual entry, no UUID, same distance, 10 minutes apart → duplicate.
        let existing = [
            HealthKitImporter.ExistingEntry(
                healthKitUUID: nil,
                distanceKm: 5.02,
                date: date.addingTimeInterval(600),
                isManualDistance: true
            )
        ]
        #expect(HealthKitImporter.pendingImports(from: [w], existing: existing).isEmpty)
    }

    @Test func distantManualEntryIsNotADuplicate() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let w = workout(km: 5.0, at: date)
        // Same distance but 3 hours away → different activity, import it.
        let existing = [
            HealthKitImporter.ExistingEntry(
                healthKitUUID: nil,
                distanceKm: 5.0,
                date: date.addingTimeInterval(3 * 3600),
                isManualDistance: true
            )
        ]
        #expect(HealthKitImporter.pendingImports(from: [w], existing: existing).count == 1)
    }

    @Test func differentDistanceIsNotADuplicate() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let w = workout(km: 5.0, at: date)
        // Within the time window but 30% off distance → not a duplicate.
        let existing = [
            HealthKitImporter.ExistingEntry(
                healthKitUUID: nil,
                distanceKm: 6.5,
                date: date,
                isManualDistance: true
            )
        ]
        #expect(HealthKitImporter.pendingImports(from: [w], existing: existing).count == 1)
    }
}

@Suite("ActivityWriter")
struct ActivityWriterTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([UserProfile.self, ActivityLog.self, UnlockedAchievement.self, StreakRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func logInsertsDistanceEntry() throws {
        let context = try makeContext()
        let result = ActivityWriter.log(
            type: .distance, value: 5.0, reps: nil, date: Date(),
            existingActivities: [], unlockedIds: [], context: context
        )
        #expect(result.activity.activityType == .distance)
        #expect(result.activity.value == 5.0)
        #expect(result.activity.source == .manual)
    }

    @Test func repeatPreservesTypeValueAndReps() throws {
        let context = try makeContext()
        let original = ActivityLog(type: .weight, value: 40.0, reps: 12, loggedAt: Date(timeIntervalSince1970: 1_000))

        let newDate = Date(timeIntervalSince1970: 2_000)
        let result = ActivityWriter.log(
            type: original.activityType,
            value: original.value,
            reps: original.reps,
            date: newDate,
            existingActivities: [original],
            unlockedIds: [],
            context: context
        )

        #expect(result.activity.activityType == .weight)
        #expect(result.activity.value == 40.0)
        #expect(result.activity.reps == 12)
        #expect(result.activity.loggedAt == newDate)
    }
}
