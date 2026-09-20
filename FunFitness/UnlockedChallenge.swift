//
//  UnlockedChallenge.swift
//  FunFitness
//
//  Persisted record of a completed monthly challenge (v2.2). Mirrors UnlockedAchievement.
//  `challengeKey` is "<challengeId>#<year>" so each year's occurrence of a recurring monthly
//  challenge is a distinct, permanent badge.
//

import Foundation
import SwiftData

@Model
final class UnlockedChallenge {
    // Defaults present so the schema is CloudKit-compatible (v2.1 rules: optional or defaulted,
    // no unique constraints, no relationships).
    var challengeKey: String = ""   // "<challengeId>#<year>" — the badge's stable identity
    var challengeId: String = ""    // references a Challenge in ChallengeCatalog
    var year: Int = 0               // the year this occurrence was earned
    var unlockedAt: Date = Date()

    init(challengeId: String, year: Int, unlockedAt: Date = Date()) {
        self.challengeId = challengeId
        self.year = year
        self.challengeKey = ChallengeEngine.unlockKey(id: challengeId, year: year)
        self.unlockedAt = unlockedAt
    }
}
