//
//  AchievementReconcilerTests.swift
//  FunFitnessTests
//
//  v2.3: reconcile safety (dedupe, opt-in revocation, unknown ids) and threshold precision.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

@Suite("AchievementReconciler")
@MainActor
struct AchievementReconcilerTests {

    private func record(_ id: String, daysAgo: Double = 0) -> UnlockedAchievement {
        UnlockedAchievement(milestoneId: id, unlockedAt: Date(timeIntervalSinceNow: -daysAgo * 86_400))
    }

    @Test func insertsEarnedIdsWithoutRows() {
        let plan = AchievementReconciler.plan(
            earned: ["D1", "D1b"], records: [record("D1")], allowRevocation: false
        )
        #expect(plan.idsToInsert == ["D1b"])
        #expect(plan.recordsToDelete.isEmpty)
    }

    // Two devices can each insert a row for the same milestone; keep the earliest one.
    @Test func dedupesKeepingEarliestRow() {
        let older = record("D1", daysAgo: 5)
        let newer = record("D1", daysAgo: 1)
        let plan = AchievementReconciler.plan(
            earned: ["D1"], records: [newer, older], allowRevocation: false
        )
        #expect(plan.recordsToDelete.count == 1)
        #expect(plan.recordsToDelete.first === newer)
        #expect(plan.revokedIds.isEmpty)
        #expect(plan.idsToInsert.isEmpty)
    }

    // Partly synced devices see low totals; without a local delete nothing is revoked.
    @Test func doesNotRevokeUnlessAllowed() {
        let plan = AchievementReconciler.plan(
            earned: [], records: [record("D1")], allowRevocation: false
        )
        #expect(plan.recordsToDelete.isEmpty)
        #expect(plan.revokedIds.isEmpty)
    }

    @Test func revokesKnownUnearnedIdWhenAllowed() {
        let stale = record("D1")
        let plan = AchievementReconciler.plan(
            earned: [], records: [stale], allowRevocation: true
        )
        #expect(plan.recordsToDelete.first === stale)
        #expect(plan.revokedIds == ["D1"])
    }

    // An id from a newer build on another device must survive this build's reconcile.
    @Test func neverRevokesUnknownIds() {
        let plan = AchievementReconciler.plan(
            earned: [], records: [record("D99")], allowRevocation: true
        )
        #expect(plan.recordsToDelete.isEmpty)
        #expect(plan.revokedIds.isEmpty)
    }

    @Test func reconcileAppliesPlanToContext() throws {
        let config = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PersistenceController.schema, configurations: [config])
        let context = container.mainContext

        context.insert(record("D1", daysAgo: 3))
        context.insert(record("D1", daysAgo: 1))
        context.insert(record("W1"))
        try context.save()

        let records = try context.fetch(FetchDescriptor<UnlockedAchievement>())
        let result = AchievementReconciler.reconcile(
            earned: ["D1", "D1b"], records: records, allowRevocation: true, context: context
        )

        let remaining = try context.fetch(FetchDescriptor<UnlockedAchievement>()).map(\.milestoneId)
        #expect(result.unlocked == ["D1", "D1b"])
        #expect(result.inserted == ["D1b"])
        #expect(remaining.sorted() == ["D1", "D1b"])
    }
}

@Suite("Milestone thresholds")
@MainActor
struct MilestoneThresholdTests {

    // Values before v2.3. Thresholds may only stay the same or go down, never up.
    private let previousThresholds: [String: Double] = [
        "D1": 1.60934, "D1b": 4.02336, "D2": 8.04672, "D2b": 16.0934, "D3": 21.0975,
        "D3b": 28.1635, "D4": 42.195, "D4b": 56.3270, "D5": 80.4672, "D5b": 120.701, "D6": 160.934,
        "W1": 226.796, "W1b": 453.592, "W2": 1133.98, "W2b": 2267.96, "W3": 4535.92,
        "W3b": 6803.89, "W4": 11339.8, "W4b": 15875.7, "W5": 22679.6, "W5b": 34019.4, "W6": 45359.2,
    ]

    @Test func thresholdsNeverRise() {
        for (id, previous) in previousThresholds {
            let current = ComparisonEngine.milestone(withId: id)?.threshold ?? .infinity
            #expect(current <= previous, "\(id) threshold rose")
        }
    }

    // Logging exactly the titled imperial amount must earn the badge (D5b and W3b used to miss).
    @Test(arguments: [
        ("D1b", 2.5), ("D2", 5.0), ("D3b", 17.5), ("D4b", 35.0), ("D5", 50.0), ("D5b", 75.0), ("D6", 100.0),
        ("D7", 250.0), ("D8", 500.0), ("D9", 1_000.0), ("D10", 2_190.0),
    ])
    func exactMilesReachDistanceMilestone(id: String, miles: Double) throws {
        let milestone = try #require(ComparisonEngine.milestone(withId: id))
        #expect(milestone.isReached(by: UnitConverter.toSI(miles, type: .distance, from: .imperial)))
    }

    @Test(arguments: [
        ("W1", 500.0), ("W3b", 15_000.0), ("W4b", 35_000.0), ("W5b", 75_000.0), ("W6", 100_000.0),
    ])
    func exactPoundsReachWeightMilestone(id: String, pounds: Double) throws {
        let milestone = try #require(ComparisonEngine.milestone(withId: id))
        #expect(milestone.isReached(by: UnitConverter.toSI(pounds, type: .weight, from: .imperial)))
    }

    // Summing entries can land a hair under the threshold; that still counts.
    @Test func summedEntriesReachThreshold() throws {
        let d5b = try #require(ComparisonEngine.milestone(withId: "D5b"))
        let entry = UnitConverter.toSI(7.5, type: .distance, from: .imperial)
        let total = (0..<10).reduce(0.0) { sum, _ in sum + entry }
        #expect(d5b.isReached(by: total))

        let crossed = ComparisonEngine.checkForNewMilestones(
            type: .distance, previousTotal: total - entry, newTotal: total, unlockedIds: []
        )
        #expect(crossed.map(\.id).contains("D5b"))
    }

    // v2.3 Journey anchors are new badges but deliberately don't move the silly-title rank.
    @Test func journeyTiersDoNotAffectRank() {
        let journey: Set<String> = ["D7", "D8", "D9", "D10"]
        #expect(journey.isSubset(of: Set(ComparisonEngine.byId.keys)))
        #expect(journey.isDisjoint(with: SillyTitleEngine.rankedMilestoneIds))
    }

    @Test func appalachianTrailKeepsItsName() throws {
        let d10 = try #require(ComparisonEngine.milestone(withId: "D10"))
        #expect(d10.title(pref: .metric) == "Appalachian Trail Complete!")
    }

    @Test func justBelowThresholdIsNotReached() throws {
        let d5b = try #require(ComparisonEngine.milestone(withId: "D5b"))
        #expect(!d5b.isReached(by: d5b.threshold - 0.001))
    }
}
