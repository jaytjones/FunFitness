//
//  ActivityWriter.swift
//  FunFitness
//
//  UI-free service that inserts an activity and unlocks any resulting
//  achievements. Shared by LogActivitySheet, the Home "Repeat last" button,
//  and the Siri Shortcut intent so the logging logic lives in exactly one place.
//

import Foundation
import SwiftData

struct ActivityWriter {

    /// Inserts a new activity into `context`, unlocks any milestones it crosses,
    /// and returns the inserted log plus the newly unlocked milestones.
    ///
    /// This variant is context-only (no view model) so it can run from an
    /// App Intent. Totals are derived from `existingActivities`.
    @discardableResult
    static func log(
        type: ActivityType,
        value: Double,
        reps: Int?,
        date: Date,
        source: ActivitySource = .manual,
        healthKitUUID: UUID? = nil,
        existingActivities: [ActivityLog],
        unlockedIds: Set<String>,
        context: ModelContext
    ) -> (activity: ActivityLog, newMilestones: [Milestone]) {
        let effectiveReps = (type == .weight) ? reps : nil

        let previousTotal = totalValue(type: type, in: existingActivities)
        let added = (type == .weight) ? value * Double(effectiveReps ?? 1) : value
        let newTotal = previousTotal + added

        let activity = ActivityLog(
            type: type,
            value: value,
            reps: effectiveReps,
            loggedAt: date,
            source: source,
            healthKitUUID: healthKitUUID
        )
        context.insert(activity)

        let newMilestones = ComparisonEngine.checkForNewMilestones(
            type: type,
            previousTotal: previousTotal,
            newTotal: newTotal,
            unlockedIds: unlockedIds
        )
        for milestone in newMilestones {
            context.insert(UnlockedAchievement(milestoneId: milestone.id))
        }

        try? context.save()
        return (activity, newMilestones)
    }

    /// Main-app convenience: logs via `context`, then keeps `viewModel` in sync
    /// (appends the activity, records unlocked ids) and returns the new
    /// milestones so the caller can drive the celebration modal.
    @discardableResult
    @MainActor
    static func log(
        type: ActivityType,
        value: Double,
        reps: Int?,
        date: Date,
        context: ModelContext,
        viewModel: AppViewModel,
        writeBackToHealth: Bool = false
    ) -> [Milestone] {
        let result = log(
            type: type,
            value: value,
            reps: reps,
            date: date,
            existingActivities: viewModel.activities,
            unlockedIds: viewModel.unlockedAchievementIds,
            context: context
        )

        viewModel.activities.append(result.activity)
        for milestone in result.newMilestones {
            viewModel.unlockedAchievementIds.insert(milestone.id)
        }

        // Write-back (distance only). Fire-and-forget: the log already exists;
        // once Health returns the new workout's UUID we tag the entry so our
        // own write-back isn't re-imported later (echo prevention).
        if writeBackToHealth, type == .distance {
            let activity = result.activity
            Task { @MainActor in
                if let uuid = await HealthKitManager.shared.saveDistanceWorkout(distanceKm: value, date: date) {
                    activity.healthKitUUID = uuid
                    try? context.save()
                }
            }
        }
        return result.newMilestones
    }

    // MARK: - Helpers

    private static func totalValue(type: ActivityType, in activities: [ActivityLog]) -> Double {
        activities.lazy
            .filter { $0.activityType == type }
            .reduce(0) { $0 + $1.effectiveValue }
    }
}
