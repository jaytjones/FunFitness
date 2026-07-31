//
//  AppViewModel.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class AppViewModel {
    // Source of truth — synced from ContentView's @Query result
    var activities: [ActivityLog] = []

    // MARK: - Computed totals (never cached; always derived from activities)

    var totalDistance: Double {
        activities.lazy.filter { $0.activityType == .distance }.reduce(0) { $0 + $1.value }
    }

    var totalWeight: Double {
        activities.lazy.filter { $0.activityType == .weight }.reduce(0) { $0 + $1.value }
    }

    var totalActivities: Int { activities.count }

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
    var pendingMilestones: [Milestone] = []
    var showMilestoneModal: Bool = false

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
        // milestones are sorted ascending by threshold (enforced by static let)
        let previousThreshold = milestones
            .filter { $0.threshold < next.threshold }
            .last?.threshold ?? 0.0
        let range = next.threshold - previousThreshold
        let progress = currentTotal - previousThreshold
        return range > 0 ? min(max(progress / range, 0), 1.0) : 0.0
    }

    // Returns the set of milestone IDs that have been earned based on current totals.
    // Used by ContentView to idempotently reconcile achievements after launch or data changes.
    func earnedMilestoneIds() -> Set<String> {
        let earnedDist = ComparisonEngine.distanceMilestones.filter { $0.threshold <= totalDistance }.map(\.id)
        let earnedWt  = ComparisonEngine.weightMilestones.filter  { $0.threshold <= totalWeight  }.map(\.id)
        return Set(earnedDist + earnedWt)
    }

    // MARK: - Absurdity Ticker

    /// Returns a fractional comparison string for the Home screen ticker, e.g.
    /// "You're 43% of 2 blue whales 🐳". Returns nil if no activities are logged
    /// or all milestones have been cleared.
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
}
