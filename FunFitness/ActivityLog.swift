//
//  ActivityLog.swift
//  FunFitness
//

import Foundation
import SwiftData

enum ActivityType: String, Codable, CaseIterable {
    case distance
    case weight
}

// Where an entry came from. Manual entries have a nil healthKitUUID;
// imported and write-back entries carry the originating HealthKit workout UUID.
enum ActivitySource: String, Codable {
    case manual
    case healthKit
}

@Model
final class ActivityLog {
    // Every stored property carries a default value so the schema is CloudKit-compatible
    // (v2.1). CloudKit requires attributes to be optional or have a default; these are
    // always overwritten by the initializer for real entries.
    var id: UUID = UUID()
    var type: String = ActivityType.distance.rawValue
    // Stored in SI units since v1.2: km for distance, kg for weight.
    var value: Double = 0
    // Optional rep count for weight entries. nil = single rep.
    var reps: Int?
    var loggedAt: Date = Date()
    var notes: String?
    // Origin of this entry (v1.4). Defaults to manual for pre-1.4 rows.
    var sourceRaw: String = ActivitySource.manual.rawValue
    // The HealthKit workout UUID this entry mirrors, if any (v1.4).
    // Set for imported workouts and for manual entries written back to Health.
    // Used as the exact-match dedup / echo-prevention key.
    var healthKitUUID: UUID?

    init(
        id: UUID = UUID(),
        type: ActivityType,
        value: Double,
        reps: Int? = nil,
        loggedAt: Date = Date(),
        notes: String? = nil,
        source: ActivitySource = .manual,
        healthKitUUID: UUID? = nil
    ) {
        self.id = id
        self.type = type.rawValue
        self.value = value
        self.reps = reps
        self.loggedAt = loggedAt
        self.notes = notes
        self.sourceRaw = source.rawValue
        self.healthKitUUID = healthKitUUID
    }

    var activityType: ActivityType {
        ActivityType(rawValue: type) ?? .distance
    }

    var source: ActivitySource {
        ActivitySource(rawValue: sourceRaw) ?? .manual
    }

    // Value counted toward totals. Types that use reps (weight) multiply value × reps;
    // all others accumulate their value directly. Driven by the type descriptor so new
    // activity types accumulate correctly without touching this. (v2.2)
    var effectiveValue: Double {
        activityType.usesReps ? value * Double(reps ?? 1) : value
    }
}

// Equatable by id + value + loggedAt + reps so onChange(of: activities) fires on
// inserts, deletes, and in-place edits (value, date, or rep-count corrections).
extension ActivityLog: Equatable {
    static func == (lhs: ActivityLog, rhs: ActivityLog) -> Bool {
        lhs.id == rhs.id && lhs.value == rhs.value && lhs.loggedAt == rhs.loggedAt && lhs.reps == rhs.reps
    }
}
