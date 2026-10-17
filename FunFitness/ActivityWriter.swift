//
//  ActivityWriter.swift
//  FunFitness
//
//  UI-free service that inserts an activity and unlocks any resulting
//  achievements. Shared by LogActivitySheet, the Home "Repeat last" button,
//  live walk/run tracking, and the Siri Shortcut intent so the logging logic
//  lives in exactly one place.
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
        // Only rep-using types (weight) keep a rep count; others store the value alone.
        let effectiveReps = type.usesReps ? reps : nil

        let previousTotal = totalValue(type: type, in: existingActivities)
        let added = type.usesReps ? value * Double(effectiveReps ?? 1) : value
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
        let result = logSyncingViewModel(
            type: type, value: value, reps: reps, date: date, source: .manual,
            context: context, viewModel: viewModel
        )

        // Write-back (distance only — HealthKit has no "weight lifted" metric). Fire-and-forget:
        // the log already exists; once Health returns the new workout's UUID we tag the entry so
        // our own write-back isn't re-imported later (echo prevention).
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

    /// Logs a GPS-tracked walk/run (3.1 B1a): a `.tracked` distance entry dated at the finish,
    /// plus its downsampled `RouteSummary`. With Health saving on, also saves a real workout and
    /// route to Health and tags both records with its UUID. Returns the new milestones.
    @discardableResult
    @MainActor
    static func logTracked(
        _ workout: TrackedWorkoutResult,
        context: ModelContext,
        viewModel: AppViewModel,
        writeBackToHealth: Bool
    ) -> [Milestone] {
        let distanceKm = workout.distanceMeters / 1000
        let result = logSyncingViewModel(
            type: .distance, value: distanceKm, reps: nil, date: workout.endedAt, source: .tracked,
            context: context, viewModel: viewModel
        )

        let route = RouteSummary(
            activityID: result.activity.id,
            polyline: RoutePolyline.encode(RouteMath.downsample(workout.points)),
            distanceKm: distanceKm,
            startedAt: workout.startedAt,
            endedAt: workout.endedAt,
            movingSeconds: workout.movingSeconds,
            kind: workout.kind
        )
        context.insert(route)
        try? context.save()

        if writeBackToHealth {
            let activity = result.activity
            Task { @MainActor in
                if let uuid = await HealthKitManager.shared.saveTrackedWorkout(workout) {
                    activity.healthKitUUID = uuid
                    route.healthKitWorkoutUUID = uuid
                    try? context.save()
                }
            }
        }
        return result.newMilestones
    }

    /// Shared by the main-app logging paths: inserts via the context-only `log`, then mirrors the
    /// new entry and unlocked ids into `viewModel`.
    @MainActor
    private static func logSyncingViewModel(
        type: ActivityType,
        value: Double,
        reps: Int?,
        date: Date,
        source: ActivitySource,
        context: ModelContext,
        viewModel: AppViewModel
    ) -> (activity: ActivityLog, newMilestones: [Milestone]) {
        let result = log(
            type: type,
            value: value,
            reps: reps,
            date: date,
            source: source,
            existingActivities: viewModel.activities,
            unlockedIds: viewModel.unlockedAchievementIds,
            context: context
        )
        viewModel.activities.append(result.activity)
        for milestone in result.newMilestones {
            viewModel.unlockedAchievementIds.insert(milestone.id)
        }
        return result
    }

    /// Deletes a user's log entry and keeps `viewModel` in sync. Shared by Activity History and
    /// Home's Recent Activity card. (2.4.4)
    @MainActor
    static func delete(_ activity: ActivityLog, context: ModelContext, viewModel: AppViewModel) {
        // A local delete may drop a total below a milestone, so let ContentView's reconcile
        // (triggered by the activities change) revoke badges this time.
        viewModel.revokeAchievementsOnNextReconcile = true
        viewModel.activities.removeAll { $0.id == activity.id }
        // A tracked entry's route goes with it. (3.1)
        if activity.source == .tracked {
            let id = activity.id
            let routes = (try? context.fetch(FetchDescriptor<RouteSummary>(predicate: #Predicate { $0.activityID == id }))) ?? []
            for route in routes { context.delete(route) }
        }
        context.delete(activity)
        try? context.save()
    }

    // MARK: - Helpers

    private static func totalValue(type: ActivityType, in activities: [ActivityLog]) -> Double {
        activities.lazy
            .filter { $0.activityType == type }
            .reduce(0) { $0 + $1.effectiveValue }
    }
}
