//
//  HardeningTests.swift
//  FunFitnessTests
//
//  v2.4: celebration cap, reconcile flags in AppViewModel, cached totals, display grouping.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

@Suite("Celebration")
@MainActor
struct CelebrationTests {

    private func milestones(_ ids: String...) -> [Milestone] {
        ids.compactMap(ComparisonEngine.milestone(withId:))
    }

    // One big entry crossing several distance milestones shows only the highest.
    @Test func showsOnlyTheHighestMilestonePerType() {
        let vm = AppViewModel()
        vm.celebrate(milestones("D1", "D1b", "D2", "D2b"))
        #expect(vm.pendingMilestones.map(\.id) == ["D2b"])
        #expect(vm.showMilestoneModal)
    }

    @Test func showsOneMilestoneForEachType() {
        let vm = AppViewModel()
        vm.celebrate(milestones("D1", "D2", "W1", "W1b"))
        #expect(vm.pendingMilestones.map(\.id) == ["D2", "W1b"])
    }

    @Test func emptyInputShowsNothing() {
        let vm = AppViewModel()
        vm.celebrate([])
        #expect(vm.pendingMilestones.isEmpty)
        #expect(!vm.showMilestoneModal)
    }

    // A second event while the screen is up queues behind it instead of replacing it.
    @Test func addsToACelebrationAlreadyShowing() {
        let vm = AppViewModel()
        vm.celebrate(milestones("D1"))
        vm.celebrate(milestones("W1"))
        vm.celebrate(milestones("W1"))   // already queued, not repeated
        #expect(vm.pendingMilestones.map(\.id) == ["D1", "W1"])
    }
}

@Suite("AppViewModel reconcile flags")
@MainActor
struct ReconcileFlagTests {

    // Held for the whole test: a context doesn't keep its container alive, and releasing the
    // container while the context is in use crashes the test process. Swift Testing makes a
    // fresh suite instance per test, so each test gets its own empty store.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        let config = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: PersistenceController.schema, configurations: [config])
    }

    // Without the delete flag (e.g. a change from iCloud), a badge above the total survives.
    @Test func doesNotRevokeWithoutTheDeleteFlag() {
        let badge = UnlockedAchievement(milestoneId: "D1")
        context.insert(badge)
        let vm = AppViewModel()

        vm.reconcileAchievements(records: [badge], context: context)
        #expect(vm.unlockedAchievementIds == ["D1"])
    }

    // The delete flag allows one revoking pass and is then cleared.
    @Test func deleteFlagRevokesOnceThenResets() {
        let badge = UnlockedAchievement(milestoneId: "D1")
        context.insert(badge)
        let vm = AppViewModel()
        vm.revokeAchievementsOnNextReconcile = true

        vm.reconcileAchievements(records: [badge], context: context)
        #expect(vm.unlockedAchievementIds.isEmpty)
        #expect(!vm.revokeAchievementsOnNextReconcile)
    }

    // After a HealthKit import, newly unlocked badges are celebrated (highest only).
    @Test func importFlagCelebratesNewBadges() {
        let vm = AppViewModel()
        vm.activities = [ActivityLog(type: .distance, value: 20)]   // past D1, D1b, D2, D2b
        vm.celebrateNewlyEarnedOnNextReconcile = true

        let inserted = vm.reconcileAchievements(records: [], context: context)
        #expect(inserted == ["D1", "D1b", "D2", "D2b"])
        #expect(vm.pendingMilestones.map(\.id) == ["D2b"])
        #expect(!vm.celebrateNewlyEarnedOnNextReconcile)
    }

    // Without the import flag, backfilled badges stay silent (sync, fresh install).
    @Test func backfillIsSilentWithoutTheImportFlag() {
        let vm = AppViewModel()
        vm.activities = [ActivityLog(type: .distance, value: 20)]

        vm.reconcileAchievements(records: [], context: context)
        #expect(vm.unlockedAchievementIds.contains("D2b"))
        #expect(vm.pendingMilestones.isEmpty)
    }
}

@Suite("Cached totals")
@MainActor
struct CachedTotalsTests {

    @Test func totalsFollowArrayChanges() {
        let vm = AppViewModel()
        vm.activities = [ActivityLog(type: .distance, value: 5), ActivityLog(type: .weight, value: 10, reps: 3)]
        #expect(vm.total(for: .distance) == 5)
        #expect(vm.total(for: .weight) == 30)

        vm.activities.append(ActivityLog(type: .distance, value: 2))
        #expect(vm.total(for: .distance) == 7)

        vm.activities = []
        #expect(vm.total(for: .distance) == 0)
    }

    // In-place edits don't reassign the array; refreshTotals() picks them up.
    @Test func refreshPicksUpInPlaceEdits() {
        let vm = AppViewModel()
        let run = ActivityLog(type: .distance, value: 5)
        vm.activities = [run]
        run.value = 8
        vm.refreshTotals()
        #expect(vm.total(for: .distance) == 8)
    }
}

@Suite("Display formatting")
struct DisplayFormattingTests {

    @Test func largeTotalsUseGroupingSeparators() {
        let us = Locale(identifier: "en_US")
        guard Locale.current.groupingSeparator == us.groupingSeparator else { return }
        #expect(UnitConverter.weightString(3_000, pref: .imperial) == "6,614 lbs")
        #expect(UnitConverter.repsString(10_000) == "10,000 reps")
    }
}
