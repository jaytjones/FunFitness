//
//  ReferenceUnitTests.swift
//  FunFitnessTests
//
//  v2.3: reference-unit catalog coverage and bestFit selection.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("ReferenceUnit")
@MainActor
struct ReferenceUnitTests {

    // Every pack must be able to restate every activity type on its own.
    @Test func everyPackHasUnitsForEveryType() {
        for pack in ThemePackCatalog.all {
            let units = ReferenceUnitCatalog.byPack[pack.id] ?? []
            for type in ActivityType.allCases {
                #expect(units.contains { $0.type == type }, "\(pack.id) has no \(type) units")
            }
        }
    }

    @Test func unitsAreWellFormed() {
        let all = ReferenceUnitCatalog.byPack.values.flatMap { $0 }
        #expect(Set(all.map(\.id)).count == all.count, "duplicate reference unit ids")
        for unit in all {
            #expect(unit.magnitude > 0, "\(unit.id) magnitude")
            #expect(!unit.singular.isEmpty && !unit.plural.isEmpty && !unit.emoji.isEmpty, "\(unit.id) copy")
        }
    }

    @Test func zeroTotalHasNoFit() {
        #expect(ReferenceUnitEngine.bestFit(total: 0, type: .weight, packId: "animals") == nil)
    }

    // Picks the largest unit the total covers at least once.
    @Test func picksLargestUnitWithCountAtLeastOne() throws {
        let fit = try #require(ReferenceUnitEngine.bestFit(total: 3_000, type: .weight, packId: "animals"))
        #expect(fit.unit.id == "animals.hippo")
        #expect(fit.count == 2)
        #expect(fit.phrase == "2 hippos")
    }

    // Below the smallest unit it reports a fraction of that unit.
    @Test func belowSmallestUnitUsesAFraction() throws {
        let fit = try #require(ReferenceUnitEngine.bestFit(total: 0.015, type: .distance, packId: "animals"))
        #expect(fit.unit.id == "animals.blueWhaleLength")
        #expect(fit.phrase == "0.5 blue whale lengths")
    }

    @Test func exactlyOneIsSingular() throws {
        let fit = try #require(ReferenceUnitEngine.bestFit(total: 1_500, type: .weight, packId: "animals"))
        #expect(fit.phrase == "1 hippo")
    }

    @Test func largeCountsAreWholeNumbers() throws {
        let fit = try #require(ReferenceUnitEngine.bestFit(total: 1_500_000, type: .weight, packId: "animals"))
        #expect(fit.unit.id == "animals.blueWhale")
        #expect(fit.phrase == "10 blue whales")
    }

    @Test func unknownPackFallsBackToAnimals() throws {
        let fit = try #require(ReferenceUnitEngine.bestFit(total: 3_000, type: .weight, packId: "not-a-pack"))
        #expect(fit.unit.id == "animals.hippo")
    }
}
