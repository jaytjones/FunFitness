//
//  StrengthSessionTests.swift
//  FunFitnessTests
//
//  3.1 B1c live strength sessions: the pure session model (sets, rest timer, totals), the
//  manager saving each set as a normal log, and the strength Live Activity content.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: 3_000_000 + seconds)
}

private func weightSet(kg: Double, reps: Int, at seconds: TimeInterval) -> StrengthSet {
    StrengthSet(id: UUID(), type: .weight, valueSI: kg, reps: reps, loggedAt: date(seconds))
}

@Suite("Strength session model")
@MainActor
struct StrengthSessionModelTests {

    @Test func loggingASetStartsTheRestTimer() {
        var session = StrengthSession(startedAt: date(0), restSeconds: 90)
        session.log(weightSet(kg: 60, reps: 10, at: 100))
        #expect(session.isResting(at: date(150)))
        #expect(session.restRemaining(at: date(150)) == 40)
        #expect(!session.isResting(at: date(190)))
        #expect(session.restRemaining(at: date(500)) == 0)
    }

    @Test func skipRestClearsTheTimer() {
        var session = StrengthSession(startedAt: date(0), restSeconds: 90)
        session.log(weightSet(kg: 60, reps: 10, at: 100))
        session.skipRest()
        #expect(!session.isResting(at: date(110)))
        #expect(session.restEndsAt == nil)
    }

    @Test func zeroRestMeansNoTimer() {
        var session = StrengthSession(startedAt: date(0), restSeconds: 0)
        session.log(weightSet(kg: 60, reps: 10, at: 100))
        #expect(session.restEndsAt == nil)
    }

    @Test func totalsSeparateWeightedAndBodyweightSets() {
        var session = StrengthSession(startedAt: date(0))
        session.log(weightSet(kg: 60, reps: 10, at: 10))
        session.log(weightSet(kg: 50, reps: 8, at: 200))
        session.log(StrengthSet(id: UUID(), type: .reps, valueSI: 20, reps: nil, loggedAt: date(400)))
        #expect(session.setCount == 3)
        #expect(session.totalLiftedKg == 600 + 400)
        #expect(session.totalBodyweightReps == 20)
        #expect(session.lastSet?.type == .reps)
        #expect(session.elapsedSeconds(at: date(600)) == 600)
    }
}

@Suite("Strength session manager", .serialized)
@MainActor
struct StrengthSessionManagerTests {
    // Kept as a property so the in-memory store outlives each test's context.
    let container: ModelContainer
    let manager = StrengthSessionManager.shared

    init() throws {
        let schema = Schema([UserProfile.self, ActivityLog.self, UnlockedAchievement.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        manager.reset()   // shared instance: start every test idle
    }

    @Test func eachSetIsSavedAsANormalLog() throws {
        let vm = AppViewModel()
        manager.start(restSeconds: 60, context: container.mainContext, viewModel: vm, at: date(0))
        #expect(manager.logSet(type: .weight, valueSI: 60, reps: 10, at: date(30)))
        #expect(manager.logSet(type: .reps, valueSI: 15, reps: nil, at: date(120)))

        let logs = try container.mainContext.fetch(FetchDescriptor<ActivityLog>(sortBy: [SortDescriptor(\.loggedAt)]))
        #expect(logs.count == 2)
        #expect(logs[0].activityType == .weight && logs[0].value == 60 && logs[0].reps == 10)
        #expect(logs[1].activityType == .reps && logs[1].value == 15 && logs[1].reps == nil)
        #expect(manager.session?.sets.map(\.id) == logs.map(\.id))
        #expect(vm.totalWeight == 600)
        manager.reset()
    }

    @Test func repeatLastSetLogsTheSameSetAgain() throws {
        let vm = AppViewModel()
        manager.start(restSeconds: 60, context: container.mainContext, viewModel: vm, at: date(0))
        #expect(!manager.repeatLastSet(at: date(5)))   // nothing to repeat yet
        manager.logSet(type: .weight, valueSI: 40, reps: 12, at: date(10))
        #expect(manager.repeatLastSet(at: date(100)))

        let logs = try container.mainContext.fetch(FetchDescriptor<ActivityLog>())
        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.value == 40 && $0.reps == 12 })
        manager.reset()
    }

    @Test func noSetsAfterTheSessionEnds() throws {
        let vm = AppViewModel()
        manager.start(restSeconds: 60, context: container.mainContext, viewModel: vm, at: date(0))
        manager.logSet(type: .weight, valueSI: 40, reps: 12, at: date(10))
        manager.end(at: date(300))
        #expect(manager.phase == .finished)
        #expect(!manager.logSet(type: .weight, valueSI: 40, reps: 12, at: date(310)))
        #expect(manager.elapsedSeconds(at: date(9_999)) == 300)   // clock frozen at the end
        #expect(try container.mainContext.fetch(FetchDescriptor<ActivityLog>()).count == 1)
        manager.reset()
        #expect(manager.phase == .idle)
        #expect(manager.session == nil)
    }

    @Test func milestonesWaitWhileTheSessionScreenIsUp() {
        let vm = AppViewModel()
        vm.showStrengthSession = true
        manager.start(restSeconds: 60, context: container.mainContext, viewModel: vm, at: date(0))
        // 2,000 kg in one set crosses the early weight milestones.
        manager.logSet(type: .weight, valueSI: 200, reps: 10, at: date(10))
        #expect(!vm.deferredMilestones.isEmpty)
        #expect(!vm.showMilestoneModal)

        vm.showStrengthSession = false
        vm.celebrateDeferred()
        #expect(vm.deferredMilestones.isEmpty)
        #expect(vm.showMilestoneModal)
        manager.reset()
    }
}

@Suite("Strength Live Activity content")
@MainActor
struct StrengthLiveActivityContentTests {
    private let now = date(1_000)

    @Test func showsSetsLastSetAndRest() {
        var session = StrengthSession(startedAt: date(0), restSeconds: 90)
        session.log(weightSet(kg: 60, reps: 10, at: 980))
        let state = WorkoutLiveActivityContent.strengthState(
            session: session, isFinished: false, elapsedSeconds: 1_000, now: now,
            pref: .metric, packId: ThemePackCatalog.default.id
        )
        #expect(state.primaryValue == "1")
        #expect(state.primaryLabel == "Set")
        #expect(state.secondaryValue == UnitConverter.weightString(60, reps: 10, pref: .metric))
        #expect(state.restStart == date(980))
        #expect(state.restEnd == date(1_070))
        #expect(state.canLogSet)
        #expect(now.timeIntervalSince(state.timerStart) == 1_000)
    }

    @Test func noRestOrLogSetBeforeTheFirstSet() {
        let session = StrengthSession(startedAt: date(0))
        let state = WorkoutLiveActivityContent.strengthState(
            session: session, isFinished: false, elapsedSeconds: 30, now: now,
            pref: .imperial, packId: ThemePackCatalog.default.id
        )
        #expect(state.primaryValue == "0")
        #expect(state.secondaryValue == "—")
        #expect(state.restEnd == nil)
        #expect(!state.canLogSet)
        #expect(state.comparison == nil)
    }

    @Test func finishedStateSummarizesAndHidesButtons() {
        var session = StrengthSession(startedAt: date(0), restSeconds: 90)
        session.log(weightSet(kg: 60, reps: 10, at: 980))
        let state = WorkoutLiveActivityContent.strengthState(
            session: session, isFinished: true, elapsedSeconds: 1_000, now: now,
            pref: .metric, packId: ThemePackCatalog.default.id
        )
        #expect(state.isFinished)
        #expect(!state.canLogSet)
        #expect(state.restEnd == nil)
        #expect(state.comparison?.hasPrefix("1 set saved") == true)
    }

    @Test func bodyweightOnlySessionsCountReps() {
        var session = StrengthSession(startedAt: date(0), restSeconds: 0)
        session.log(StrengthSet(id: UUID(), type: .reps, valueSI: 25, reps: nil, loggedAt: date(900)))
        let state = WorkoutLiveActivityContent.strengthState(
            session: session, isFinished: false, elapsedSeconds: 1_000, now: now,
            pref: .metric, packId: ThemePackCatalog.default.id
        )
        #expect(state.secondaryValue == UnitConverter.repsString(25))
        #expect(state.comparison == "25 bodyweight reps so far")
    }
}
