//
//  AppViewModel.swift
//  FunFitness
//

import Foundation
import SwiftData

@MainActor
@Observable
final class AppViewModel {
    // Source of truth — synced from ContentView's @Query result
    var activities: [ActivityLog] = []

    // MARK: - Computed totals (derived from activities; never cached)

    /// Total accumulated (effective) value for a given activity type. Weight multiplies by
    /// reps via `effectiveValue`; other types accumulate their value. One place, all types. (v2.2)
    func total(for type: ActivityType) -> Double {
        activities.lazy
            .filter { $0.activityType == type }
            .reduce(0) { $0 + $1.effectiveValue }
    }

    var totalDistance: Double { total(for: .distance) }

    // Accumulates value × (reps ?? 1) for each weight entry.
    var totalWeight: Double { total(for: .weight) }

    var totalActivities: Int { activities.count }

    // Most recently logged activity, for one-tap repeat.
    var lastActivity: ActivityLog? {
        activities.max { $0.loggedAt < $1.loggedAt }
    }

    var isActiveThisWeek: Bool {
        let calendar = Calendar.current
        let thisWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return activities.contains { activity in
            let activityWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: activity.loggedAt)
            return activityWeek == thisWeek
        }
    }

    // MARK: - Stored state

    var unlockedAchievementIds: Set<String> = []
    var activePack: ThemePack = ThemePackCatalog.default
    var unitPreference: UnitPreference = .imperial
    var pendingMilestones: [Milestone] = []
    var showMilestoneModal: Bool = false

    // MARK: - Streak state (updated by ContentView after each activity change)
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var isActiveThisWeekStreak: Bool = false
    var shieldsAvailable: Int = 0
    var pendingShieldActivation: Bool = false

    // MARK: - Milestone helpers

    func checkForMilestones(type: ActivityType, previousTotal: Double, newTotal: Double) -> [Milestone] {
        ComparisonEngine.checkForNewMilestones(
            type: type,
            previousTotal: previousTotal,
            newTotal: newTotal,
            unlockedIds: unlockedAchievementIds
        )
    }

    func remainingToNextMilestone(type: ActivityType) -> (milestone: Milestone?, remaining: Double) {
        let currentTotal = total(for: type)
        guard let next = ComparisonEngine.nextMilestone(for: type, currentTotal: currentTotal) else {
            return (nil, 0)
        }
        return (next, next.threshold - currentTotal)
    }

    func progressToNextMilestone(type: ActivityType) -> Double {
        let currentTotal = total(for: type)
        guard let next = ComparisonEngine.nextMilestone(for: type, currentTotal: currentTotal) else {
            return 1.0
        }
        let milestones = ComparisonEngine.milestones(for: type)
        let previousThreshold = milestones
            .filter { $0.threshold < next.threshold }
            .last?.threshold ?? 0.0
        let range = next.threshold - previousThreshold
        let progress = currentTotal - previousThreshold
        return range > 0 ? min(max(progress / range, 0), 1.0) : 0.0
    }

    func earnedMilestoneIds() -> Set<String> {
        // Every activity type contributes its earned milestones; iterating allCases means new
        // types participate automatically once they have a milestone array. (v2.2)
        var earned: Set<String> = []
        for type in ActivityType.allCases {
            let total = total(for: type)
            for milestone in ComparisonEngine.milestones(for: type) where milestone.threshold <= total {
                earned.insert(milestone.id)
            }
        }
        return earned
    }

    // MARK: - Absurdity Ticker

    /// "You're 43% of [ticker] [emoji]". Returns nil with no activities or past the last milestone.
    func absurdityTickerText(for type: ActivityType) -> String? {
        let currentTotal = total(for: type)
        guard currentTotal > 0 else { return nil }
        guard let next = ComparisonEngine.nextMilestone(for: type, currentTotal: currentTotal) else {
            return nil
        }
        let pct = Int(progressToNextMilestone(type: type) * 100)
        let reference = next.getTicker(for: activePack)
        let emoji = next.getEmoji(for: activePack)
        return "You're \(pct)% of \(reference) \(emoji)"
    }

    // MARK: - Unit-aware display helpers

    func displayDistance(_ km: Double) -> String {
        UnitConverter.distanceString(km, pref: unitPreference)
    }

    func displayWeight(_ kg: Double, reps: Int? = nil) -> String {
        UnitConverter.weightString(kg, reps: reps, pref: unitPreference)
    }

    /// Formatted running total for any activity type, in the user's units. Drives the
    /// data-driven Home/Progress cards so every type (incl. duration/reps) displays uniformly. (v2.2)
    func displayTotal(for type: ActivityType) -> String {
        UnitConverter.displayString(total(for: type), type: type, pref: unitPreference)
    }

    // MARK: - Silly Title

    var sillyTitle: SillyTitle {
        SillyTitleEngine.sillyTitle(unlockedCount: unlockedAchievementIds.count)
    }
}
