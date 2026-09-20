//
//  AnalyticsTests.swift
//  FunFitnessTests
//
//  Locks in the v2.2 AnalyticsEngine (weekly volume, personal records, activity heatmap).
//  All cases use a fixed reference date so bucketing never depends on the wall clock.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("AnalyticsEngine")
struct AnalyticsTests {

    private let cal = Calendar.current

    private func fixedNow() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 15; c.hour = 12
        return cal.date(from: c)!
    }

    // MARK: - Weekly volume

    @Test func weeklyVolumeBucketsByWeekAndType() {
        let now = fixedNow()
        let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: now)!
        let activities = [
            ActivityLog(type: .distance, value: 5, loggedAt: now),        // this week
            ActivityLog(type: .distance, value: 3, loggedAt: now),        // this week
            ActivityLog(type: .distance, value: 10, loggedAt: lastWeek),  // previous week
            ActivityLog(type: .weight,   value: 100, reps: 3, loggedAt: now), // wrong type
        ]
        let buckets = AnalyticsEngine.weeklyVolume(type: .distance, activities: activities, now: now, weeks: 4)

        #expect(buckets.count == 4)
        #expect(buckets.map(\.weekStart) == buckets.map(\.weekStart).sorted())  // oldest → newest
        #expect(abs(buckets[3].total - 8) < 0.001)   // this week: 5 + 3
        #expect(abs(buckets[2].total - 10) < 0.001)  // previous week
        #expect(buckets[0].total == 0)               // empty weeks present with 0
        #expect(buckets[1].total == 0)
    }

    @Test func weeklyVolumeZeroWeeksIsEmpty() {
        #expect(AnalyticsEngine.weeklyVolume(type: .distance, activities: [], now: fixedNow(), weeks: 0).isEmpty)
    }

    // MARK: - Personal records

    @Test func personalRecordIsMaxEffectiveValue() {
        let activities = [
            ActivityLog(type: .weight,   value: 100, reps: 3),  // 300 effective
            ActivityLog(type: .weight,   value: 250, reps: 1),  // 250 effective
            ActivityLog(type: .distance, value: 5),
        ]
        #expect(AnalyticsEngine.personalRecord(type: .weight, activities: activities) == 300)
        #expect(AnalyticsEngine.personalRecord(type: .distance, activities: activities) == 5)
    }

    @Test func personalRecordNilWhenNoneLogged() {
        let activities = [ActivityLog(type: .distance, value: 5)]
        #expect(AnalyticsEngine.personalRecord(type: .reps, activities: activities) == nil)
    }

    // MARK: - Activity heatmap

    @Test func dailyActivityCountsPerDay() {
        let now = fixedNow()
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: now)!
        let activities = [
            ActivityLog(type: .distance, value: 1, loggedAt: now),          // today
            ActivityLog(type: .weight,   value: 1, loggedAt: now),          // today → count 2
            ActivityLog(type: .distance, value: 1, loggedAt: threeDaysAgo), // 3 days ago
        ]
        let days = AnalyticsEngine.dailyActivity(activities: activities, now: now, days: 7)

        #expect(days.count == 7)
        #expect(days.map(\.day) == days.map(\.day).sorted())  // oldest → newest
        #expect(days.last?.count == 2)                        // today
        #expect(days[days.count - 4].count == 1)              // 3 days ago
        #expect(days.reduce(0) { $0 + $1.count } == 3)        // nothing counted outside the window
    }

    @Test func dailyActivityZeroDaysIsEmpty() {
        #expect(AnalyticsEngine.dailyActivity(activities: [], now: fixedNow(), days: 0).isEmpty)
    }
}
