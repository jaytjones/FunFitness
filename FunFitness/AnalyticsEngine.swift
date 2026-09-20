//
//  AnalyticsEngine.swift
//  FunFitness
//
//  Pure, deterministic analytics derived from the activity log (v2.2). Feeds the Progress tab's
//  Swift Charts views: weekly volume, personal records, and a day-by-day activity heatmap. Every
//  function takes an explicit reference date and calendar so results never depend on the wall
//  clock and are fully unit-testable.
//

import Foundation

enum AnalyticsEngine {

    // MARK: - Weekly volume

    /// Summed effective value for one activity type in a single calendar week.
    struct WeeklyBucket: Identifiable, Equatable {
        let weekStart: Date   // start of the week (per the calendar)
        let total: Double     // effective value in SI for the type
        var id: Date { weekStart }
    }

    /// The last `weeks` calendar weeks (oldest → newest) of summed `effectiveValue` for `type`.
    /// Weeks with no matching activity are included with a total of 0 so the chart has a
    /// continuous x-axis.
    static func weeklyVolume(
        type: ActivityType,
        activities: [ActivityLog],
        now: Date,
        weeks: Int = 8,
        calendar: Calendar = .current
    ) -> [WeeklyBucket] {
        guard weeks > 0,
              let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
        else { return [] }

        // Oldest week first.
        let starts: [Date] = (0..<weeks).reversed().compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart)
        }

        let matching = activities.filter { $0.activityType == type }

        return starts.map { start in
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            let total = matching
                .filter { $0.loggedAt >= start && $0.loggedAt < end }
                .reduce(0.0) { $0 + $1.effectiveValue }
            return WeeklyBucket(weekStart: start, total: total)
        }
    }

    // MARK: - Personal records

    /// The largest single logged `effectiveValue` for `type` (a personal best), or nil if the
    /// user has never logged that type.
    static func personalRecord(type: ActivityType, activities: [ActivityLog]) -> Double? {
        activities.lazy
            .filter { $0.activityType == type }
            .map(\.effectiveValue)
            .max()
    }

    // MARK: - Activity heatmap

    /// Number of activities logged on a single day.
    struct DayCount: Identifiable, Equatable {
        let day: Date     // start of day (per the calendar)
        let count: Int
        var id: Date { day }
    }

    /// Per-day activity counts across the last `days` days (oldest → newest), ending on the day of
    /// `now`. Every day in the window is present (count 0 when nothing was logged) so a heatmap can
    /// render a full grid.
    static func dailyActivity(
        activities: [ActivityLog],
        now: Date,
        days: Int = 84,
        calendar: Calendar = .current
    ) -> [DayCount] {
        guard days > 0 else { return [] }
        let today = calendar.startOfDay(for: now)

        // Bucket activities by start-of-day for O(n) lookup.
        var counts: [Date: Int] = [:]
        for activity in activities {
            let day = calendar.startOfDay(for: activity.loggedAt)
            counts[day, default: 0] += 1
        }

        return (0..<days).reversed().compactMap { offset -> DayCount? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayCount(day: day, count: counts[day] ?? 0)
        }
    }
}
