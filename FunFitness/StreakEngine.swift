//
//  StreakEngine.swift
//  FunFitness
//

import Foundation

// A calendar week identified by ISO year + week-of-year.
struct WeekKey: Hashable, Comparable, Codable, Sendable {
    let year: Int
    let week: Int

    static func from(date: Date, calendar: Calendar = .current) -> WeekKey {
        let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
        return WeekKey(year: comps.yearForWeekOfYear ?? 0, week: comps.weekOfYear ?? 0)
    }

    static func current(calendar: Calendar = .current) -> WeekKey {
        from(date: Date(), calendar: calendar)
    }

    static func < (lhs: WeekKey, rhs: WeekKey) -> Bool {
        lhs.year == rhs.year ? lhs.week < rhs.week : lhs.year < rhs.year
    }

    // The WeekKey one week before this one.
    func previous(calendar: Calendar = .current) -> WeekKey {
        let startOfWeek = calendar.date(from: DateComponents(
            weekOfYear: week, yearForWeekOfYear: year
        )) ?? Date()
        let prevDate = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) ?? startOfWeek
        return WeekKey.from(date: prevDate, calendar: calendar)
    }

    var string: String { String(format: "%d-W%02d", year, week) }
}

struct StreakResult {
    let currentStreak: Int      // consecutive active weeks ending at or including now
    let longestStreak: Int      // all-time high
    let isActiveThisWeek: Bool  // has an activity this ISO week
}

@MainActor
struct StreakEngine {

    // Decode the JSON string from StreakRecord into a Set<WeekKey>.
    static func shieldedWeeks(from json: String) -> Set<WeekKey> {
        guard let data = json.data(using: .utf8),
              let keys = try? JSONDecoder().decode([WeekKey].self, from: data)
        else { return [] }
        return Set(keys)
    }

    // Encode a Set<WeekKey> back to JSON for storage.
    static func encodeShieldedWeeks(_ weeks: Set<WeekKey>) -> String {
        let sorted = weeks.sorted()
        return (try? String(data: JSONEncoder().encode(sorted), encoding: .utf8)) ?? "[]"
    }

    // Activate a shield for the current week and return the updated JSON string.
    // Returns nil if no shields are available.
    static func activateShield(record: StreakRecord) -> Bool {
        guard record.shieldsAvailable > 0 else { return false }
        var keys = shieldedWeeks(from: record.shieldedWeekKeysJSON)
        keys.insert(WeekKey.current())
        record.shieldedWeekKeysJSON = encodeShieldedWeeks(keys)
        record.shieldsAvailable -= 1
        return true
    }

    // Recomputes streak from scratch given all activity dates and the set of
    // shielded weeks. Shielded weeks count as active for streak purposes.
    // Walking back from the current week, a gap of 1 unshielded week breaks the streak.
    static func compute(
        activities: [ActivityLog],
        shieldedWeekKeysJSON: String = "[]",
        calendar: Calendar = .current
    ) -> StreakResult {
        let shieldedWeeks = shieldedWeeks(from: shieldedWeekKeysJSON)
        let activeWeeks: Set<WeekKey> = Set(activities.map { WeekKey.from(date: $0.loggedAt, calendar: calendar) })
        let allCoveredWeeks = activeWeeks.union(shieldedWeeks)
        let today = WeekKey.current(calendar: calendar)

        let isActiveThisWeek = activeWeeks.contains(today)

        // Walk back from the current week counting consecutive covered weeks.
        var current = 0
        var cursor = today
        // If current week has no activity yet, that doesn't break the streak —
        // only fully elapsed weeks with no coverage break it.
        // But we don't credit the current week unless it's actually active.
        if allCoveredWeeks.contains(cursor) {
            current = 1
            cursor = cursor.previous(calendar: calendar)
            while allCoveredWeeks.contains(cursor) {
                current += 1
                cursor = cursor.previous(calendar: calendar)
            }
        } else {
            // Current week not covered — check last week to keep the streak alive
            let lastWeek = cursor.previous(calendar: calendar)
            if allCoveredWeeks.contains(lastWeek) {
                current = 1
                cursor = lastWeek.previous(calendar: calendar)
                while allCoveredWeeks.contains(cursor) {
                    current += 1
                    cursor = cursor.previous(calendar: calendar)
                }
            }
        }

        // Compute all-time longest streak by walking every covered week in order.
        let longest = longestRun(in: allCoveredWeeks, calendar: calendar)

        return StreakResult(
            currentStreak: current,
            longestStreak: max(longest, current),
            isActiveThisWeek: isActiveThisWeek
        )
    }

    // Returns the day-of-week (1=Sun … 7=Sat) for the current locale's first weekday.
    static func daysRemainingInWeek(calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.weekday], from: Date())
        let today = comps.weekday ?? 1
        let last  = calendar.firstWeekday == 1 ? 7 : 7  // last day is always index 7
        return last - today + (calendar.firstWeekday == 1 ? 0 : 1)
    }

    // MARK: - Private

    private static func longestRun(in weeks: Set<WeekKey>, calendar: Calendar) -> Int {
        guard !weeks.isEmpty else { return 0 }
        let sorted = weeks.sorted()
        var best = 1, run = 1
        for i in 1..<sorted.count {
            if sorted[i] == sorted[i - 1].next(calendar: calendar) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }
}

extension WeekKey {
    func next(calendar: Calendar = .current) -> WeekKey {
        let startOfWeek = calendar.date(from: DateComponents(
            weekOfYear: week, yearForWeekOfYear: year
        )) ?? Date()
        let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? startOfWeek
        return WeekKey.from(date: nextDate, calendar: calendar)
    }
}
