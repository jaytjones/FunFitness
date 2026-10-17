//
//  WorkoutLiveActivityController.swift
//  FunFitness
//
//  Starts, updates, and ends the workout Live Activity from `WorkoutTracker` (3.1 B1b), and runs
//  its Lock Screen / Dynamic Island buttons. Updates are local (no push tokens) and throttled:
//  the clock ticks by itself via `Text(timerInterval:)`, so only distance/pace need refreshing.
//

import Foundation
import ActivityKit

// MARK: - Content (pure)

/// Builds the Live Activity's content from tracker numbers. Pure so it's unit-tested.
enum WorkoutLiveActivityContent {

    /// Minimum gap between routine updates; pause/resume/finish always update immediately.
    static let updateInterval: TimeInterval = 10

    static func state(
        isPaused: Bool,
        isFinished: Bool,
        movingSeconds: TimeInterval,
        distanceMeters: Double,
        now: Date,
        pref: UnitPreference,
        packId: String
    ) -> WorkoutActivityAttributes.ContentState {
        let distanceKm = distanceMeters / 1000
        let pace = RouteMath.paceSecondsPerKm(distanceMeters: distanceMeters, movingSeconds: movingSeconds)
        return WorkoutActivityAttributes.ContentState(
            isPaused: isPaused,
            isFinished: isFinished,
            timerStart: now.addingTimeInterval(-movingSeconds),
            elapsedText: UnitConverter.elapsedString(movingSeconds),
            primaryValue: UnitConverter.distanceString(distanceKm, pref: pref),
            primaryLabel: "Distance",
            secondaryValue: UnitConverter.paceString(secondsPerKm: pace, pref: pref),
            secondaryLabel: "Pace",
            comparison: isFinished
                ? "Open FunFitness to save it"
                : ReferenceUnitEngine.distancePhrase(distanceKm: distanceKm, pref: pref, packId: packId)
        )
    }

    static func shouldUpdate(lastUpdate: Date?, now: Date, force: Bool) -> Bool {
        guard !force, let lastUpdate else { return true }
        return now.timeIntervalSince(lastUpdate) >= updateInterval
    }
}

// MARK: - Controller

@MainActor
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()

    /// Display settings, set when a workout starts so the extension gets the user's units/pack.
    private var pref: UnitPreference = .imperial
    private var packId: String = ThemePackCatalog.default.id

    private var activity: Activity<WorkoutActivityAttributes>?
    private var lastUpdate: Date?

    private init() {}

    func configure(pref: UnitPreference, packId: String) {
        self.pref = pref
        self.packId = packId
    }

    /// Starts the Live Activity for a workout the tracker just began. Silently does nothing when
    /// Live Activities are off in Settings — tracking works the same without one.
    func start(for tracker: WorkoutTracker, at date: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAll()
        let attributes = WorkoutActivityAttributes(title: tracker.kind.displayName, emoji: tracker.kind.emoji)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state(for: tracker, at: date), staleDate: nil),
                pushType: nil
            )
            lastUpdate = date
        } catch {
            activity = nil   // e.g. too many Live Activities running; tracking continues regardless
        }
    }

    /// Pushes new numbers. Routine (per-GPS-fix) calls are throttled; pass `force` for state changes.
    func update(for tracker: WorkoutTracker, force: Bool = false, at date: Date = Date()) {
        guard let activity,
              WorkoutLiveActivityContent.shouldUpdate(lastUpdate: lastUpdate, now: date, force: force) else { return }
        lastUpdate = date
        let content = ActivityContent(state: state(for: tracker, at: date), staleDate: nil)
        let id = activity.id
        Task { await Self.update(activityID: id, to: content) }
    }

    /// Ends the Live Activity immediately (saved, discarded, or abandoned), plus any left over from
    /// a previous launch (e.g. the app was closed mid-run).
    func endAll() {
        // Snapshot ids now, so a Live Activity started right after this call isn't swept up too.
        let ids = Activity<WorkoutActivityAttributes>.activities.map(\.id)
        activity = nil
        lastUpdate = nil
        guard !ids.isEmpty else { return }
        Task { await Self.end(activityIDs: ids) }
    }

    // `Activity` isn't Sendable, so these look activities up by id off the main actor instead of
    // carrying one across actors.
    private nonisolated static func update(activityID: String, to content: ActivityContent<WorkoutActivityAttributes.ContentState>) async {
        for running in Activity<WorkoutActivityAttributes>.activities where running.id == activityID {
            await running.update(content)
        }
    }

    private nonisolated static func end(activityIDs: [String]) async {
        for running in Activity<WorkoutActivityAttributes>.activities where activityIDs.contains(running.id) {
            await running.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Clears orphaned Live Activities at launch when no workout is being tracked.
    func endOrphanedActivities(tracker: WorkoutTracker) {
        guard tracker.phase == .idle, !Activity<WorkoutActivityAttributes>.activities.isEmpty else { return }
        endAll()
    }

    private func state(for tracker: WorkoutTracker, at date: Date) -> WorkoutActivityAttributes.ContentState {
        WorkoutLiveActivityContent.state(
            isPaused: tracker.phase == .paused,
            isFinished: tracker.phase == .finished,
            movingSeconds: tracker.result?.movingSeconds ?? tracker.movingSeconds(at: date),
            distanceMeters: tracker.distanceMeters,
            now: date,
            pref: pref,
            packId: packId
        )
    }
}

// MARK: - Button handling

/// Runs Live Activity button presses (the intents live in Shared/WorkoutLiveActivity.swift).
enum WorkoutLiveActivityActions {
    static func handle(_ command: WorkoutLiveActivityCommand) async {
        let tracker = WorkoutTracker.shared
        switch command {
        case .pause:  tracker.pause()
        case .resume: tracker.resume()
        // Finishing doesn't save: the summary opens the next time the app comes to the
        // foreground, so nothing is logged without the person reviewing it.
        case .end:    tracker.finish()
        }
    }
}
