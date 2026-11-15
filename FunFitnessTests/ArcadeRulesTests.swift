//
//  ArcadeRulesTests.swift
//  FunFitnessTests
//
//  Arcade's game layer is display rules over existing data (docs/design/arcade/README.md): level =
//  silly-title tier index, rarity = position in the type's milestones, 8-segment bars.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Arcade rules")
@MainActor
struct ArcadeRulesTests {

    @Test func levelIsTheSillyTitleTier() {
        // README: the sample user has 8 badges → LVL 4 · Silver, 4 badges to Gold.
        let eight: Set<String> = ["D1", "D1b", "D2", "D2b", "W1", "W1b", "T1", "R1"]
        let level = SillyTitleEngine.level(unlockedIds: eight)
        #expect(level.level == 4)
        #expect(level.nextRank == "Gold")
        #expect(level.badgesToNext == 4)

        #expect(SillyTitleEngine.level(unlockedIds: []).level == 0)
        #expect(SillyTitleEngine.level(unlockedIds: []).nextRank == "Starter")
        #expect(SillyTitleEngine.level(unlockedIds: SillyTitleEngine.rankedMilestoneIds).level == 7)
        #expect(SillyTitleEngine.level(unlockedIds: SillyTitleEngine.rankedMilestoneIds).nextRank == nil)
    }

    @Test func unrankedIdsDontRaiseTheLevel() {
        // Journey-anchor tiers (D7–D10) aren't ranked, like the silly title.
        #expect(SillyTitleEngine.level(unlockedIds: ["D7", "D8", "D9", "D10"]).level == 0)
    }

    #if INTERNAL_STYLES
    @Test func rarityMatchesTheReadmeTable() {
        // Distance (15): Common D1–D3b, Rare D4–D5b, Epic D6–D8, Legendary D9–D10.
        let expected: [String: ArcadeRarity] = [
            "D1": .common, "D3b": .common, "D4": .rare, "D5b": .rare,
            "D6": .epic, "D8": .epic, "D9": .legendary, "D10": .legendary,
            // Duration (8): T1–T3 Common, T4–T5 Rare, T6–T7 Epic, T8 Legendary.
            "T3": .common, "T4": .rare, "T6": .epic, "T8": .legendary,
        ]
        for (id, rarity) in expected {
            #expect(ArcadeRules.rarity(of: id) == rarity, "\(id)")
        }
    }

    @Test func rarityTotalsMatchTheReadme() {
        // 16 Common, 12 Rare, 9 Epic, 5 Legendary across all 42.
        let all = ComparisonEngine.allMilestones.compactMap { ArcadeRules.rarity(of: $0.id) }
        #expect(all.count == 42)
        #expect(all.filter { $0 == .common }.count == 16)
        #expect(all.filter { $0 == .rare }.count == 12)
        #expect(all.filter { $0 == .epic }.count == 9)
        #expect(all.filter { $0 == .legendary }.count == 5)
    }

    @Test func segmentExamplesFromTheSpec() {
        #expect(ArcadeRules.litSegments(progress: 0.68) == 5)
        #expect(ArcadeRules.litSegments(progress: 0.50) == 4)
        #expect(ArcadeRules.litSegments(progress: 0.63) == 5)
        #expect(ArcadeRules.litSegments(progress: 0.72) == 6)
        #expect(ArcadeRules.litSegments(progress: 0.08) == 1)
        #expect(ArcadeRules.litSegments(progress: 0.99) == 7)   // held under 8 until reached
        #expect(ArcadeRules.litSegments(progress: 1.0) == 8)
        #expect(ArcadeRules.litSegments(progress: 0) == 0)
    }

    @Test func positionIsOneBasedInTheType() throws {
        let d1 = try #require(ArcadeRules.position(of: "D1"))
        #expect(d1.type == .distance)
        #expect(d1.index == 0)
        #expect(d1.count == 15)
    }

    @Test func splitsUnitFromNumeral() {
        #expect(ArcadeRules.split("2,589 lbs") == ("2,589", "lbs"))
        #expect(ArcadeRules.split("40") == ("40", ""))
    }
    #endif
}
