//
//  WorkoutSession.swift
//  FunFitness
//
//  Strength sessions (3.1, feedback C1/C2): sets from one workout grouped together, like discrete
//  workouts in Apple Fitness. Each set stays a normal ActivityLog, so totals, milestones, streaks
//  and challenges are unchanged; a set points at its session by `ActivityLog.sessionID` (a plain
//  UUID, matching the RouteSummary pattern — no relationship, so CloudKit stays happy).
//
//  Sessions come from three places:
//  - a live strength session (Home › Start a Strength Session),
//  - a multi-set entry in the log sheet ("3 × 10 @ 135 lbs"),
//  - automatic grouping of strength logs entered close together (`SessionGrouping`).
//  The person can ungroup a session or take one set out; those sets are then never auto-grouped
//  again (`ActivityLog.excludedFromAutoGrouping`).
//

import Foundation
import SwiftData

/// What a session holds. Raw values are persisted, so never rename them.
enum WorkoutSessionKind: String, Codable {
    case strength

    var displayName: String { "Strength" }
    var emoji: String { "🏋️" }
}

@Model
final class WorkoutSession {
    // CloudKit-legal: every attribute has a default, no relationships, no unique constraints.
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date = Date()
    var kindRaw: String = WorkoutSessionKind.strength.rawValue
    /// Created by `SessionGrouping` rather than by the person. Only these sessions take in more
    /// logs automatically, and one shrunk to a single set dissolves.
    var isAutoGrouped: Bool = false
    var notes: String?

    init(id: UUID = UUID(), startedAt: Date, endedAt: Date, kind: WorkoutSessionKind = .strength, isAutoGrouped: Bool = false) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.kindRaw = kind.rawValue
        self.isAutoGrouped = isAutoGrouped
    }

    var kind: WorkoutSessionKind {
        WorkoutSessionKind(rawValue: kindRaw) ?? .strength
    }
}

// MARK: - Automatic grouping (pure)

enum SessionGrouping {

    /// Strength logs this close together count as one workout.
    static let autoGroupGap: TimeInterval = 30 * 60

    /// Only strength entries are grouped; walks/runs have their own records.
    static func isGroupable(_ type: ActivityType) -> Bool {
        type == .weight || type == .reps
    }

    /// A nearby strength log the new one might be grouped with.
    struct Candidate: Equatable {
        let id: UUID
        let date: Date
        let sessionID: UUID?
        /// The candidate's session was created automatically (false when it has none).
        let sessionIsAutoGrouped: Bool
        let excludedFromAutoGrouping: Bool
    }

    enum Decision: Equatable {
        /// Stays on its own.
        case none
        /// Joins this existing automatic session.
        case join(sessionID: UUID)
        /// Starts a new automatic session together with this loose log.
        case startSession(with: UUID)
    }

    /// Picks what a newly logged strength entry at `date` should be grouped with. The nearest
    /// eligible log within `autoGroupGap` (before or after — entries can be backdated) wins.
    /// Sessions the person made (live or multi-set) are left alone, as are logs they ungrouped.
    static func decide(newDate date: Date, candidates: [Candidate]) -> Decision {
        let eligible = candidates.filter { candidate in
            !candidate.excludedFromAutoGrouping
                && (candidate.sessionID == nil || candidate.sessionIsAutoGrouped)
                && abs(candidate.date.timeIntervalSince(date)) <= autoGroupGap
        }
        guard let nearest = eligible.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else { return .none }
        if let sessionID = nearest.sessionID { return .join(sessionID: sessionID) }
        return .startSession(with: nearest.id)
    }
}

// MARK: - Summaries (pure over the session's logs)

/// What a session row shows: set count, weight lifted, bodyweight reps, time span.
struct SessionSummary: Equatable {
    let setCount: Int
    let liftedKg: Double
    let bodyweightReps: Int
    let startedAt: Date
    let endedAt: Date

    init?(logs: [ActivityLog]) {
        guard let first = logs.map(\.loggedAt).min(), let last = logs.map(\.loggedAt).max() else { return nil }
        setCount = logs.count
        liftedKg = logs.filter { $0.activityType == .weight }.reduce(0) { $0 + $1.effectiveValue }
        bodyweightReps = logs.filter { $0.activityType == .reps }.reduce(0) { $0 + Int($1.value.rounded()) }
        startedAt = first
        endedAt = last
    }

    /// "5 sets"
    var setsText: String { "\(setCount) set\(setCount == 1 ? "" : "s")" }

    /// "2,400 lbs", "45 reps", or "2,400 lbs + 45 reps".
    func totalText(pref: UnitPreference) -> String {
        var parts: [String] = []
        if liftedKg > 0 { parts.append(UnitConverter.weightString(liftedKg, pref: pref)) }
        if bodyweightReps > 0 { parts.append(UnitConverter.displayString(Double(bodyweightReps), type: .reps, pref: pref)) }
        return parts.isEmpty ? "—" : parts.joined(separator: " + ")
    }
}

/// One History row: a single entry, or a session with its sets (newest first).
enum HistoryItem: Identifiable {
    case single(ActivityLog)
    case session(id: UUID, logs: [ActivityLog])

    var id: UUID {
        switch self {
        case .single(let log):         return log.id
        case .session(let id, _):      return id
        }
    }

    /// When the row sorts: the entry's date, or a session's latest set.
    var date: Date {
        switch self {
        case .single(let log):         return log.loggedAt
        case .session(_, let logs):    return logs.map(\.loggedAt).max() ?? .distantPast
        }
    }

    /// Groups logs by session, newest row first. Logs whose session record hasn't synced yet
    /// still group by their shared id.
    static func items(from logs: [ActivityLog]) -> [HistoryItem] {
        var items: [HistoryItem] = []
        var sessions: [UUID: [ActivityLog]] = [:]
        for log in logs {
            if let sessionID = log.sessionID {
                sessions[sessionID, default: []].append(log)
            } else {
                items.append(.single(log))
            }
        }
        for (id, sessionLogs) in sessions {
            items.append(.session(id: id, logs: sessionLogs.sorted { $0.loggedAt > $1.loggedAt }))
        }
        return items.sorted { $0.date > $1.date }
    }
}
