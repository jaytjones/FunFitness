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

    var totalDistance: Double {
        activities.lazy.filter { $0.activityType == .distance }.reduce(0) { $0 + $1.value }
    }

    // Accumulates value × (reps ?? 1) for each weight entry.
    var totalWeight: Double {
        activities.lazy.filter { $0.activityType == .weight }.reduce(0) { $0 + $1.effectiveValue }
    }

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
    var activeTheme: Theme = .animals
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
        let currentTotal = type == .distance ? totalDistance : totalWeight
        guard let next = ComparisonEngine.nextMilestone(for: type, currentTotal: currentTotal) else {
            return (nil, 0)
        }
        return (next, next.threshold - currentTotal)
    }

    func progressToNextMilestone(type: ActivityType) -> Double {
        let currentTotal = type == .distance ? totalDistance : totalWeight
        guard let next = ComparisonEngine.nextMilestone(for: type, currentTotal: currentTotal) else {
            return 1.0
        }
        let milestones = type == .distance ? ComparisonEngine.distanceMilestones : ComparisonEngine.weightMilestones
        let previousThreshold = milestones
            .filter { $0.threshold < next.threshold }
            .last?.threshold ?? 0.0
        let range = next.threshold - previousThreshold
        let progress = currentTotal - previousThreshold
        return range > 0 ? min(max(progress / range, 0), 1.0) : 0.0
    }

    func earnedMilestoneIds() -> Set<String> {
        let earnedDist = ComparisonEngine.distanceMilestones.filter { $0.threshold <= totalDistance }.map(\.id)
        let earnedWt   = ComparisonEngine.weightMilestones.filter  { $0.threshold <= totalWeight  }.map(\.id)
        return Set(earnedDist + earnedWt)
    }

    // MARK: - Absurdity Ticker

    /// "You're 43% of [ticker] [emoji]". Returns nil with no activities or past the last milestone.
    func absurdityTickerText(for type: ActivityType) -> String? {
        let currentTotal = type == .distance ? totalDistance : totalWeight
        guard currentTotal > 0 else { return nil }
        guard let next = ComparisonEngine.nextMilestone(for: type, currentTotal: currentTotal) else {
            return nil
        }
        let pct = Int(progressToNextMilestone(type: type) * 100)
        let reference = next.getTicker(for: activeTheme)
        let emoji = next.getEmoji(for: activeTheme)
        return "You're \(pct)% of \(reference) \(emoji)"
    }

    // MARK: - Unit-aware display helpers

    func displayDistance(_ km: Double) -> String {
        UnitConverter.distanceString(km, pref: unitPreference)
    }

    func displayWeight(_ kg: Double, reps: Int? = nil) -> String {
        UnitConverter.weightString(kg, reps: reps, pref: unitPreference)
    }

    // MARK: - Silly Title

    var sillyTitle: SillyTitle {
        SillyTitleEngine.sillyTitle(unlockedCount: unlockedAchievementIds.count)
    }
}
