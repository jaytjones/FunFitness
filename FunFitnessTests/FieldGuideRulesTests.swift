//
//  FieldGuideRulesTests.swift
//  FunFitnessTests
//
//  Field Guide's voice is a light layer over real data (docs/design/field-guide/README.md):
//  specimen numbers, Animals-only binomials, spelled-out units, roman field notes, "a"/"an".
//

import Testing
import Foundation
@testable import FunFitness

#if INTERNAL_STYLES
@Suite("Field Guide rules")
@MainActor
struct FieldGuideRulesTests {

    @Test func specimenNumbersFollowTheCatalogue() {
        #expect(FieldGuideRules.specimenNumber(ComparisonEngine.allMilestones[0].id) == 1)
        #expect(FieldGuideRules.specimenNumber(ComparisonEngine.allMilestones.last!.id) == ComparisonEngine.allMilestones.count)
        #expect(FieldGuideRules.specimenNumber("nope") == nil)
    }

    @Test func binomialsOnlyInTheAnimalsPack() {
        #expect(FieldGuideRules.binomial(for: "🐳", packId: "animals") == "Balaenoptera musculus")
        #expect(FieldGuideRules.binomial(for: "🐘", packId: "animals") == "Loxodonta africana")
        #expect(FieldGuideRules.binomial(for: "🐳", packId: "food") == nil)
        #expect(FieldGuideRules.binomial(for: "🍕", packId: "animals") == nil)
    }

    @Test func unitsAreSpelledOut() {
        #expect(FieldGuideRules.totalInWords("21.9 mi") == "21.9 miles")
        #expect(FieldGuideRules.totalInWords("1 mi") == "1 mile")
        #expect(FieldGuideRules.totalInWords("2,589 lbs") == "2,589 pounds")
        #expect(FieldGuideRules.totalInWords("40 min") == "40 minutes")
        #expect(FieldGuideRules.totalInWords("12.3 km") == "12.3 kilometers")
    }

    @Test func romanNumerals() {
        #expect((1...5).map(FieldGuideRules.roman) == ["i", "ii", "iii", "iv", "v"])
        #expect(FieldGuideRules.roman(9) == "ix")
        #expect(FieldGuideRules.roman(14) == "xiv")
    }

    @Test func articleFromFirstLetter() {
        #expect(FieldGuideRules.article(for: "Elite Elephant Wrangler") == "an")
        #expect(FieldGuideRules.article(for: "Mythical Whale Chaser") == "a")
    }
}
#endif
