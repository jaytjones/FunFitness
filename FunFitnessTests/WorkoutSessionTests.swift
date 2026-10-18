//
//  WorkoutSessionTests.swift
//  FunFitnessTests
//
//  3.1 C1/C2 strength sessions: the auto-grouping rule, History grouping and summaries, multi-set
//  logging, auto-grouping on save, ungroup/remove/delete, and live sessions saving a session.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

private func date(_ minutes: Double) -> Date {
    Date(timeIntervalSince1970: 1_000_000 + minutes * 60)
}

// MARK: - Grouping rule

@Suite("Session grouping rule")
@MainActor
struct SessionGroupingTests {

    private func candidate(
        at minutes: Double, session: UUID? = nil, auto: Bool = false, excluded: Bool = false
    ) -> SessionGrouping.Candidate {
        SessionGrouping.Candidate(
            id: UUID(), date: date(minutes), sessionID: session,
            sessionIsAutoGrouped: auto, excludedFromAutoGrouping: excluded
        )
    }

    @Test func nothingNearbyStaysAlone() {
        #expect(SessionGrouping.decide(newDate: date(0), candidates: []) == .none)
        #expect(SessionGrouping.decide(newDate: date(0), candidates: [candidate(at: -31)]) == .none)
    }

    @Test func aNearbyLooseLogStartsASession() {
        let loose = candidate(at: -20)
        #expect(SessionGrouping.decide(newDate: date(0), candidates: [loose]) == .startSession(with: loose.id))
    }

    @Test func joinsANearbyAutomaticSession() {
        let session = UUID()
        let member = candidate(at: -10, session: session, auto: true)
        #expect(SessionGrouping.decide(newDate: date(0), candidates: [member]) == .join(sessionID: session))
    }

    @Test func leavesSessionsThePersonMadeAlone() {
        let explicit = candidate(at: -5, session: UUID(), auto: false)
        #expect(SessionGrouping.decide(newDate: date(0), candidates: [explicit]) == .none)
    }

    @Test func skipsUngroupedLogs() {
        #expect(SessionGrouping.decide(newDate: date(0), candidates: [candidate(at: -5, excluded: true)]) == .none)
    }

    @Test func picksTheNearestAndWorksForBackdatedEntries() {
        let far = candidate(at: -25)
        let near = candidate(at: 8)   // logged later than the backdated new entry
        #expect(SessionGrouping.decide(newDate: date(0), candidates: [far, near]) == .startSession(with: near.id))
    }

    @Test func onlyStrengthTypesGroup() {
        #expect(SessionGrouping.isGroupable(.weight))
        #expect(SessionGrouping.isGroupable(.reps))
        #expect(!SessionGrouping.isGroupable(.distance))
        #expect(!SessionGrouping.isGroupable(.duration))
    }
}

// MARK: - History grouping and summaries

@Suite("Session history")
@MainActor
struct SessionHistoryTests {

    @Test func groupsSessionSetsIntoOneNewestFirstRow() {
        let session = UUID()
        let run = ActivityLog(type: .distance, value: 5, loggedAt: date(100))
        let set1 = ActivityLog(type: .weight, value: 50, reps: 10, loggedAt: date(10))
        let set2 = ActivityLog(type: .weight, value: 50, reps: 8, loggedAt: date(15))
        let alone = ActivityLog(type: .reps, value: 20, loggedAt: date(0))
        set1.sessionID = session
        set2.sessionID = session

        let items = HistoryItem.items(from: [run, set1, set2, alone])
        #expect(items.map(\.id) == [run.id, session, alone.id])
        if case .session(_, let logs) = items[1] {
            #expect(logs.map(\.id) == [set2.id, set1.id])
        } else {
            Issue.record("expected a session row")
        }
    }

    @Test func summarizesWeightAndBodyweightSets() throws {
        let logs = [
            ActivityLog(type: .weight, value: 50, reps: 10, loggedAt: date(0)),
            ActivityLog(type: .weight, value: 60, reps: 5, loggedAt: date(5)),
            ActivityLog(type: .reps, value: 15, loggedAt: date(9)),
        ]
        let summary = try #require(SessionSummary(logs: logs))
        #expect(summary.setCount == 3)
        #expect(summary.liftedKg == 800)
        #expect(summary.bodyweightReps == 15)
        #expect(summary.startedAt == date(0))
        #expect(summary.endedAt == date(9))
        #expect(summary.setsText == "3 sets")
        #expect(summary.totalText(pref: .metric).contains("+"))
        #expect(SessionSummary(logs: []) == nil)
    }
}

// MARK: - Saving

@Suite("Session saving", .serialized)
@MainActor
struct SessionSavingTests {
    // Kept as a property so the in-memory store outlives each test's context.
    let container: ModelContainer

    init() throws {
        let schema = Schema([UserProfile.self, ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    private var context: ModelContext { container.mainContext }

    private func logs() throws -> [ActivityLog] {
        try context.fetch(FetchDescriptor<ActivityLog>(sortBy: [SortDescriptor(\.loggedAt)]))
    }

    private func sessions() throws -> [WorkoutSession] {
        try context.fetch(FetchDescriptor<WorkoutSession>())
    }

    @Test func multipleSetsSaveAsOneSession() throws {
        let vm = AppViewModel()
        ActivityWriter.logSets(type: .weight, value: 60, reps: 10, sets: 3, date: date(0), context: context, viewModel: vm)

        let saved = try logs()
        let session = try #require(try sessions().first)
        #expect(saved.count == 3)
        #expect(saved.allSatisfy { $0.sessionID == session.id && $0.value == 60 && $0.reps == 10 })
        #expect(Set(saved.map(\.loggedAt)).count == 3)   // distinct, ordered times
        #expect(saved.last?.loggedAt == date(0))
        #expect(!session.isAutoGrouped)
        #expect(vm.totalWeight == 1_800)                  // same total as three separate logs
    }

    @Test func multiSetMilestonesMatchLoggingEachSet() {
        let vm = AppViewModel()
        // 3 × 10 × 100 kg = 3,000 kg crosses the early weight milestones.
        let milestones = ActivityWriter.logSets(type: .weight, value: 100, reps: 10, sets: 3, date: date(0), context: context, viewModel: vm)
        #expect(!milestones.isEmpty)
        #expect(Set(milestones.map(\.id)).count == milestones.count)   // each only once
    }

    @Test func oneSetIsAPlainLog() throws {
        ActivityWriter.logSets(type: .weight, value: 60, reps: 10, sets: 1, date: date(0), context: context, viewModel: AppViewModel())
        #expect(try logs().first?.sessionID == nil)
        #expect(try sessions().isEmpty)
    }

    @Test func nearbyStrengthLogsAutoGroup() throws {
        let vm = AppViewModel()
        ActivityWriter.log(type: .weight, value: 50, reps: 10, date: date(0), context: context, viewModel: vm)
        ActivityWriter.log(type: .reps, value: 20, reps: nil, date: date(10), context: context, viewModel: vm)
        ActivityWriter.log(type: .weight, value: 50, reps: 8, date: date(35), context: context, viewModel: vm)

        let saved = try logs()
        let session = try #require(try sessions().first)
        #expect(try sessions().count == 1)
        #expect(session.isAutoGrouped)
        #expect(saved.allSatisfy { $0.sessionID == session.id })   // 35 is within 30 min of 10
        #expect(session.startedAt == date(0))
        #expect(session.endedAt == date(35))
    }

    @Test func distanceAndFarApartLogsDontGroup() throws {
        let vm = AppViewModel()
        ActivityWriter.log(type: .weight, value: 50, reps: 10, date: date(0), context: context, viewModel: vm)
        ActivityWriter.log(type: .distance, value: 3, reps: nil, date: date(5), context: context, viewModel: vm)
        ActivityWriter.log(type: .weight, value: 50, reps: 10, date: date(45), context: context, viewModel: vm)
        #expect(try logs().allSatisfy { $0.sessionID == nil })
        #expect(try sessions().isEmpty)
    }

    @Test func aManualLogDoesntJoinAMultiSetSession() throws {
        let vm = AppViewModel()
        ActivityWriter.logSets(type: .weight, value: 60, reps: 10, sets: 2, date: date(0), context: context, viewModel: vm)
        ActivityWriter.log(type: .weight, value: 60, reps: 10, date: date(5), context: context, viewModel: vm)
        #expect(try logs().last?.sessionID == nil)
        #expect(try sessions().count == 1)
    }

    @Test func ungroupedSetsStayApart() throws {
        let vm = AppViewModel()
        ActivityWriter.log(type: .weight, value: 50, reps: 10, date: date(0), context: context, viewModel: vm)
        ActivityWriter.log(type: .weight, value: 50, reps: 10, date: date(5), context: context, viewModel: vm)
        let session = try #require(try sessions().first)

        ActivityWriter.ungroupSession(session.id, context: context)
        #expect(try sessions().isEmpty)
        #expect(try logs().allSatisfy { $0.sessionID == nil && $0.excludedFromAutoGrouping })

        // A new nearby log doesn't pull them back in.
        ActivityWriter.log(type: .weight, value: 50, reps: 10, date: date(8), context: context, viewModel: vm)
        #expect(try sessions().isEmpty)
        #expect(vm.totalWeight == 1_500)
    }

    @Test func removingASetDissolvesATwoSetAutoSession() throws {
        let vm = AppViewModel()
        ActivityWriter.log(type: .weight, value: 50, reps: 10, date: date(0), context: context, viewModel: vm)
        ActivityWriter.log(type: .weight, value: 50, reps: 10, date: date(5), context: context, viewModel: vm)
        let second = try #require(try logs().last)

        ActivityWriter.removeFromSession(second, context: context)
        #expect(try sessions().isEmpty)
        #expect(try logs().allSatisfy { $0.sessionID == nil })
        #expect(second.excludedFromAutoGrouping)
    }

    @Test func deletingTheLastSetsLeavesNoEmptySession() throws {
        let vm = AppViewModel()
        ActivityWriter.logSets(type: .weight, value: 60, reps: 10, sets: 2, date: date(0), context: context, viewModel: vm)
        for log in try logs() { ActivityWriter.delete(log, context: context, viewModel: vm) }
        #expect(try sessions().isEmpty)
        #expect(vm.totalWeight == 0)
    }

    @Test func deletingASetKeepsAPersonMadeSessionAndItsSpan() throws {
        let vm = AppViewModel()
        ActivityWriter.logSets(type: .weight, value: 60, reps: 10, sets: 3, date: date(0), context: context, viewModel: vm)
        let first = try #require(try logs().first)
        ActivityWriter.delete(first, context: context, viewModel: vm)

        let session = try #require(try sessions().first)
        let remaining = try logs()
        #expect(remaining.count == 2)
        #expect(session.startedAt == remaining.first?.loggedAt)
    }

    @Test func deleteSessionRemovesEverySet() throws {
        let vm = AppViewModel()
        ActivityWriter.log(type: .distance, value: 3, reps: nil, date: date(0), context: context, viewModel: vm)
        ActivityWriter.logSets(type: .weight, value: 60, reps: 10, sets: 4, date: date(60), context: context, viewModel: vm)
        let session = try #require(try sessions().first)

        ActivityWriter.deleteSession(session.id, context: context, viewModel: vm)
        #expect(try logs().count == 1)                  // the run stays
        #expect(try sessions().isEmpty)
        #expect(vm.totalWeight == 0)
        #expect(vm.totalDistance == 3)
        #expect(vm.revokeAchievementsOnNextReconcile)
    }
}

// MARK: - Live sessions

// Part of the serialized manager suite (StrengthSessionTests.swift), since every test there
// drives the one shared StrengthSessionManager.
extension StrengthSessionManagerTests {

    @Test func liveSetsShareOnePersonMadeSession() throws {
        let context = container.mainContext
        let vm = AppViewModel()   // the manager holds it weakly
        manager.start(restSeconds: 60, context: context, viewModel: vm, at: date(0))
        manager.logSet(type: .weight, valueSI: 60, reps: 10, at: date(2))
        manager.logSet(type: .reps, valueSI: 15, reps: nil, at: date(6))
        manager.end(at: date(10))

        let session = try #require(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        let logs = try context.fetch(FetchDescriptor<ActivityLog>())
        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.sessionID == session.id })
        #expect(!session.isAutoGrouped)
        #expect(session.startedAt == date(0))
        #expect(session.endedAt == date(10))
        manager.reset()
    }

    @Test func aSessionWithNoSetsSavesNothing() throws {
        let context = container.mainContext
        manager.start(restSeconds: 60, context: context, viewModel: AppViewModel(), at: date(0))
        manager.end(at: date(5))
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
        manager.reset()
    }
}
