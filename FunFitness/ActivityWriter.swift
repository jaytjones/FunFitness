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
        surface: DistanceSurface? = nil,
        sessionID: UUID? = nil,
        exerciseID: String? = nil,
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
            healthKitUUID: healthKitUUID,
            // Only distance has a surface.
            surface: type == .distance ? surface : nil
        )
        activity.sessionID = sessionID
        // Only strength entries name an exercise. (3.1 C3)
        activity.exerciseID = SessionGrouping.isGroupable(type) ? exerciseID : nil
        context.insert(activity)
        // A strength entry not already in a session may join nearby ones (3.1 C1).
        if sessionID == nil, SessionGrouping.isGroupable(type) {
            autoGroup(activity, context: context)
        }

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
        surface: DistanceSurface? = nil,
        exerciseID: String? = nil,
        context: ModelContext,
        viewModel: AppViewModel,
        writeBackToHealth: Bool = false
    ) -> [Milestone] {
        let result = logSyncingViewModel(
            type: type, value: value, reps: reps, date: date, source: .manual, surface: surface,
            exerciseID: exerciseID, context: context, viewModel: viewModel
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
    /// route to Health and tags both records with its UUID. Keeps any heart rate read from Health
    /// (B2). Returns the new milestones.
    @discardableResult
    @MainActor
    static func logTracked(
        _ workout: TrackedWorkoutResult,
        surface: DistanceSurface? = nil,
        heartRate: HeartRateSummary? = nil,
        readsHeartRate: Bool = false,
        context: ModelContext,
        viewModel: AppViewModel,
        writeBackToHealth: Bool
    ) -> [Milestone] {
        let distanceKm = workout.distanceMeters / 1000
        let result = logSyncingViewModel(
            type: .distance, value: distanceKm, reps: nil, date: workout.endedAt, source: .tracked,
            surface: surface, context: context, viewModel: viewModel
        )
        result.activity.avgHeartRate = heartRate?.average
        result.activity.maxHeartRate = heartRate?.maximum

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

        // A Watch can take a little while to sync its readings to the phone, so if none were in
        // Health when the summary opened, look once more after saving. (3.1 B2)
        if heartRate == nil, readsHeartRate {
            let activity = result.activity
            Task { @MainActor in
                if let late = await HealthKitManager.shared.heartRateSummary(for: workout) {
                    activity.avgHeartRate = late.average
                    activity.maxHeartRate = late.maximum
                    try? context.save()
                }
            }
        }

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

    /// Shared by the main-app logging paths (and strength sessions, which need the saved entry):
    /// inserts via the context-only `log`, then mirrors the new entry and unlocked ids into
    /// `viewModel`. No Health write-back.
    @MainActor
    static func logSyncingViewModel(
        type: ActivityType,
        value: Double,
        reps: Int?,
        date: Date,
        source: ActivitySource,
        surface: DistanceSurface? = nil,
        sessionID: UUID? = nil,
        exerciseID: String? = nil,
        context: ModelContext,
        viewModel: AppViewModel
    ) -> (activity: ActivityLog, newMilestones: [Milestone]) {
        let result = log(
            type: type,
            value: value,
            reps: reps,
            date: date,
            source: source,
            surface: surface,
            sessionID: sessionID,
            exerciseID: exerciseID,
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
        let sessionID = activity.sessionID
        context.delete(activity)
        try? context.save()
        if let sessionID { cleanUpSession(sessionID, context: context) }
        StrengthSessionManager.shared.syncWithStore()   // keep a live session's set list in step (FB-0001)
    }

    // MARK: - Sessions (3.1 C1/C2)

    /// Logs `sets` identical sets ("3 × 10 @ 135 lbs") as one session; a single set is a normal
    /// log (which may auto-group). The sets are a second apart, ending at `date`, so they keep
    /// their order. Returns every milestone the sets crossed.
    @discardableResult
    @MainActor
    static func logSets(
        type: ActivityType,
        value: Double,
        reps: Int?,
        sets: Int,
        date: Date,
        exerciseID: String? = nil,
        context: ModelContext,
        viewModel: AppViewModel
    ) -> [Milestone] {
        guard sets > 1, SessionGrouping.isGroupable(type) else {
            return log(type: type, value: value, reps: reps, date: date, exerciseID: exerciseID, context: context, viewModel: viewModel)
        }
        let first = date.addingTimeInterval(-Double(sets - 1))
        let session = WorkoutSession(startedAt: first, endedAt: date)
        context.insert(session)
        var milestones: [Milestone] = []
        for index in 0..<sets {
            milestones += logSyncingViewModel(
                type: type, value: value, reps: reps, date: first.addingTimeInterval(Double(index)),
                source: .manual, sessionID: session.id, exerciseID: exerciseID, context: context, viewModel: viewModel
            ).newMilestones
        }
        return milestones
    }

    /// Puts a just-inserted strength log into an automatic session with nearby strength logs,
    /// per `SessionGrouping.decide`. Context-only, so Siri's repeat-last groups too.
    static func autoGroup(_ activity: ActivityLog, context: ModelContext) {
        let start = activity.loggedAt.addingTimeInterval(-SessionGrouping.autoGroupGap)
        let end = activity.loggedAt.addingTimeInterval(SessionGrouping.autoGroupGap)
        let ownID = activity.id
        let nearby = ((try? context.fetch(FetchDescriptor<ActivityLog>(
            predicate: #Predicate { $0.loggedAt >= start && $0.loggedAt <= end && $0.id != ownID }
        ))) ?? []).filter { SessionGrouping.isGroupable($0.activityType) }
        guard !nearby.isEmpty else { return }

        let sessionIDs = Array(Set(nearby.compactMap(\.sessionID)))
        let sessions = sessionIDs.isEmpty ? [] : ((try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { sessionIDs.contains($0.id) }
        ))) ?? [])
        let autoSessionIDs = Set(sessions.filter(\.isAutoGrouped).map(\.id))
        let candidates = nearby.map {
            SessionGrouping.Candidate(
                id: $0.id, date: $0.loggedAt, sessionID: $0.sessionID,
                sessionIsAutoGrouped: $0.sessionID.map(autoSessionIDs.contains) ?? false,
                excludedFromAutoGrouping: $0.excludedFromAutoGrouping
            )
        }

        switch SessionGrouping.decide(newDate: activity.loggedAt, candidates: candidates) {
        case .none:
            return
        case .join(let sessionID):
            activity.sessionID = sessionID
            if let session = sessions.first(where: { $0.id == sessionID }) {
                session.startedAt = min(session.startedAt, activity.loggedAt)
                session.endedAt = max(session.endedAt, activity.loggedAt)
            }
        case .startSession(let otherID):
            guard let other = nearby.first(where: { $0.id == otherID }) else { return }
            let session = WorkoutSession(
                startedAt: min(other.loggedAt, activity.loggedAt),
                endedAt: max(other.loggedAt, activity.loggedAt),
                isAutoGrouped: true
            )
            context.insert(session)
            other.sessionID = session.id
            activity.sessionID = session.id
        }
    }

    /// Deletes a whole session: every set in it and the session record.
    @MainActor
    static func deleteSession(_ sessionID: UUID, context: ModelContext, viewModel: AppViewModel) {
        viewModel.revokeAchievementsOnNextReconcile = true
        let logs = logs(inSession: sessionID, context: context)
        let ids = Set(logs.map(\.id))
        viewModel.activities.removeAll { ids.contains($0.id) }
        for log in logs { context.delete(log) }
        for session in sessionRecords(sessionID, context: context) { context.delete(session) }
        try? context.save()
        StrengthSessionManager.shared.syncWithStore()   // keep a live session's set list in step (FB-0001)
    }

    /// Splits a session back into separate entries that won't be auto-grouped again.
    static func ungroupSession(_ sessionID: UUID, context: ModelContext) {
        for log in logs(inSession: sessionID, context: context) {
            log.sessionID = nil
            log.excludedFromAutoGrouping = true
        }
        for session in sessionRecords(sessionID, context: context) { context.delete(session) }
        try? context.save()
        StrengthSessionManager.shared.syncWithStore()   // keep a live session's set list in step (FB-0001)
    }

    /// Takes one set out of its session; it won't be auto-grouped again.
    static func removeFromSession(_ activity: ActivityLog, context: ModelContext) {
        guard let sessionID = activity.sessionID else { return }
        activity.sessionID = nil
        activity.excludedFromAutoGrouping = true
        try? context.save()
        cleanUpSession(sessionID, context: context)
        StrengthSessionManager.shared.syncWithStore()   // keep a live session's set list in step (FB-0001)
    }

    /// After a set leaves a session: drop an emptied session, or dissolve an automatic one that's
    /// down to a single set. The session's start/end stay as they are — they're the workout's
    /// time (live-timed or set by the person, C4), not just the span of its sets.
    static func cleanUpSession(_ sessionID: UUID, context: ModelContext) {
        let remaining = logs(inSession: sessionID, context: context)
        let records = sessionRecords(sessionID, context: context)
        if remaining.isEmpty || (remaining.count == 1 && records.contains(where: \.isAutoGrouped)) {
            for log in remaining { log.sessionID = nil }
            for session in records { context.delete(session) }
        }
        try? context.save()
    }

    /// Saves a timed session to Health as a strength workout with its estimated calories (C4/C5)
    /// and remembers the workout's id. Returns false when untimed or the save fails. Later edits
    /// aren't sent to Health.
    @discardableResult
    @MainActor
    static func saveSessionToHealth(_ session: WorkoutSession, weightKg: Double?, context: ModelContext) async -> Bool {
        guard session.isTimed, session.healthKitWorkoutUUID == nil else { return false }
        let kcal = CalorieEstimator.kcal(seconds: session.durationSeconds, weightKg: weightKg)
        guard let uuid = await HealthKitManager.shared.saveStrengthSession(
            start: session.startedAt, end: session.endedAt, kcal: kcal, isIndoor: session.isIndoor
        ) else { return false }
        session.healthKitWorkoutUUID = uuid
        try? context.save()
        return true
    }

    private static func logs(inSession sessionID: UUID, context: ModelContext) -> [ActivityLog] {
        let id: UUID? = sessionID
        return (try? context.fetch(FetchDescriptor<ActivityLog>(predicate: #Predicate { $0.sessionID == id }))) ?? []
    }

    private static func sessionRecords(_ sessionID: UUID, context: ModelContext) -> [WorkoutSession] {
        (try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID }))) ?? []
    }

    // MARK: - Helpers

    private static func totalValue(type: ActivityType, in activities: [ActivityLog]) -> Double {
        activities.lazy
            .filter { $0.activityType == type }
            .reduce(0) { $0 + $1.effectiveValue }
    }
}
