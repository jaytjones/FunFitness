//
//  FunFitnessWidgetData.swift
//  FunFitnessWidget
//
//  Shared data read/written via App Group UserDefaults.
//  Must be compiled into BOTH the main app target and the widget extension target.
//

import Foundation

enum WidgetDataKey {
    static let suiteName           = "group.com.discoverhealthquest.funfitness"
    static let streak              = "streak"
    static let longestStreak       = "longestStreak"
    static let activeThisWeek      = "activeThisWeek"
    static let distanceProgress    = "distanceProgress"
    static let weightProgress      = "weightProgress"
    static let nextDistanceMilestone = "nextDistanceMilestone"
    static let nextWeightMilestone  = "nextWeightMilestone"
    static let sillyTitle          = "sillyTitle"
}

struct WidgetSnapshot {
    var streak: Int
    var longestStreak: Int
    var activeThisWeek: Bool
    var distanceProgress: Double
    var weightProgress: Double
    var nextDistanceMilestone: String
    var nextWeightMilestone: String
    var sillyTitle: String

    static var empty: WidgetSnapshot {
        WidgetSnapshot(
            streak: 0,
            longestStreak: 0,
            activeThisWeek: false,
            distanceProgress: 0,
            weightProgress: 0,
            nextDistanceMilestone: "Log your first run!",
            nextWeightMilestone: "Log your first lift!",
            sillyTitle: "Future Legend"
        )
    }

    static func load() -> WidgetSnapshot {
        let d = UserDefaults(suiteName: WidgetDataKey.suiteName)
        return WidgetSnapshot(
            streak:                   d?.integer(forKey: WidgetDataKey.streak)               ?? 0,
            longestStreak:            d?.integer(forKey: WidgetDataKey.longestStreak)        ?? 0,
            activeThisWeek:           d?.bool(forKey: WidgetDataKey.activeThisWeek)          ?? false,
            distanceProgress:         d?.double(forKey: WidgetDataKey.distanceProgress)      ?? 0,
            weightProgress:           d?.double(forKey: WidgetDataKey.weightProgress)        ?? 0,
            nextDistanceMilestone:    d?.string(forKey: WidgetDataKey.nextDistanceMilestone) ?? "Log your first run!",
            nextWeightMilestone:      d?.string(forKey: WidgetDataKey.nextWeightMilestone)   ?? "Log your first lift!",
            sillyTitle:               d?.string(forKey: WidgetDataKey.sillyTitle)            ?? "Future Legend"
        )
    }
}
