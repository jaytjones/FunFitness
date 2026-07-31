//
//  StreakRecord.swift
//  FunFitness
//

import Foundation
import SwiftData

@Model
final class StreakRecord {
    var currentStreak: Int
    var longestStreak: Int
    var shieldsAvailable: Int
    // JSON-encoded array of "YYYY-Www" strings for shielded weeks.
    var shieldedWeekKeysJSON: String
    var lastUpdated: Date

    init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        shieldsAvailable: Int = 1,
        shieldedWeekKeysJSON: String = "[]",
        lastUpdated: Date = Date()
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.shieldsAvailable = shieldsAvailable
        self.shieldedWeekKeysJSON = shieldedWeekKeysJSON
        self.lastUpdated = lastUpdated
    }

    // Regenerates 1 shield on the 1st of each calendar month (capped at 1).
    func regenerateShieldIfNeeded() {
        let cal = Calendar.current
        let now = Date()
        if cal.component(.month, from: lastUpdated) != cal.component(.month, from: now) ||
           cal.component(.year,  from: lastUpdated) != cal.component(.year,  from: now) {
            shieldsAvailable = min(shieldsAvailable + 1, 1)
            lastUpdated = now
        }
    }
}
