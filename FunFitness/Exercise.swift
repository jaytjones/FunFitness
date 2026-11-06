//
//  Exercise.swift
//  FunFitness
//
//  Named exercises (3.1, feedback C3) and the muscle groups they work (C6). The built-in list
//  ships as bundled JSON (`Exercises.json`) — the first content to move out of Swift literals;
//  the theme-pack comparison copy follows around 3.3. People can add their own exercises
//  (`CustomExercise`), which sync through iCloud like everything else.
//
//  Jay's decisions (2026-11-06): every new Weight/Reps set names an exercise (repeats inherit
//  it; older entries stay generic); "Muscles worked this week" chips and per-exercise records
//  on Progress. A body heat map is a future enhancement.
//
//  A log points at its exercise by `ActivityLog.exerciseID`: a bundled id ("bench-press") or
//  "custom-<uuid>". Ids are persisted, so never rename them in the JSON.
//

import Foundation
import Observation
import SwiftData

/// Raw values are persisted (custom exercises, JSON), so never rename them.
nonisolated enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest, back, shoulders, biceps, triceps, forearms, core, glutes, quads, hamstrings, calves

    var displayName: String {
        switch self {
        case .chest:      return "Chest"
        case .back:       return "Back"
        case .shoulders:  return "Shoulders"
        case .biceps:     return "Biceps"
        case .triceps:    return "Triceps"
        case .forearms:   return "Forearms"
        case .core:       return "Core"
        case .glutes:     return "Glutes"
        case .quads:      return "Quads"
        case .hamstrings: return "Hamstrings"
        case .calves:     return "Calves"
        }
    }
}

nonisolated struct Exercise: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    /// `.weight` (weight × reps) or `.reps` (bodyweight).
    let type: ActivityType
    let muscles: [MuscleGroup]
    let isCustom: Bool

    static let customPrefix = "custom-"

    static func customID(_ uuid: UUID) -> String { customPrefix + uuid.uuidString }
}

// MARK: - Bundled catalog

nonisolated enum ExerciseCatalog {

    /// The JSON shape of one bundled exercise.
    struct Entry: Codable, Equatable {
        let id: String
        let name: String
        let type: String
        let muscles: [MuscleGroup]
    }

    /// Decodes catalog JSON, dropping entries with a type that isn't Weight or Reps.
    static func decode(_ data: Data) throws -> [Exercise] {
        try JSONDecoder().decode([Entry].self, from: data).compactMap { entry in
            guard let type = ActivityType(rawValue: entry.type), SessionGrouping.isGroupable(type) else { return nil }
            return Exercise(id: entry.id, name: entry.name, type: type, muscles: entry.muscles, isCustom: false)
        }
    }

    /// The bundled exercises, loaded once. Empty only if the resource is missing, which the
    /// catalog test guards against.
    static let bundled: [Exercise] = {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let exercises = try? decode(data) else { return [] }
        return exercises
    }()
}

// MARK: - Custom exercises

@Model
final class CustomExercise {
    // CloudKit-legal: every attribute has a default, no relationships, no unique constraints.
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = ActivityType.weight.rawValue
    /// Comma-separated `MuscleGroup` raw values.
    var musclesRaw: String = ""
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, type: ActivityType, muscles: [MuscleGroup], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.musclesRaw = muscles.map(\.rawValue).joined(separator: ",")
        self.createdAt = createdAt
    }

    var exercise: Exercise {
        Exercise(
            id: Exercise.customID(id),
            name: name,
            type: ActivityType(rawValue: typeRaw) ?? .weight,
            muscles: musclesRaw.split(separator: ",").compactMap { MuscleGroup(rawValue: String($0)) },
            isCustom: true
        )
    }
}

// MARK: - Library (bundled + custom)

/// Every exercise the app knows: the bundled catalog plus the person's own. ContentView keeps
/// `custom` in step with the store, so rows and pickers can look names up without a query each.
@MainActor
@Observable
final class ExerciseLibrary {
    static let shared = ExerciseLibrary()

    private(set) var custom: [Exercise] = []
    @ObservationIgnored private var byID: [String: Exercise] = [:]
    @ObservationIgnored private let bundled: [Exercise]

    init(bundled: [Exercise] = ExerciseCatalog.bundled) {
        self.bundled = bundled
        rebuildIndex()
    }

    func setCustom(_ exercises: [CustomExercise]) {
        let mapped = exercises.sorted { $0.createdAt < $1.createdAt }.map(\.exercise)
        guard mapped != custom else { return }
        custom = mapped
        rebuildIndex()
    }

    func exercise(id: String?) -> Exercise? {
        id.flatMap { byID[$0] }
    }

    /// Bundled and custom exercises for `type`, sorted by name.
    func exercises(for type: ActivityType) -> [Exercise] {
        (bundled + custom)
            .filter { $0.type == type }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func rebuildIndex() {
        byID = Dictionary((bundled + custom).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

// MARK: - Stats (pure, 3.1 C6)

nonisolated enum ExerciseStats {

    /// What the stats need from one log.
    struct SetFacts: Equatable, Sendable {
        let exerciseID: String?
        let type: ActivityType
        /// kg per rep for weight sets; the rep count for bodyweight sets.
        let value: Double
        let reps: Int?
        let date: Date
    }

    struct MuscleCount: Equatable, Identifiable, Sendable {
        let muscle: MuscleGroup
        let sets: Int
        var id: MuscleGroup { muscle }
    }

    /// Sets per muscle group in the calendar week containing `now`, most-worked first (ties in
    /// `MuscleGroup` order). A set counts once for every muscle its exercise works. Sets without
    /// an exercise, or with an unknown one, don't count.
    static func musclesWorked(
        sets: [SetFacts],
        lookup: (String) -> Exercise?,
        now: Date,
        calendar: Calendar = .current
    ) -> [MuscleCount] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        var counts: [MuscleGroup: Int] = [:]
        for set in sets where set.date >= week.start && set.date < week.end {
            guard let id = set.exerciseID, let exercise = lookup(id) else { continue }
            for muscle in Set(exercise.muscles) { counts[muscle, default: 0] += 1 }
        }
        let order = MuscleGroup.allCases
        return counts
            .map { MuscleCount(muscle: $0.key, sets: $0.value) }
            .sorted { lhs, rhs in
                lhs.sets != rhs.sets
                    ? lhs.sets > rhs.sets
                    : (order.firstIndex(of: lhs.muscle) ?? 0) < (order.firstIndex(of: rhs.muscle) ?? 0)
            }
    }

    /// A personal best for one exercise: the heaviest weight (with the most reps at it) for a
    /// lift, or the most reps in one set for a bodyweight move.
    struct Record: Equatable, Identifiable, Sendable {
        let exerciseID: String
        let type: ActivityType
        let value: Double
        let reps: Int?
        let date: Date
        var id: String { exerciseID }
    }

    /// One record per exercise, most recently set first.
    static func personalRecords(sets: [SetFacts]) -> [Record] {
        var best: [String: Record] = [:]
        for set in sets {
            guard let id = set.exerciseID, SessionGrouping.isGroupable(set.type) else { continue }
            let candidate = Record(exerciseID: id, type: set.type, value: set.value, reps: set.reps, date: set.date)
            guard let current = best[id] else { best[id] = candidate; continue }
            if beats(candidate, current) { best[id] = candidate }
        }
        return best.values.sorted { $0.date > $1.date }
    }

    /// Heavier wins; at the same weight, more reps; at a tie, the earlier set keeps the record.
    private static func beats(_ candidate: Record, _ current: Record) -> Bool {
        if candidate.value != current.value { return candidate.value > current.value }
        let candidateReps = candidate.reps ?? 1, currentReps = current.reps ?? 1
        if candidateReps != currentReps { return candidateReps > currentReps }
        return candidate.date < current.date
    }
}

extension ExerciseStats.SetFacts {
    init(_ log: ActivityLog) {
        self.init(exerciseID: log.exerciseID, type: log.activityType, value: log.value, reps: log.reps, date: log.loggedAt)
    }
}
