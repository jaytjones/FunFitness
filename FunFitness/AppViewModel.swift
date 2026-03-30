//
//  AppViewModel.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import Foundation
import SwiftData

@Observable
class AppViewModel {
    var totalDistance: Double = 0.0
    var totalWeight: Double = 0.0
    var totalActivities: Int = 0
    var isActiveThisWeek: Bool = false
    var unlockedAchievementIds: Set<String> = []
    var activeTheme: Theme = .animals
    var pendingMilestones: [Milestone] = []
    var showMilestoneModal: Bool = false
    
    func calculateTotals(activities: [ActivityLog]) {
        totalDistance = activities
            .filter { $0.activityType == .distance }
            .reduce(0) { $0 + $1.value }
        
        totalWeight = activities
            .filter { $0.activityType == .weight }
            .reduce(0) { $0 + $1.value }
        
        totalActivities = activities.count
        
        // Check if any activity was logged this week
        let calendar = Calendar.current
        let startOfWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        
        isActiveThisWeek = activities.contains { activity in
            let activityWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: activity.loggedAt)
            return activityWeek == startOfWeek
        }
    }
    
    func loadUnlockedAchievements(_ achievements: [UnlockedAchievement]) {
        unlockedAchievementIds = Set(achievements.map { $0.milestoneId })
    }
    
    func checkForMilestones(
        type: ActivityType,
        previousTotal: Double,
        newTotal: Double
    ) -> [Milestone] {
        return ComparisonEngine.checkForNewMilestones(
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
        
        // Find the previous milestone threshold
        let milestones = type == .distance ? ComparisonEngine.distanceMilestones : ComparisonEngine.weightMilestones
        let previousThreshold = milestones
            .filter { $0.threshold < next.threshold }
            .last?.threshold ?? 0.0
        
        let range = next.threshold - previousThreshold
        let progress = currentTotal - previousThreshold
        
        return range > 0 ? min(max(progress / range, 0), 1.0) : 0.0
    }
}
