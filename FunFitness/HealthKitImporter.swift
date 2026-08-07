//
//  HealthKitImporter.swift
//  FunFitness
//
//  Pure, testable logic that decides which imported HealthKit workouts should
//  become new ActivityLog entries. Kept free of SwiftData/HealthKit types so it
//  can be unit-tested directly.
//

import Foundation

struct HealthKitImporter {

    /// A manual distance entry considered when checking for fuzzy duplicates.
    struct ExistingEntry {
        let healthKitUUID: UUID?
        let distanceKm: Double
        let date: Date
        let isManualDistance: Bool
    }

    /// A workout that survived dedup and should be inserted.
    struct PendingImport: Equatable {
        let uuid: UUID
        let distanceKm: Double
        let date: Date
    }

    // Fuzzy-match window for skipping workouts that duplicate a manual entry.
    static let timeWindow: TimeInterval = 60 * 60          // ±1 hour
    static let distanceTolerance: Double = 0.05            // ±5%

    /// Returns the workouts that should be imported, filtering out:
    /// 1. Any workout whose UUID already exists (exact re-import / write-back echo).
    /// 2. Any workout that closely matches an existing manual distance entry.
    static func pendingImports(
        from workouts: [ImportedWorkout],
        existing: [ExistingEntry]
    ) -> [PendingImport] {
        let knownUUIDs = Set(existing.compactMap { $0.healthKitUUID })
        let manualEntries = existing.filter { $0.isManualDistance }

        return workouts.compactMap { workout in
            guard !knownUUIDs.contains(workout.uuid) else { return nil }
            if manualEntries.contains(where: { matches($0, workout) }) { return nil }
            return PendingImport(uuid: workout.uuid, distanceKm: workout.distanceKm, date: workout.date)
        }
    }

    private static func matches(_ entry: ExistingEntry, _ workout: ImportedWorkout) -> Bool {
        guard abs(entry.date.timeIntervalSince(workout.date)) <= timeWindow else { return false }
        guard workout.distanceKm > 0 else { return false }
        let delta = abs(entry.distanceKm - workout.distanceKm) / workout.distanceKm
        return delta <= distanceTolerance
    }
}
