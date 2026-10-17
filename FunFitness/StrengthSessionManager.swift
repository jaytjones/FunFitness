//
//  StrengthSessionManager.swift
//  FunFitness
//
//  Runs a live strength session (3.1 B1c): session clock, "log set", rest countdown. Every set is
//  saved immediately as a normal weight or bodyweight-reps ActivityLog through ActivityWriter, so
//  milestones, streaks, challenges and the widget work exactly as for a manual log, and nothing is
//  lost if the session is abandoned. A single shared instance so the session screen, Home, and
//  the Live Activity's "Log set" button all act on the same session.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StrengthSessionManager {
    static let shared = StrengthSessionManager()

    enum Phase: Equatable {
        case idle
        case active
        /// Ended; the summary shows until the person closes it. Sets are already saved.
        case finished
    }

    private(set) var phase: Phase = .idle
    private(set) var session: StrengthSession?
    private(set) var endedAt: Date?

    // Where sets are saved. Set at `start` from the presenting view's environment.
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private weak var viewModel: AppViewModel?

    private var liveActivity: WorkoutLiveActivityController { .shared }

    private init() {}

    var isActive: Bool { phase == .active }

    // MARK: - Controls

    func start(restSeconds: TimeInterval, context: ModelContext, viewModel: AppViewModel, at date: Date = Date()) {
        guard phase == .idle else { return }
        self.context = context
        self.viewModel = viewModel
        session = StrengthSession(startedAt: date, restSeconds: restSeconds)
        endedAt = nil
        phase = .active
        liveActivity.startStrength(for: self, at: date)
    }

    /// Saves a set and starts the rest timer. `valueSI` is kg per rep for `.weight` (with `reps`),
    /// or the rep count for bodyweight `.reps`. Returns false if there's no active session.
    @discardableResult
    func logSet(type: ActivityType, valueSI: Double, reps: Int?, at date: Date = Date()) -> Bool {
        guard phase == .active, var current = session, let context, let viewModel, valueSI > 0 else { return false }
        // Weight and bodyweight reps have no Health equivalent, so there's no write-back.
        let saved = ActivityWriter.logSyncingViewModel(
            type: type, value: valueSI, reps: reps, date: date, source: .manual,
            context: context, viewModel: viewModel
        )
        current.log(StrengthSet(id: saved.activity.id, type: type, valueSI: valueSI, reps: saved.activity.reps, loggedAt: date))
        session = current
        viewModel.celebrateOrDefer(saved.newMilestones)
        if let restEndsAt = current.restEndsAt {
            NotificationManager.shared.scheduleRestOver(at: restEndsAt)
        }
        liveActivity.updateStrength(for: self, at: date)
        return true
    }

    /// Logs the same set again (the Live Activity's "Log set" button).
    @discardableResult
    func repeatLastSet(at date: Date = Date()) -> Bool {
        guard let last = session?.lastSet else { return false }
        return logSet(type: last.type, valueSI: last.valueSI, reps: last.reps, at: date)
    }

    func skipRest(at date: Date = Date()) {
        guard phase == .active, var current = session else { return }
        current.skipRest()
        session = current
        NotificationManager.shared.cancel(.strengthRest)
        liveActivity.updateStrength(for: self, at: date)
    }

    func setRestSeconds(_ seconds: TimeInterval) {
        session?.restSeconds = seconds
    }

    /// Ends the session. Sets are already saved; this just stops the clock and shows the summary.
    func end(at date: Date = Date()) {
        guard phase == .active else { return }
        endedAt = date
        phase = .finished
        NotificationManager.shared.cancel(.strengthRest)
        liveActivity.finishStrength(for: self, at: date)
    }

    /// Back to idle once the summary is closed.
    func reset() {
        if phase == .active { NotificationManager.shared.cancel(.strengthRest) }
        liveActivity.endAll()
        session = nil
        endedAt = nil
        context = nil
        viewModel = nil
        phase = .idle
    }

    /// Session time: frozen at the end once finished.
    func elapsedSeconds(at date: Date) -> TimeInterval {
        session?.elapsedSeconds(at: endedAt ?? date) ?? 0
    }
}
