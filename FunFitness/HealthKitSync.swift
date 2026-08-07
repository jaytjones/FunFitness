//
//  HealthKitSync.swift
//  FunFitness
//
//  Orchestrates a HealthKit import pass: authorize, fetch distance workouts
//  since the user's chosen anchor, dedup via HealthKitImporter, and insert the
//  survivors as .healthKit ActivityLog entries. Shared by ContentView (on
//  launch / foreground) and ProfileView (enable + manual re-import).
//

import Foundation
import SwiftData

@MainActor
struct HealthKitSync {

    /// Earliest workout date to import. `nil` (no key) means "all history".
    private static let anchorKey = "healthKitImportAnchor"

    static var anchor: Date? {
        UserDefaults.standard.object(forKey: anchorKey) as? Date
    }

    /// Records the retroactive-import choice: pass `nil` to count all history,
    /// or `Date()` to import only workouts from now on.
    static func setAnchor(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(date, forKey: anchorKey)
        } else {
            UserDefaults.standard.removeObject(forKey: anchorKey)
        }
    }

    /// Runs one import pass. Returns the number of new entries inserted.
    /// Safe to call repeatedly — dedup keeps it idempotent.
    @discardableResult
    static func run(existing: [ActivityLog], context: ModelContext) async -> Int {
        let manager = HealthKitManager.shared
        guard manager.isAvailable else { return 0 }
        guard await manager.requestAuthorization() else { return 0 }

        let workouts = await manager.fetchDistanceWorkouts(since: anchor)
        guard !workouts.isEmpty else { return 0 }

        let existingEntries = existing.map { log in
            HealthKitImporter.ExistingEntry(
                healthKitUUID: log.healthKitUUID,
                distanceKm: log.value,
                date: log.loggedAt,
                isManualDistance: log.source == .manual && log.activityType == .distance
            )
        }

        let pending = HealthKitImporter.pendingImports(from: workouts, existing: existingEntries)
        guard !pending.isEmpty else { return 0 }

        for item in pending {
            context.insert(ActivityLog(
                type: .distance,
                value: item.distanceKm,
                loggedAt: item.date,
                source: .healthKit,
                healthKitUUID: item.uuid
            ))
        }
        try? context.save()
        return pending.count
    }
}
