//
//  ExerciseTests.swift
//  FunFitnessTests
//
//  Named exercises (3.1, C3) and muscle-group stats (C6): the bundled catalog, custom
//  exercises, the library, logging with an exercise, and the Progress stats.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

@Suite("Exercises")
@MainActor
struct ExerciseTests {

    private let cal = Calendar.current

    private func fixedNow() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 17; c.hour = 12
        return cal.date(from: c)!
    }

    // MARK: - Catalog

    @Test func bundledCatalogLoadsWithUniqueIDsAndMuscles() {
        let catalog = ExerciseCatalog.bundled
        #expect(catalog.count >= 40)
        #expect(Set(catalog.map(\.id)).count == catalog.count)
        #expect(catalog.allSatisfy { !$0.muscles.isEmpty && !$0.name.isEmpty })
        #expect(catalog.contains { $0.type == .weight })
        #expect(catalog.contains { $0.type == .reps })
        #expect(!catalog.contains { $0.id.hasPrefix(Exercise.customPrefix) })
    }

    /// Ids are persisted on logs, so these must never disappear from the JSON.
    @Test func persistedIDsStayInTheCatalog() {
        let ids = Set(ExerciseCatalog.bundled.map(\.id))
        for id in ["bench-press", "upright-row", "back-squat", "deadlift", "push-up", "pull-up"] {
            #expect(ids.contains(id), "missing \(id)")
        }
    }

    @Test func decodeDropsNonStrengthTypes() throws {
        let json = """
        [{"id":"a","name":"A","type":"weight","muscles":["chest"]},
         {"id":"b","name":"B","type":"distance","muscles":["quads"]}]
        """
        let exercises = try ExerciseCatalog.decode(Data(json.utf8))
        #expect(exercises.map(\.id) == ["a"])
    }

    // MARK: - Custom + library

    @Test func customExerciseRoundTripsMuscles() {
        let custom = CustomExercise(name: "Zercher Squat", type: .weight, muscles: [.quads, .core])
        let exercise = custom.exercise
        #expect(exercise.id == Exercise.customID(custom.id))
        #expect(exercise.isCustom)
        #expect(exercise.muscles == [.quads, .core])
        #expect(exercise.type == .weight)
    }

    @Test func libraryMergesCustomAndFiltersByType() {
        let library = ExerciseLibrary(bundled: [
            Exercise(id: "bench-press", name: "Bench Press", type: .weight, muscles: [.chest], isCustom: false),
            Exercise(id: "push-up", name: "Push-Up", type: .reps, muscles: [.chest], isCustom: false),
        ])
        let custom = CustomExercise(name: "Arnold Press", type: .weight, muscles: [.shoulders])
        library.setCustom([custom])

        #expect(library.exercises(for: .weight).map(\.name) == ["Arnold Press", "Bench Press"])
        #expect(library.exercises(for: .reps).map(\.name) == ["Push-Up"])
        #expect(library.exercise(id: custom.exercise.id)?.name == "Arnold Press")
        #expect(library.exercise(id: nil) == nil)
        #expect(library.exercise(id: "unknown") == nil)
    }

    // MARK: - Logging

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self, CustomExercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func loggedSetsKeepTheirExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let viewModel = AppViewModel()

        ActivityWriter.logSets(
            type: .weight, value: 60, reps: 10, sets: 3, date: fixedNow(),
            exerciseID: "bench-press", context: context, viewModel: viewModel
        )
        let logs = try context.fetch(FetchDescriptor<ActivityLog>())
        #expect(logs.count == 3)
        #expect(logs.allSatisfy { $0.exerciseID == "bench-press" })
        #expect(viewModel.lastExerciseID(for: .weight) == "bench-press")
        #expect(viewModel.lastExerciseID(for: .reps) == nil)
    }

    @Test func distanceEntriesNeverStoreAnExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let result = ActivityWriter.log(
            type: .distance, value: 5, reps: nil, date: fixedNow(), exerciseID: "bench-press",
            existingActivities: [], unlockedIds: [], context: context
        )
        #expect(result.activity.exerciseID == nil)
    }

    @Test func exerciseChangeMakesLogsUnequal() {
        let id = UUID(), date = fixedNow()
        let a = ActivityLog(id: id, type: .weight, value: 60, reps: 10, loggedAt: date)
        let b = ActivityLog(id: id, type: .weight, value: 60, reps: 10, loggedAt: date)
        #expect(a == b)
        b.exerciseID = "bench-press"
        #expect(a != b)
    }

    // MARK: - Stats

    private func set(_ id: String?, _ value: Double, type: ActivityType = .weight, reps: Int? = nil, at date: Date) -> ExerciseStats.SetFacts {
        ExerciseStats.SetFacts(exerciseID: id, type: type, value: value, reps: reps, date: date)
    }

    @Test func musclesWorkedCountsThisWeekOnly() {
        let now = fixedNow()
        let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: now)!
        let catalog: [String: Exercise] = [
            "bench": Exercise(id: "bench", name: "Bench", type: .weight, muscles: [.chest, .triceps], isCustom: false),
            "row": Exercise(id: "row", name: "Row", type: .weight, muscles: [.back], isCustom: false),
        ]
        let sets = [
            set("bench", 60, reps: 10, at: now),
            set("bench", 60, reps: 10, at: now),
            set("row", 50, reps: 10, at: now),
            set("row", 50, reps: 10, at: lastWeek),   // last week
            set(nil, 40, reps: 10, at: now),          // generic set
            set("gone", 40, reps: 10, at: now),       // unknown exercise
        ]
        let counts = ExerciseStats.musclesWorked(sets: sets, lookup: { catalog[$0] }, now: now)

        #expect(counts.map(\.muscle) == [.chest, .triceps, .back])
        #expect(counts.map(\.sets) == [2, 2, 1])
    }

    @Test func personalRecordsPickHeaviestThenMostReps() {
        let now = fixedNow()
        let earlier = now.addingTimeInterval(-86_400)
        let records = ExerciseStats.personalRecords(sets: [
            set("bench", 80, reps: 5, at: earlier),
            set("bench", 80, reps: 8, at: now),     // same weight, more reps → record
            set("bench", 70, reps: 12, at: now),
            set("push-up", 25, type: .reps, at: earlier),
            set("push-up", 20, type: .reps, at: now),
            set(nil, 200, reps: 1, at: now),         // generic: no record
        ])
        let bench = records.first { $0.exerciseID == "bench" }
        let pushUp = records.first { $0.exerciseID == "push-up" }

        #expect(records.count == 2)
        #expect(bench?.value == 80)
        #expect(bench?.reps == 8)
        #expect(pushUp?.value == 25)
        #expect(records.first?.exerciseID == "bench")   // most recently set first
    }
}
