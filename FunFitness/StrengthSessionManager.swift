//
//  StrengthSessionManager.swift
//  FunFitness
//
//  Runs a live strength session (3.1 B1c): session clock, "log set", rest countdown. Every set is
//  saved immediately as a normal weight or bodyweight-reps ActivityLog through ActivityWriter, so
//  milestones, streaks, challenges and the widget work exactly as for a manual log, and nothing is
//  lost if the session is abandoned. A single shared instance so the session screen, Home, and
//  the Live Activity's "Log set" button all act on the same session. The sets are grouped under
//  a stored WorkoutSession (C1), created with the first set so an empty session leaves nothing.
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
    @ObservationIgnored private var record: WorkoutSession?

    private var liveActivity: WorkoutLiveActivityController { .shared }

    private init() {}

    var isActive: Bool { phase == .active }

    // MARK: - Controls

    func start(restSeconds: TimeInterval, context: ModelContext, viewModel: AppViewModel, at date: Date = Date()) {
        guard phase == .idle else { return }
        self.context = context
        self.viewModel = viewModel
        session = StrengthSession(startedAt: date, restSeconds: restSeconds)
        record = nil
        endedAt = nil
        phase = .active
        liveActivity.startStrength(for: self, at: date)
    }

    /// Saves a set and starts the rest timer. `valueSI` is kg per rep for `.weight` (with `reps`),
    /// or the rep count for bodyweight `.reps`. Returns false if there's no active session.
    @discardableResult
    func logSet(type: ActivityType, valueSI: Double, reps: Int?, at date: Date = Date()) -> Bool {
        guard phase == .active, var current = session, let context, let viewModel, valueSI > 0 else { return false }
        let record = self.record ?? {
            let new = WorkoutSession(startedAt: current.startedAt, endedAt: date)
            context.insert(new)
            self.record = new
            return new
        }()
        record.endedAt = date
        // Weight and bodyweight reps have no Health equivalent, so there's no write-back.
        let saved = ActivityWriter.logSyncingViewModel(
            type: type, value: valueSI, reps: reps, date: date, source: .manual, sessionID: record.id,
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

    /// Deletes a set from the session screen. Goes through the same delete as History, so totals,
    /// badges and the stored session follow, and `syncWithStore` updates the live list.
    @discardableResult
    func deleteSet(id: UUID) -> Bool {
        guard phase != .idle, let context, let viewModel,
              let log = (try? context.fetch(FetchDescriptor<ActivityLog>(predicate: #Predicate { $0.id == id })))?.first
        else { return false }
        ActivityWriter.delete(log, context: context, viewModel: viewModel)
        return true
    }

    /// Rebuilds the live set list from the logs saved in this session. ActivityWriter calls it
    /// after every delete, edit, ungroup or remove-from-session, so a set deleted in History
    /// also disappears here (TestFlight FB-0001). If the stored session was removed (its last set
    /// was deleted, or it was ungrouped), the next set starts a new one.
    func syncWithStore(at date: Date = Date()) {
        guard phase != .idle, var current = session, let context, let record else { return }
        let recordID = record.id
        let recordExists = ((try? context.fetchCount(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == recordID }
        ))) ?? 0) > 0
        let sessionID: UUID? = recordID
        let logs = recordExists ? ((try? context.fetch(FetchDescriptor<ActivityLog>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.loggedAt)]
        ))) ?? []) : []
        if !recordExists { self.record = nil }

        let sets = logs.map {
            StrengthSet(id: $0.id, type: $0.activityType, valueSI: $0.value, reps: $0.reps, loggedAt: $0.loggedAt)
        }
        guard sets != current.sets else { return }
        current.replaceSets(sets)
        session = current
        if sets.isEmpty { NotificationManager.shared.cancel(.strengthRest) }
        if phase == .active { liveActivity.updateStrength(for: self, at: date) }
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
        if let record, let context {
            record.endedAt = date
            try? context.save()
            // With "Save logs to Apple Health" on, a timed session goes to Health as a strength
            // workout with estimated calories. Weight: the profile's, else Health's latest
            // (without prompting here — the session screen is in front). (3.1 C5)
            let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
            if profile?.healthKitWriteBackEnabled == true, record.isTimed {
                let profileWeight = profile?.weightKg
                Task { @MainActor in
                    var weight = profileWeight
                    if weight == nil { weight = await HealthKitManager.shared.latestBodyMassKg(requestingAccess: false) }
                    await ActivityWriter.saveSessionToHealth(record, weightKg: weight, context: context)
                }
            }
        }
        NotificationManager.shared.cancel(.strengthRest)
        liveActivity.finishStrength(for: self, at: date)
    }

    /// Back to idle once the summary is closed.
    func reset() {
        if phase == .active { NotificationManager.shared.cancel(.strengthRest) }
        liveActivity.endAll()
        session = nil
        record = nil
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
