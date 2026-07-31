//
//  FunFitnessTests.swift
//  FunFitnessTests
//
//  Created by Jay Jones on 3/29/26.
//

import Testing
@testable import FunFitness

// MARK: - ComparisonEngine Tests

@Suite("ComparisonEngine")
struct ComparisonEngineTests {

    @Test func allMilestonesCountIsExpected() {
        // 11 distance + 11 weight = 22 total (includes intermediate milestones added in 1.1)
        #expect(ComparisonEngine.allMilestones.count == 22)
    }

    @Test func byIdContainsAllMilestones() {
        let allIds = Set(ComparisonEngine.allMilestones.map(\.id))
        #expect(allIds == Set(ComparisonEngine.byId.keys))
    }

    @Test func milestoneWithIdFindsExisting() {
        let first = ComparisonEngine.allMilestones[0]
        #expect(ComparisonEngine.milestone(withId: first.id)?.id == first.id)
    }

    @Test func milestoneWithIdReturnsNilForUnknownId() {
        #expect(ComparisonEngine.milestone(withId: "NONEXISTENT") == nil)
    }

    @Test func distanceMilestonesAscendingByThreshold() {
        let thresholds = ComparisonEngine.distanceMilestones.map(\.threshold)
        #expect(thresholds == thresholds.sorted())
    }

    @Test func weightMilestonesAscendingByThreshold() {
        let thresholds = ComparisonEngine.weightMilestones.map(\.threshold)
        #expect(thresholds == thresholds.sorted())
    }

    @Test func noDuplicateMilestoneIds() {
        let ids = ComparisonEngine.allMilestones.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func allMilestoneTitlesNonEmpty() {
        for m in ComparisonEngine.allMilestones {
            #expect(!m.title.isEmpty, "Milestone \(m.id) has empty title")
        }
    }

    @Test func allMilestoneTickersNonEmpty() {
        for m in ComparisonEngine.allMilestones {
            for theme in Theme.allCases {
                #expect(!m.getTicker(for: theme).isEmpty, "Milestone \(m.id) has empty ticker for theme \(theme)")
            }
        }
    }

    @Test func allMilestoneComparisonTextsNonEmpty() {
        for m in ComparisonEngine.allMilestones {
            for theme in Theme.allCases {
                #expect(!m.getComparison(for: theme).isEmpty, "Milestone \(m.id) has empty comparison for theme \(theme)")
            }
        }
    }

    // Exactly at threshold should be returned as newly crossed
    @Test func checkForNewMilestonesAtExactThreshold() {
        let m = ComparisonEngine.distanceMilestones[0] // D1, threshold 1.0
        let result = ComparisonEngine.checkForNewMilestones(
            type: .distance,
            previousTotal: m.threshold - 0.001,
            newTotal: m.threshold,
            unlockedIds: []
        )
        #expect(result.contains(where: { $0.id == m.id }))
    }

    // Already-crossed threshold must NOT be returned
    @Test func checkForNewMilestonesIgnoresPreviouslyCrossed() {
        let m = ComparisonEngine.distanceMilestones[0]
        let result = ComparisonEngine.checkForNewMilestones(
            type: .distance,
            previousTotal: m.threshold,
            newTotal: m.threshold + 1,
            unlockedIds: []
        )
        #expect(!result.contains(where: { $0.id == m.id }))
    }

    // Already-unlocked milestone must NOT be returned even if threshold crossed
    @Test func checkForNewMilestonesRespectsUnlockedSet() {
        let m = ComparisonEngine.distanceMilestones[0]
        let result = ComparisonEngine.checkForNewMilestones(
            type: .distance,
            previousTotal: 0,
            newTotal: m.threshold,
            unlockedIds: Set([m.id])
        )
        #expect(!result.contains(where: { $0.id == m.id }))
    }

    // Only milestones of the correct type are returned
    @Test func checkForNewMilestonesFiltersToCorrectType() {
        let result = ComparisonEngine.checkForNewMilestones(
            type: .distance,
            previousTotal: 0,
            newTotal: 1_000_000,
            unlockedIds: []
        )
        for m in result {
            #expect(m.unit == .miles)
        }
    }

    // Intermediate milestones (1.1) appear in sorted order between originals
    @Test func intermediateMilestonesArePresentAndSorted() {
        let thresholds = ComparisonEngine.distanceMilestones.map(\.threshold)
        #expect(thresholds.contains(2.5))
        #expect(thresholds.contains(10.0))
        #expect(thresholds.contains(17.5))
        #expect(thresholds.contains(35.0))
        #expect(thresholds.contains(75.0))
        #expect(thresholds == thresholds.sorted())
    }
}

// MARK: - AppViewModel Tests

@Suite("AppViewModel")
@MainActor
struct AppViewModelTests {

    @Test func totalDistanceFiltersDistanceOnly() {
        let vm = AppViewModel()
        vm.activities = [
            ActivityLog(type: .distance, value: 3.5),
            ActivityLog(type: .distance, value: 1.5),
            ActivityLog(type: .weight, value: 100),
        ]
        #expect(abs(vm.totalDistance - 5.0) < 0.001)
    }

    @Test func totalWeightFiltersWeightOnly() {
        let vm = AppViewModel()
        vm.activities = [
            ActivityLog(type: .weight, value: 200),
            ActivityLog(type: .weight, value: 150),
            ActivityLog(type: .distance, value: 3.0),
        ]
        #expect(abs(vm.totalWeight - 350.0) < 0.001)
    }

    @Test func totalActivitiesCountsAll() {
        let vm = AppViewModel()
        vm.activities = [
            ActivityLog(type: .distance, value: 1.0),
            ActivityLog(type: .weight, value: 50.0),
            ActivityLog(type: .distance, value: 2.0),
        ]
        #expect(vm.totalActivities == 3)
    }

    @Test func emptyActivitiesProduceZeroTotals() {
        let vm = AppViewModel()
        vm.activities = []
        #expect(vm.totalDistance == 0)
        #expect(vm.totalWeight == 0)
        #expect(vm.totalActivities == 0)
    }

    @Test func earnedMilestoneIdsIncludesMilestonesAtThreshold() {
        let vm = AppViewModel()
        let first = ComparisonEngine.distanceMilestones[0]
        vm.activities = [ActivityLog(type: .distance, value: first.threshold)]
        #expect(vm.earnedMilestoneIds().contains(first.id))
    }

    @Test func earnedMilestoneIdsExcludesMilestonesAboveTotal() {
        let vm = AppViewModel()
        let first = ComparisonEngine.distanceMilestones[0]
        let second = ComparisonEngine.distanceMilestones[1]
        vm.activities = [ActivityLog(type: .distance, value: first.threshold)]
        let earned = vm.earnedMilestoneIds()
        #expect(earned.contains(first.id))
        #expect(!earned.contains(second.id))
    }

    @Test func earnedMilestoneIdsIncludesBothTypes() {
        let vm = AppViewModel()
        let d = ComparisonEngine.distanceMilestones[0]
        let w = ComparisonEngine.weightMilestones[0]
        vm.activities = [
            ActivityLog(type: .distance, value: d.threshold),
            ActivityLog(type: .weight, value: w.threshold),
        ]
        let earned = vm.earnedMilestoneIds()
        #expect(earned.contains(d.id))
        #expect(earned.contains(w.id))
    }

    // MARK: Absurdity Ticker

    @Test func absurdityTickerReturnsNilForZeroTotal() {
        let vm = AppViewModel()
        vm.activities = []
        #expect(vm.absurdityTickerText(for: .distance) == nil)
        #expect(vm.absurdityTickerText(for: .weight) == nil)
    }

    @Test func absurdityTickerReturnsTextForPositiveTotal() {
        let vm = AppViewModel()
        vm.activities = [ActivityLog(type: .distance, value: 0.5)]
        let text = vm.absurdityTickerText(for: .distance)
        #expect(text != nil)
        #expect(text?.contains("You're") == true)
        #expect(text?.contains("%") == true)
    }

    @Test func absurdityTickerPercentageIsBounded() {
        let vm = AppViewModel()
        // 0.5 miles toward D1 (1.0 threshold) = 50%
        vm.activities = [ActivityLog(type: .distance, value: 0.5)]
        let text = vm.absurdityTickerText(for: .distance)
        #expect(text?.contains("50%") == true)
    }

    @Test func absurdityTickerReturnsNilWhenAllMilestonesCleared() {
        let vm = AppViewModel()
        // Well past the last milestone
        vm.activities = [ActivityLog(type: .distance, value: 999_999)]
        #expect(vm.absurdityTickerText(for: .distance) == nil)
    }
}
