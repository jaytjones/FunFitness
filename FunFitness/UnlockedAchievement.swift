//
//  UnlockedAchievement.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import Foundation
import SwiftData

@Model
final class UnlockedAchievement {
    // Defaults present so the schema is CloudKit-compatible (v2.1).
    var milestoneId: String = "" // References milestone definition (e.g. "D1", "W2")
    var unlockedAt: Date = Date()

    init(
        milestoneId: String,
        unlockedAt: Date = Date()
    ) {
        self.milestoneId = milestoneId
        self.unlockedAt = unlockedAt
    }
}
