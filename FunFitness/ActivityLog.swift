//
//  ActivityLog.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
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
    var type: String // Stored as raw string for SwiftData compatibility
    var value: Double // Miles (distance) or pounds (weight)
    var loggedAt: Date
    var notes: String?
    
    init(
        id: UUID = UUID(),
        type: ActivityType,
        value: Double,
        loggedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.type = type.rawValue
        self.value = value
        self.loggedAt = loggedAt
        self.notes = notes
    }
    
    var activityType: ActivityType {
        ActivityType(rawValue: type) ?? .distance
    }
}
