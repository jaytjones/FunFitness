//
//  EffortEngine.swift
//  FunFitness
//
//  Effort Points (3.1, feedback C7): one weekly score across every activity type that isn't
//  calories. Effort Points = minutes of activity × intensity. Design and the reasoning behind
//  the numbers: docs/20261017_workout_score_design.md. Jay's decisions (2026-11-06): a weekly
//  target of 150 points (echoing the WHO 150-minute guideline), shown on a Home card.
//
//  Pure and date-explicit like the other engines. Nothing new is stored: everything comes from
//  the logs, tracked routes, and strength sessions the app already keeps.
//

import Foundation

nonisolated enum EffortEngine {

    /// Weekly goal (Jay, 2026-11-06).
    static let weeklyTarget: Double = 150

    // MARK: - Intensity (points per minute)

    /// MET ÷ 2, using Compendium of Physical Activities values.
    static let walkPerMinute = 3.5 / 2       // walking, ~5 km/h
    static let runPerMinute = 9.8 / 2        // running, ~10 km/h
    static let strengthPerMinute = 3.5 / 2   // resistance training, moderate (matches CalorieEstimator)
    /// Duration logs can be anything (yoga, cycling, HIIT), so they count as moderate effort.
    static let durationPerMinute = 4.0 / 2

    // MARK: - Estimates for entries with no time

    /// A distance entry without a recorded time is assumed to be a walk at 5 km/h.
    static let estimatedMinutesPerKm = 12.0
    /// A strength set without a timed session is assumed to take 2 minutes, rest included.
    static let estimatedMinutesPerSet = 2.0

    /// Heart-rate zone (1–5) for an average heart rate, as % of max (220 − age):
    /// Z1 under 60%, Z2 60–70%, Z3 70–80%, Z4 80–90%, Z5 90%+. Everything below Z2 counts as Z1,
    /// so any recorded activity earns at least a point a minute.
    static func heartRateZone(averageBPM: Double, age: Int) -> Int {
        let maxHR = Double(220 - age)
        guard maxHR > 0 else { return 1 }
        let percent = averageBPM / maxHR
        switch percent {
        case ..<0.6: return 1
        case ..<0.7: return 2
        case ..<0.8: return 3
        case ..<0.9: return 4
        default:     return 5
        }
    }

    // MARK: - Entries

    /// One thing that earns points. Built from the stored models by `entries(…)`.
    struct Entry: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case walk, run, strength, duration
        }
        let kind: Kind
        let date: Date
        let minutes: Double
        /// The minutes are a guess (no time was recorded).
        let isEstimated: Bool
        let averageHeartRate: Double?
    }

    /// The points one entry earns. Heart rate sets the intensity when there is one and the age is
    /// known; otherwise the activity's MET does.
    static func points(for entry: Entry, age: Int?) -> Double {
        let perMinute: Double
        if let bpm = entry.averageHeartRate, let age, age > 0 {
            perMinute = Double(heartRateZone(averageBPM: bpm, age: age))
        } else {
            switch entry.kind {
            case .walk:     perMinute = walkPerMinute
            case .run:      perMinute = runPerMinute
            case .strength: perMinute = strengthPerMinute
            case .duration: perMinute = durationPerMinute
            }
        }
        return max(0, entry.minutes) * perMinute
    }

    /// What the stored models say about one log, so the engine doesn't depend on SwiftData.
    struct LogFacts: Equatable, Sendable {
        let id: UUID
        let type: ActivityType
        /// Stored value: km, kg, minutes, or a rep count.
        let value: Double
        let date: Date
        let sessionID: UUID?
        let averageHeartRate: Double?
    }

    struct RouteFacts: Equatable, Sendable {
        let activityID: UUID
        let movingSeconds: Double
        let kind: TrackedWorkoutKind
    }

    struct SessionFacts: Equatable, Sendable {
        let id: UUID
        let startedAt: Date
        let durationSeconds: TimeInterval
    }

    /// Turns logs into point-earning entries:
    /// - a tracked walk/run counts its moving time at walk or run intensity;
    /// - any other distance entry is estimated as a walk (`estimatedMinutesPerKm`);
    /// - a Duration log counts its minutes;
    /// - a timed strength session counts its length once; sets outside one count
    ///   `estimatedMinutesPerSet` each.
    static func entries(logs: [LogFacts], routes: [RouteFacts], sessions: [SessionFacts]) -> [Entry] {
        let routesByActivity = Dictionary(routes.map { ($0.activityID, $0) }, uniquingKeysWith: { first, _ in first })
        let timedSessions = Dictionary(
            sessions.filter { SessionTiming.isTimed($0.durationSeconds) }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var result: [Entry] = []
        var countedSessions: Set<UUID> = []

        for log in logs {
            switch log.type {
            case .distance:
                if let route = routesByActivity[log.id], route.movingSeconds > 0 {
                    result.append(Entry(
                        kind: route.kind == .run ? .run : .walk,
                        date: log.date,
                        minutes: route.movingSeconds / 60,
                        isEstimated: false,
                        averageHeartRate: log.averageHeartRate
                    ))
                } else {
                    result.append(Entry(
                        kind: .walk,
                        date: log.date,
                        minutes: max(0, log.value) * estimatedMinutesPerKm,
                        isEstimated: true,
                        averageHeartRate: log.averageHeartRate
                    ))
                }
            case .duration:
                result.append(Entry(
                    kind: .duration, date: log.date, minutes: max(0, log.value),
                    isEstimated: false, averageHeartRate: log.averageHeartRate
                ))
            case .weight, .reps:
                if let sessionID = log.sessionID, let session = timedSessions[sessionID] {
                    // The whole session counts once, on the day it started.
                    guard countedSessions.insert(sessionID).inserted else { continue }
                    result.append(Entry(
                        kind: .strength, date: session.startedAt, minutes: session.durationSeconds / 60,
                        isEstimated: false, averageHeartRate: nil
                    ))
                } else {
                    result.append(Entry(
                        kind: .strength, date: log.date, minutes: estimatedMinutesPerSet,
                        isEstimated: true, averageHeartRate: nil
                    ))
                }
            }
        }
        return result
    }

    // MARK: - Weekly total

    struct WeeklySummary: Equatable, Sendable {
        let points: Double
        let target: Double
        /// Some of the points come from estimated minutes.
        let includesEstimates: Bool

        var fraction: Double { target > 0 ? min(1, points / target) : 0 }
        var isComplete: Bool { points >= target }
        /// Whole points, as shown: "87".
        var pointsText: String { "\(Int(points.rounded()))" }
        var targetText: String { "\(Int(target.rounded()))" }
    }

    /// Points earned in the calendar week containing `now`.
    static func weeklySummary(
        entries: [Entry],
        age: Int?,
        now: Date,
        target: Double = weeklyTarget,
        calendar: Calendar = .current
    ) -> WeeklySummary {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return WeeklySummary(points: 0, target: target, includesEstimates: false)
        }
        let thisWeek = entries.filter { $0.date >= week.start && $0.date < week.end }
        let total = thisWeek.reduce(0) { $0 + points(for: $1, age: age) }
        return WeeklySummary(
            points: total,
            target: target,
            includesEstimates: thisWeek.contains { $0.isEstimated && points(for: $0, age: age) > 0 }
        )
    }
}

// MARK: - Model adapters

extension EffortEngine.LogFacts {
    init(_ log: ActivityLog) {
        self.init(
            id: log.id, type: log.activityType, value: log.value, date: log.loggedAt,
            sessionID: log.sessionID, averageHeartRate: log.avgHeartRate
        )
    }
}

extension EffortEngine.RouteFacts {
    init(_ route: RouteSummary) {
        self.init(activityID: route.activityID, movingSeconds: route.movingSeconds, kind: route.kind)
    }
}

extension EffortEngine.SessionFacts {
    init(_ session: WorkoutSession) {
        self.init(id: session.id, startedAt: session.startedAt, durationSeconds: session.durationSeconds)
    }
}
