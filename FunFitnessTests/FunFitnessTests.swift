//
//  FunFitnessTests.swift
//  FunFitnessTests
//

import Testing
import Foundation
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

    // Distance milestones use km thresholds since v1.2
    @Test func distanceMilestoneThresholdsAreInKm() {
        // D1 = 1 mile ≈ 1.60934 km
        let d1 = ComparisonEngine.milestone(withId: "D1")
        #expect(d1 != nil)
        #expect(abs((d1?.threshold ?? 0) - 1.60934) < 0.001)
        // D3 = half marathon = 21.0975 km exactly
        let d3 = ComparisonEngine.milestone(withId: "D3")
        #expect(abs((d3?.threshold ?? 0) - 21.0975) < 0.001)
        // D4 = full marathon = 42.195 km exactly
        let d4 = ComparisonEngine.milestone(withId: "D4")
        #expect(abs((d4?.threshold ?? 0) - 42.195) < 0.001)
    }

    // Weight milestones use kg thresholds since v1.2
    @Test func weightMilestoneThresholdsAreInKg() {
        // W1 = 500 lbs ≈ 226.796 kg
        let w1 = ComparisonEngine.milestone(withId: "W1")
        #expect(w1 != nil)
        #expect(abs((w1?.threshold ?? 0) - 226.796) < 0.001)
    }

    @Test func distanceMilestoneUnitsAreKilometers() {
        for m in ComparisonEngine.distanceMilestones {
            #expect(m.unit == .kilometers, "Distance milestone \(m.id) should have .kilometers unit")
        }
    }

    @Test func weightMilestoneUnitsAreKilograms() {
        for m in ComparisonEngine.weightMilestones {
            #expect(m.unit == .kilograms, "Weight milestone \(m.id) should have .kilograms unit")
        }
    }

    // Exactly at threshold should be returned as newly crossed
    @Test func checkForNewMilestonesAtExactThreshold() {
        let m = ComparisonEngine.distanceMilestones[0] // D1, threshold ~1.60934 km
        let result = ComparisonEngine.checkForNewMilestones(
            type: .distance,
            previousTotal: m.threshold - 0.001,
            newTotal: m.threshold,
            unlockedIds: []
        )
        #expect(result.contains(where: { $0.id == m.id }))
    }

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

    @Test func checkForNewMilestonesFiltersToCorrectType() {
        let result = ComparisonEngine.checkForNewMilestones(
            type: .distance,
            previousTotal: 0,
            newTotal: 1_000_000,
            unlockedIds: []
        )
        for m in result {
            #expect(m.unit == .kilometers)
        }
    }

    @Test func intermediateMilestonesArePresentAndSorted() {
        // Intermediate distance milestones (in km)
        let thresholds = ComparisonEngine.distanceMilestones.map(\.threshold)
        #expect(thresholds.contains(where: { abs($0 - 4.02336) < 0.001 }))   // D1b = 2.5 mi
        #expect(thresholds.contains(where: { abs($0 - 16.0934) < 0.001 }))   // D2b = 10 mi
        #expect(thresholds.contains(where: { abs($0 - 28.1635) < 0.001 }))   // D3b = 17.5 mi
        #expect(thresholds.contains(where: { abs($0 - 56.327)  < 0.001 }))   // D4b = 35 mi
        #expect(thresholds.contains(where: { abs($0 - 120.701) < 0.001 }))   // D5b = 75 mi
        #expect(thresholds == thresholds.sorted())
    }
}

// MARK: - UnitConverter Tests

@Suite("UnitConverter")
struct UnitConverterTests {

    @Test func imperialToKmConversion() {
        let km = UnitConverter.toKm(1.0, from: .imperial)
        #expect(abs(km - 1.60934) < 0.001)
    }

    @Test func metricToKmPassthrough() {
        let km = UnitConverter.toKm(5.0, from: .metric)
        #expect(abs(km - 5.0) < 0.001)
    }

    @Test func imperialToKgConversion() {
        let kg = UnitConverter.toKg(1.0, from: .imperial)
        #expect(abs(kg - 0.453592) < 0.001)
    }

    @Test func metricToKgPassthrough() {
        let kg = UnitConverter.toKg(10.0, from: .metric)
        #expect(abs(kg - 10.0) < 0.001)
    }

    @Test func kmToImperialConversion() {
        let miles = UnitConverter.fromKm(1.60934, to: .imperial)
        #expect(abs(miles - 1.0) < 0.001)
    }

    @Test func kgToImperialConversion() {
        let lbs = UnitConverter.fromKg(0.453592, to: .imperial)
        #expect(abs(lbs - 1.0) < 0.001)
    }

    @Test func roundTripDistanceImperial() {
        let original = 5.0 // miles
        let km = UnitConverter.toKm(original, from: .imperial)
        let backToMiles = UnitConverter.fromKm(km, to: .imperial)
        #expect(abs(backToMiles - original) < 0.001)
    }

    @Test func roundTripWeightImperial() {
        let original = 100.0 // lbs
        let kg = UnitConverter.toKg(original, from: .imperial)
        let backToLbs = UnitConverter.fromKg(kg, to: .imperial)
        #expect(abs(backToLbs - original) < 0.001)
    }

    @Test func distanceStringImperial() {
        let str = UnitConverter.distanceString(1.60934, pref: .imperial)
        #expect(str == "1.0 mi")
    }

    @Test func distanceStringMetric() {
        let str = UnitConverter.distanceString(5.0, pref: .metric)
        #expect(str == "5.0 km")
    }

    @Test func weightStringWithReps() {
        // 45.3592 kg ≈ 100 lbs; 10 reps → "100 lbs × 10"
        let str = UnitConverter.weightString(45.3592, reps: 10, pref: .imperial)
        #expect(str.contains("100"))
        #expect(str.contains("× 10"))
    }

    @Test func weightStringNoRepsOmitsMultiplier() {
        let str = UnitConverter.weightString(45.3592, reps: nil, pref: .imperial)
        #expect(!str.contains("×"))
    }

    @Test func weightStringRepsOneOmitsMultiplier() {
        let str = UnitConverter.weightString(45.3592, reps: 1, pref: .imperial)
        #expect(!str.contains("×"))
    }
}

// MARK: - AppViewModel Tests

@Suite("AppViewModel")
@MainActor
struct AppViewModelTests {

    @Test func totalDistanceFiltersDistanceOnly() {
        let vm = AppViewModel()
        // Values in km
        vm.activities = [
            ActivityLog(type: .distance, value: 3.0),
            ActivityLog(type: .distance, value: 2.0),
            ActivityLog(type: .weight, value: 50),
        ]
        #expect(abs(vm.totalDistance - 5.0) < 0.001)
    }

    @Test func totalWeightFiltersWeightOnly() {
        let vm = AppViewModel()
        // Values in kg
        vm.activities = [
            ActivityLog(type: .weight, value: 90.0),
            ActivityLog(type: .weight, value: 60.0),
            ActivityLog(type: .distance, value: 5.0),
        ]
        #expect(abs(vm.totalWeight - 150.0) < 0.001)
    }

    @Test func totalWeightMultipliesReps() {
        let vm = AppViewModel()
        vm.activities = [
            ActivityLog(type: .weight, value: 100.0, reps: 10), // 1000 kg effective
            ActivityLog(type: .weight, value: 50.0,  reps: nil), // 50 kg (no reps = ×1)
        ]
        #expect(abs(vm.totalWeight - 1050.0) < 0.001)
    }

    @Test func totalWeightRepsOneEquivalentToNoReps() {
        let vm = AppViewModel()
        vm.activities = [
            ActivityLog(type: .weight, value: 80.0, reps: 1),
            ActivityLog(type: .weight, value: 80.0, reps: nil),
        ]
        #expect(abs(vm.totalWeight - 160.0) < 0.001)
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
        let first  = ComparisonEngine.distanceMilestones[0]
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

    // MARK: - Absurdity Ticker

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
        // D1 threshold = 1.60934 km; half of that = 0.80467 km → 50%
        vm.activities = [ActivityLog(type: .distance, value: 0.80467)]
        let text = vm.absurdityTickerText(for: .distance)
        #expect(text?.contains("50%") == true)
    }

    @Test func absurdityTickerReturnsNilWhenAllMilestonesCleared() {
        let vm = AppViewModel()
        vm.activities = [ActivityLog(type: .distance, value: 999_999)]
        #expect(vm.absurdityTickerText(for: .distance) == nil)
    }

    // Reps count should not affect distance ticker
    @Test func absurdityTickerIgnoresRepsForDistance() {
        let vm = AppViewModel()
        vm.activities = [ActivityLog(type: .distance, value: 0.80467, reps: 5)]
        let text = vm.absurdityTickerText(for: .distance)
        #expect(text?.contains("50%") == true)
    }
}

// MARK: - StreakEngine Tests

@Suite("StreakEngine")
@MainActor
struct StreakEngineTests {

    private func makeLog(daysAgo: Int) -> ActivityLog {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return ActivityLog(type: .distance, value: 1.0, loggedAt: date)
    }

    @Test func emptyActivitiesProducesZeroStreak() {
        let result = StreakEngine.compute(activities: [])
        #expect(result.currentStreak == 0)
        #expect(result.longestStreak == 0)
        #expect(!result.isActiveThisWeek)
    }

    @Test func singleActivityThisWeekProducesStreak1() {
        let result = StreakEngine.compute(activities: [makeLog(daysAgo: 0)])
        #expect(result.currentStreak == 1)
        #expect(result.isActiveThisWeek)
    }

    @Test func consecutiveWeeksProduceCorrectStreak() {
        let logs = [
            makeLog(daysAgo: 0),    // this week
            makeLog(daysAgo: 8),    // last week
            makeLog(daysAgo: 15),   // 2 weeks ago
        ]
        let result = StreakEngine.compute(activities: logs)
        #expect(result.currentStreak == 3)
        #expect(result.longestStreak >= 3)
    }

    @Test func gapBreaksStreak() {
        let logs = [
            makeLog(daysAgo: 0),    // this week
            makeLog(daysAgo: 15),   // 2 weeks ago (gap last week)
        ]
        let result = StreakEngine.compute(activities: logs)
        #expect(result.currentStreak == 1)
    }

    @Test func shieldedWeekFillsGap() {
        let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let shieldKey = WeekKey.from(date: lastWeek)
        let shieldJSON = StreakEngine.encodeShieldedWeeks([shieldKey])
        let logs = [
            makeLog(daysAgo: 0),    // this week
            makeLog(daysAgo: 15),   // 2 weeks ago — with shield on last week, chain continues
        ]
        let result = StreakEngine.compute(activities: logs, shieldedWeekKeysJSON: shieldJSON)
        #expect(result.currentStreak == 3)
    }

    @Test func longestStreakTracksAllTimeHigh() {
        let logs = (0..<5).map { makeLog(daysAgo: $0 * 7) }
        let result = StreakEngine.compute(activities: logs)
        #expect(result.longestStreak >= 5)
    }

    @Test func duplicateActivitiesSameWeekCountOnce() {
        let logs = [makeLog(daysAgo: 0), makeLog(daysAgo: 1), makeLog(daysAgo: 2)]
        let result = StreakEngine.compute(activities: logs)
        #expect(result.currentStreak == 1)
    }
}

// MARK: - SillyTitleEngine Tests

@Suite("SillyTitleEngine")
struct SillyTitleEngineTests {

    @Test func zeroUnlockIsUnranked() {
        let title = SillyTitleEngine.sillyTitle(unlockedCount: 0)
        #expect(title.rank == "Unranked")
    }

    @Test func maxUnlockIsDiamond() {
        let title = SillyTitleEngine.sillyTitle(unlockedCount: 22)
        #expect(title.rank == "Diamond")
    }

    @Test func certifiedHippoHoisterAt4() {
        let title = SillyTitleEngine.sillyTitle(unlockedCount: 4)
        #expect(title.title == "Certified Hippo Hoister")
    }

    @Test func titleAndRankNonEmpty() {
        for count in [0, 1, 3, 5, 8, 12, 16, 20, 22] {
            let title = SillyTitleEngine.sillyTitle(unlockedCount: count)
            #expect(!title.title.isEmpty)
            #expect(!title.rank.isEmpty)
            #expect(!title.rankEmoji.isEmpty)
        }
    }
}
