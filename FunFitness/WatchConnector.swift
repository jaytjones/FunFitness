//
//  WatchConnector.swift
//  FunFitness
//
//  The iPhone end of the Apple Watch link (3.1). Saves entries logged on the Watch through
//  ActivityWriter, and keeps the Watch's exercise list and units current. Message types live in
//  WatchShared/WatchMessages.swift.
//
//  Watch walks/runs are saved to Health on the Watch and also sent here tagged with the Health
//  workout's UUID, so they count even when Health import is off; the import's exact-UUID de-dup
//  keeps them from counting twice.
//

import Foundation
import SwiftData
import WatchConnectivity

@MainActor
final class WatchConnector: NSObject {
    static let shared = WatchConnector()

    private var context: ModelContext?
    private weak var viewModel: AppViewModel?
    /// Entries that arrived before ContentView configured a store.
    private var pending: [WatchQuickLog] = []
    private var lastSentContext: WatchContext?

    /// Ids already saved, so a re-delivered transfer isn't logged twice. Kept small.
    private static let processedKey = "watchProcessedLogIDs"
    private static let processedLimit = 200

    private override init() {}

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Called by ContentView once the store and view model exist; saves anything queued.
    func configure(context: ModelContext, viewModel: AppViewModel) {
        self.context = context
        self.viewModel = viewModel
        let queued = pending
        pending = []
        for log in queued { save(log) }
    }

    // MARK: - Phone → Watch

    /// Sends the exercise list, units and last-used values, if they changed.
    func sendContext(pref: UnitPreference, viewModel: AppViewModel) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        let library = ExerciseLibrary.shared
        let exercises = library.exercises(for: .weight).map { WatchExercise(id: $0.id, name: $0.name, kind: .lift) }
            + library.exercises(for: .reps).map { WatchExercise(id: $0.id, name: $0.name, kind: .bodyweight) }
        var lastIDs: [String: String] = [:]
        if let id = viewModel.lastExerciseID(for: .weight) { lastIDs[WatchQuickLog.Kind.lift.rawValue] = id }
        if let id = viewModel.lastExerciseID(for: .reps) { lastIDs[WatchQuickLog.Kind.bodyweight.rawValue] = id }
        let lastLift = viewModel.activities.filter { $0.activityType == .weight }.max { $0.loggedAt < $1.loggedAt }
        var context = WatchContext(
            usesMetric: pref == .metric,
            exercises: exercises,
            lastExerciseIDs: lastIDs,
            lastLiftKg: lastLift?.value,
            lastLiftReps: lastLift?.reps
        )
        context.currentStreakWeeks = viewModel.currentStreak
        context.effortPoints = weeklyEffortPoints(viewModel: viewModel)
        context.effortTarget = EffortEngine.weeklyTarget
        context.totalDistanceKm = viewModel.totalDistance
        context.totalLiftedKg = viewModel.totalWeight
        // Compared without the timestamp, so an unchanged context isn't re-sent.
        guard context != lastSentContext else { return }
        let comparable = context
        context.updatedAt = Date()
        do {
            try WCSession.default.updateApplicationContext(context.encoded())
            lastSentContext = comparable
        } catch {
            // Not reachable yet; the next change or launch tries again.
        }
    }

    /// This week's Effort Points, the same number as the Home card.
    private func weeklyEffortPoints(viewModel: AppViewModel) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        let logs = viewModel.activities.filter { $0.loggedAt >= cutoff }
        let routes = (try? context?.fetch(FetchDescriptor<RouteSummary>(predicate: #Predicate { $0.startedAt >= cutoff }))) ?? []
        let sessions = (try? context?.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.startedAt >= cutoff }))) ?? []
        let age = (try? context?.fetch(FetchDescriptor<UserProfile>()))?.first?.computedAge
        let entries = EffortEngine.entries(
            logs: logs.map(EffortEngine.LogFacts.init),
            routes: routes.map(EffortEngine.RouteFacts.init),
            sessions: sessions.map(EffortEngine.SessionFacts.init)
        )
        return EffortEngine.weeklySummary(entries: entries, age: age, now: Date()).points
    }

    // MARK: - Watch → phone

    func receive(_ log: WatchQuickLog) {
        guard context != nil, viewModel != nil else {
            pending.append(log)
            return
        }
        save(log)
    }

    private func save(_ log: WatchQuickLog) {
        guard let context, let viewModel else { return }
        var processed = UserDefaults.standard.stringArray(forKey: Self.processedKey) ?? []
        guard !processed.contains(log.id.uuidString) else { return }

        let milestones: [Milestone]
        switch log.kind {
        case .lift:
            milestones = ActivityWriter.logSyncingViewModel(
                type: .weight, value: log.value, reps: log.reps, date: log.date, source: .manual,
                exerciseID: log.exerciseID, context: context, viewModel: viewModel
            ).newMilestones
        case .bodyweight:
            milestones = ActivityWriter.logSyncingViewModel(
                type: .reps, value: log.value, reps: nil, date: log.date, source: .manual,
                exerciseID: log.exerciseID, context: context, viewModel: viewModel
            ).newMilestones
        case .duration:
            milestones = ActivityWriter.logSyncingViewModel(
                type: .duration, value: log.value, reps: nil, date: log.date, source: .manual,
                context: context, viewModel: viewModel
            ).newMilestones
        case .distance:
            // Already imported from Health (import ran first)? Then it's counted.
            if let uuid = log.healthKitUUID,
               ((try? context.fetchCount(FetchDescriptor<ActivityLog>(predicate: #Predicate { $0.healthKitUUID == uuid }))) ?? 0) > 0 {
                milestones = []
            } else {
                // With moving time (build 12+) it's a tracked walk/run like one recorded on the phone:
                // it gets a RouteSummary (the map, when there's a route) and real Effort Points.
                let isTracked = log.movingSeconds != nil && log.trackedKind != nil
                let source: ActivitySource = isTracked ? .tracked : (log.healthKitUUID == nil ? .manual : .healthKit)
                let result = ActivityWriter.logSyncingViewModel(
                    type: .distance, value: log.value, reps: nil, date: log.date,
                    source: source, healthKitUUID: log.healthKitUUID,
                    context: context, viewModel: viewModel
                )
                result.activity.avgHeartRate = log.averageHeartRate
                result.activity.maxHeartRate = log.maximumHeartRate
                if isTracked, let moving = log.movingSeconds, let kind = log.trackedKind {
                    context.insert(RouteSummary(
                        activityID: result.activity.id,
                        polyline: log.routePolyline,
                        distanceKm: log.value,
                        startedAt: log.startDate ?? log.date.addingTimeInterval(-moving),
                        endedAt: log.date,
                        movingSeconds: moving,
                        kind: kind,
                        healthKitWorkoutUUID: log.healthKitUUID
                    ))
                }
                try? context.save()
                milestones = result.newMilestones
            }
        }
        viewModel.celebrateOrDefer(milestones)

        processed.append(log.id.uuidString)
        UserDefaults.standard.set(Array(processed.suffix(Self.processedLimit)), forKey: Self.processedKey)
    }
}

extension WatchConnector: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to a different Watch: start talking to the new one.
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let log = WatchQuickLog.decode(userInfo) else { return }
        Task { @MainActor in WatchConnector.shared.receive(log) }
    }
}
