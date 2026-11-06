//
//  WatchStatsStore.swift
//  FunFitness (in WatchShared/: compiled into the iPhone app, the Watch app, and the Watch widgets)
//
//  Where the Watch keeps the latest WatchContext from the phone so its complications can read it
//  (3.1 build 12). App Group storage on the Watch; the iPhone app doesn't use it.
//

import Foundation

nonisolated enum WatchStatsStore {
    static let suiteName = "group.com.discoverhealthquest.funfitness"
    static let key = "watchContext"

    static func save(_ context: WatchContext) {
        guard let data = try? JSONEncoder().encode(context) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
    }

    static func load() -> WatchContext? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchContext.self, from: data)
    }
}

nonisolated extension WatchContext {
    /// This week's Effort Points: the phone's value if it was computed this week, else 0 (a new
    /// week started since the phone last sent stats).
    func effortPoints(asOf now: Date, calendar: Calendar = .current) -> Double {
        guard let points = effortPoints, let updatedAt,
              let week = calendar.dateInterval(of: .weekOfYear, for: now),
              week.contains(updatedAt) else { return 0 }
        return points
    }

    var target: Double { effortTarget ?? 150 }

    /// 0…1 toward the weekly target.
    func effortFraction(asOf now: Date, calendar: Calendar = .current) -> Double {
        target > 0 ? min(1, effortPoints(asOf: now, calendar: calendar) / target) : 0
    }
}
