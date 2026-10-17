//
//  WorkoutLiveActivityController.swift
//  FunFitness
//
//  Starts, updates, and ends the workout Live Activity from `WorkoutTracker` (3.1 B1b) and
//  `StrengthSessionManager` (B1c), and runs its Lock Screen / Dynamic Island buttons. Updates are
//  local (no push tokens); walk/run updates are throttled since the clock ticks by itself via
//  `Text(timerInterval:)` and only distance/pace need refreshing.
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

    /// Strength session content (3.1 B1c): sets done, last set, a rest countdown, and a running
    /// "weight lifted" comparison.
    static func strengthState(
        session: StrengthSession,
        isFinished: Bool,
        elapsedSeconds: TimeInterval,
        now: Date,
        pref: UnitPreference,
        packId: String
    ) -> WorkoutActivityAttributes.ContentState {
        let resting = !isFinished && session.isResting(at: now)
        return WorkoutActivityAttributes.ContentState(
            isPaused: false,
            isFinished: isFinished,
            timerStart: now.addingTimeInterval(-elapsedSeconds),
            elapsedText: UnitConverter.elapsedString(elapsedSeconds),
            primaryValue: "\(session.setCount)",
            primaryLabel: session.setCount == 1 ? "Set" : "Sets",
            secondaryValue: session.lastSet.map { setText($0, pref: pref) } ?? "—",
            secondaryLabel: "Last set",
            comparison: strengthComparison(session: session, isFinished: isFinished, pref: pref, packId: packId),
            restStart: resting ? session.restStartedAt : nil,
            restEnd: resting ? session.restEndsAt : nil,
            canLogSet: !isFinished && session.lastSet != nil
        )
    }

    /// "135 lbs × 10" or "20 reps".
    static func setText(_ set: StrengthSet, pref: UnitPreference) -> String {
        UnitConverter.displayString(set.valueSI, type: set.type, reps: set.reps, pref: pref)
    }

    private static func strengthComparison(session: StrengthSession, isFinished: Bool, pref: UnitPreference, packId: String) -> String? {
        let lifted = session.totalLiftedKg
        let liftedText = lifted > 0 ? UnitConverter.weightString(lifted, pref: pref) : nil
        if isFinished {
            let sets = "\(session.setCount) set\(session.setCount == 1 ? "" : "s") saved"
            return liftedText.map { "\(sets) · \($0) lifted" } ?? sets
        }
        if let liftedText, let fit = ReferenceUnitEngine.bestFit(total: lifted, type: .weight, packId: packId) {
            return "\(liftedText) lifted — \(fit.phrase) \(fit.unit.emoji)"
        }
        let reps = session.totalBodyweightReps
        return reps > 0 ? "\(reps) bodyweight reps so far" : nil
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
        request(
            WorkoutActivityAttributes(title: tracker.kind.displayName, emoji: tracker.kind.emoji),
            state: state(for: tracker, at: date),
            at: date
        )
    }

    /// Starts the Live Activity for a strength session (3.1 B1c).
    func startStrength(for manager: StrengthSessionManager, at date: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, let state = strengthState(for: manager, at: date) else { return }
        request(WorkoutActivityAttributes(title: "Strength", emoji: "🏋️", isStrength: true), state: state, at: date)
    }

    /// Strength changes are discrete (a set, a skipped rest), so every one is pushed.
    func updateStrength(for manager: StrengthSessionManager, at date: Date = Date()) {
        guard let activity, let state = strengthState(for: manager, at: date) else { return }
        lastUpdate = date
        let id = activity.id
        Task { await Self.update(activityID: id, to: ActivityContent(state: state, staleDate: nil)) }
    }

    /// Shows the session's final numbers on the Lock Screen for a while, then lets it go. The sets
    /// are already saved, so unlike a run there's nothing waiting in the app.
    func finishStrength(for manager: StrengthSessionManager, at date: Date = Date()) {
        guard let activity, let state = strengthState(for: manager, at: date) else { return }
        self.activity = nil
        lastUpdate = nil
        let id = activity.id
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await Self.end(activityID: id, finalContent: content, dismissAt: date.addingTimeInterval(15 * 60)) }
    }

    private func request(_ attributes: WorkoutActivityAttributes, state: WorkoutActivityAttributes.ContentState, at date: Date) {
        endAll()
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            lastUpdate = date
        } catch {
            activity = nil   // e.g. too many Live Activities running; the session continues regardless
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

    private nonisolated static func end(
        activityID: String,
        finalContent: ActivityContent<WorkoutActivityAttributes.ContentState>,
        dismissAt: Date
    ) async {
        for running in Activity<WorkoutActivityAttributes>.activities where running.id == activityID {
            await running.end(finalContent, dismissalPolicy: .after(dismissAt))
        }
    }

    private nonisolated static func end(activityIDs: [String]) async {
        for running in Activity<WorkoutActivityAttributes>.activities where activityIDs.contains(running.id) {
            await running.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Clears orphaned Live Activities at launch when no live session is running.
    func endOrphanedActivities(tracker: WorkoutTracker, strength: StrengthSessionManager) {
        guard tracker.phase == .idle, strength.phase == .idle,
              !Activity<WorkoutActivityAttributes>.activities.isEmpty else { return }
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

    private func strengthState(for manager: StrengthSessionManager, at date: Date) -> WorkoutActivityAttributes.ContentState? {
        guard let session = manager.session else { return nil }
        return WorkoutLiveActivityContent.strengthState(
            session: session,
            isFinished: manager.phase == .finished,
            elapsedSeconds: manager.elapsedSeconds(at: date),
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
        let strength = StrengthSessionManager.shared
        switch command {
        case .pause:  tracker.pause()
        case .resume: tracker.resume()
        case .logSet: strength.repeatLastSet()
        case .end:
            if strength.isActive {
                strength.end()
            } else {
                // Finishing doesn't save: the summary opens the next time the app comes to the
                // foreground, so nothing is logged without the person reviewing it.
                tracker.finish()
            }
        }
    }
}
