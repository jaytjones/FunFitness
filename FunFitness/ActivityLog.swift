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

    init(
        id: UUID = UUID(),
        type: ActivityType,
        value: Double,
        reps: Int? = nil,
        loggedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.type = type.rawValue
        self.value = value
        self.reps = reps
        self.loggedAt = loggedAt
        self.notes = notes
    }

    var activityType: ActivityType {
        ActivityType(rawValue: type) ?? .distance
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
