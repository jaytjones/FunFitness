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

    /// The milestones that count toward rank, frozen at the 38 that existed in 2.2. New tiers are
    /// left out on purpose so adding them doesn't silently promote existing users; to rank on a
    /// new tier, add its id here and re-tune the cutoffs below in the same change. (v2.3)
    static let rankedMilestoneIds: Set<String> = [
        "D1", "D1b", "D2", "D2b", "D3", "D3b", "D4", "D4b", "D5", "D5b", "D6",
        "W1", "W1b", "W2", "W2b", "W3", "W3b", "W4", "W4b", "W5", "W5b", "W6",
        "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8",
        "R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8",
    ]

    /// Title for a set of unlocked milestone ids. Only ranked ids count, so tiers added later and
    /// ids synced from a newer build don't change the rank.
    static func sillyTitle(unlockedIds: Set<String>) -> SillyTitle {
        sillyTitle(unlockedCount: unlockedIds.intersection(rankedMilestoneIds).count)
    }

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
