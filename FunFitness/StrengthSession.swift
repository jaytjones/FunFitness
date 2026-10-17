//
//  StrengthSession.swift
//  FunFitness
//
//  Pure state for a live strength session (3.1 B1c): the sets logged so far, the rest countdown,
//  and totals. `StrengthSessionManager` owns one and saves each set as a normal ActivityLog;
//  this type does no I/O so it's unit-tested directly. Grouping sets into a stored "workout" is
//  the later Workouts epic (C1) — here a session only lives in memory.
//

import Foundation

/// One set logged during a session. `id` matches the saved ActivityLog's id.
struct StrengthSet: Equatable, Identifiable, Sendable {
    let id: UUID
    /// `.weight` (value = kg per rep, with `reps`) or `.reps` (value = a bodyweight rep count).
    let type: ActivityType
    let valueSI: Double
    let reps: Int?
    let loggedAt: Date

    /// Weight lifted in this set (kg × reps); 0 for bodyweight sets.
    var liftedKg: Double {
        type == .weight ? valueSI * Double(reps ?? 1) : 0
    }

    /// Bodyweight reps in this set; 0 for weighted sets.
    var bodyweightReps: Int {
        type == .reps ? Int(valueSI.rounded()) : 0
    }
}

struct StrengthSession: Equatable, Sendable {
    /// Rest lengths offered in the session screen, in seconds.
    static let restOptions: [TimeInterval] = [60, 90, 120, 180]
    static let defaultRest: TimeInterval = 90

    let startedAt: Date
    var restSeconds: TimeInterval
    private(set) var sets: [StrengthSet] = []
    private(set) var restStartedAt: Date?
    private(set) var restEndsAt: Date?

    init(startedAt: Date, restSeconds: TimeInterval = StrengthSession.defaultRest) {
        self.startedAt = startedAt
        self.restSeconds = restSeconds
    }

    var lastSet: StrengthSet? { sets.last }
    var setCount: Int { sets.count }
    var totalLiftedKg: Double { sets.reduce(0) { $0 + $1.liftedKg } }
    var totalBodyweightReps: Int { sets.reduce(0) { $0 + $1.bodyweightReps } }

    func elapsedSeconds(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }

    /// Adds a set and starts the rest countdown from the moment it was logged.
    mutating func log(_ set: StrengthSet) {
        sets.append(set)
        guard restSeconds > 0 else { return skipRest() }
        restStartedAt = set.loggedAt
        restEndsAt = set.loggedAt.addingTimeInterval(restSeconds)
    }

    mutating func skipRest() {
        restStartedAt = nil
        restEndsAt = nil
    }

    func isResting(at date: Date) -> Bool {
        guard let restEndsAt else { return false }
        return restEndsAt > date
    }

    func restRemaining(at date: Date) -> TimeInterval {
        guard let restEndsAt else { return 0 }
        return max(0, restEndsAt.timeIntervalSince(date))
    }
}
