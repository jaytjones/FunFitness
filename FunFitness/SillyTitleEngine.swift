//
//  SillyTitleEngine.swift
//  FunFitness
//

import Foundation

struct SillyTitle {
    let title: String   // e.g. "Certified Hippo Hoister"
    let rank: String    // e.g. "Silver"
    let rankEmoji: String
}

struct SillyTitleEngine {

    static func sillyTitle(unlockedCount: Int) -> SillyTitle {
        let tier = tier(for: unlockedCount)
        return SillyTitle(title: tier.title, rank: tier.rank, rankEmoji: tier.emoji)
    }

    // MARK: - Private

    private struct Tier {
        let minUnlocked: Int
        let title: String
        let rank: String
        let emoji: String
    }

    // Ordered descending so the first match wins.
    private static let tiers: [Tier] = [
        Tier(minUnlocked: 20, title: "Grand Poobah of Perpetual Motion",  rank: "Diamond",  emoji: "💎"),
        Tier(minUnlocked: 16, title: "Mythical Whale Chaser",              rank: "Platinum", emoji: "🌟"),
        Tier(minUnlocked: 12, title: "Legendary Giraffe Stacker",          rank: "Gold",     emoji: "🥇"),
        Tier(minUnlocked:  8, title: "Elite Elephant Wrangler",            rank: "Silver",   emoji: "🥈"),
        Tier(minUnlocked:  4, title: "Certified Hippo Hoister",            rank: "Bronze",   emoji: "🥉"),
        Tier(minUnlocked:  2, title: "Aspiring Animal Accumulator",        rank: "Iron",     emoji: "⚙️"),
        Tier(minUnlocked:  1, title: "Rookie Reps",                        rank: "Starter",  emoji: "🌱"),
        Tier(minUnlocked:  0, title: "Future Legend",                      rank: "Unranked", emoji: "🎯"),
    ]

    private static func tier(for count: Int) -> Tier {
        tiers.first { count >= $0.minUnlocked } ?? tiers.last!
    }
}
