//
//  FunFitnessWidgetData.swift
//  FunFitnessWidgets
//
//  Shared data read/written via App Group UserDefaults.
//  The app writes these keys in ContentView.writeWidgetData(); the widget reads them here.
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
    // Medium widget context (3.1 B3)
    static let distanceTotal       = "distanceTotal"
    static let weightTotal         = "weightTotal"
    static let distanceRemaining   = "distanceRemaining"
    static let weightRemaining     = "weightRemaining"
    static let challengeTitle      = "challengeTitle"
    static let challengeFraction   = "challengeFraction"
    static let challengeMonth      = "challengeMonth"   // yyyymm the challenge numbers belong to
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
    var distanceTotal: String = "0 mi"
    var weightTotal: String = "0 lbs"
    var distanceRemaining: String = "Log a walk or run!"
    var weightRemaining: String = "Log your first lift!"
    /// "❄️ Frosty Mile Chase", or nil when there's no challenge for the current month.
    var challengeTitle: String? = nil
    var challengeFraction: Double = 0

    static var empty: WidgetSnapshot {
        WidgetSnapshot(
            streak: 0,
            longestStreak: 0,
            activeThisWeek: false,
            distanceProgress: 0,
            weightProgress: 0,
            nextDistanceMilestone: "Log a walk or run!",
            nextWeightMilestone: "Log your first lift!",
            sillyTitle: "Future Legend"
        )
    }

    static func load(now: Date = .now) -> WidgetSnapshot {
        let d = UserDefaults(suiteName: WidgetDataKey.suiteName)
        var snapshot = WidgetSnapshot(
            streak:                   d?.integer(forKey: WidgetDataKey.streak)               ?? 0,
            longestStreak:            d?.integer(forKey: WidgetDataKey.longestStreak)        ?? 0,
            activeThisWeek:           d?.bool(forKey: WidgetDataKey.activeThisWeek)          ?? false,
            distanceProgress:         d?.double(forKey: WidgetDataKey.distanceProgress)      ?? 0,
            weightProgress:           d?.double(forKey: WidgetDataKey.weightProgress)        ?? 0,
            nextDistanceMilestone:    d?.string(forKey: WidgetDataKey.nextDistanceMilestone) ?? "Log a walk or run!",
            nextWeightMilestone:      d?.string(forKey: WidgetDataKey.nextWeightMilestone)   ?? "Log your first lift!",
            sillyTitle:               d?.string(forKey: WidgetDataKey.sillyTitle)            ?? "Future Legend"
        )
        if let total = d?.string(forKey: WidgetDataKey.distanceTotal)         { snapshot.distanceTotal = total }
        if let total = d?.string(forKey: WidgetDataKey.weightTotal)           { snapshot.weightTotal = total }
        if let text = d?.string(forKey: WidgetDataKey.distanceRemaining)      { snapshot.distanceRemaining = text }
        if let text = d?.string(forKey: WidgetDataKey.weightRemaining)        { snapshot.weightRemaining = text }
        // The app only refreshes these when it runs, so last month's challenge is hidden rather
        // than shown with stale progress once the month rolls over.
        let month = Calendar.current.dateComponents([.year, .month], from: now)
        let currentMonth = (month.year ?? 0) * 100 + (month.month ?? 0)
        if d?.integer(forKey: WidgetDataKey.challengeMonth) == currentMonth {
            snapshot.challengeTitle    = d?.string(forKey: WidgetDataKey.challengeTitle)
            snapshot.challengeFraction = d?.double(forKey: WidgetDataKey.challengeFraction) ?? 0
        }
        return snapshot
    }
}
