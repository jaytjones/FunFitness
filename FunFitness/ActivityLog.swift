//
//  ActivityLog.swift
//  FunFitness
//

import Foundation
import SwiftData

enum ActivityType: String, Codable {
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
    var id: UUID
    var type: String
    // Stored in SI units since v1.2: km for distance, kg for weight.
    var value: Double
    // Optional rep count for weight entries. nil = single rep.
    var reps: Int?
    var loggedAt: Date
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

    // For weight entries: value × reps (or × 1 when reps is nil).
    // For distance entries: value unchanged.
    var effectiveValue: Double {
        activityType == .weight ? value * Double(reps ?? 1) : value
    }
}

// Equatable by id + value + loggedAt + reps so onChange(of: activities) fires on
// inserts, deletes, and in-place edits (value, date, or rep-count corrections).
extension ActivityLog: Equatable {
    static func == (lhs: ActivityLog, rhs: ActivityLog) -> Bool {
        lhs.id == rhs.id && lhs.value == rhs.value && lhs.loggedAt == rhs.loggedAt && lhs.reps == rhs.reps
    }
}
