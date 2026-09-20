//
//  SeasonalTests.swift
//  FunFitnessTests
//
//  Locks in the v2.2 date-gated SeasonalEngine (windows + absurd conversions).
//

import Testing
import Foundation
@testable import FunFitness

@Suite("SeasonalEngine")
struct SeasonalTests {

    private let cal = Calendar.current

    private func date(month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = month; c.day = day; c.hour = 12
        return cal.date(from: c)!
    }

    // MARK: - Windows

    @Test func octoberIsHalloween() {
        #expect(SeasonalEngine.activeSeason(on: date(month: 10, day: 1)) == .halloween)
        #expect(SeasonalEngine.activeSeason(on: date(month: 10, day: 31)) == .halloween)
    }

    @Test func thanksgivingStartsMidNovember() {
        #expect(SeasonalEngine.activeSeason(on: date(month: 11, day: 14)) == nil)
        #expect(SeasonalEngine.activeSeason(on: date(month: 11, day: 15)) == .thanksgiving)
        #expect(SeasonalEngine.activeSeason(on: date(month: 11, day: 30)) == .thanksgiving)
    }

    @Test func decemberIsWinterHoliday() {
        #expect(SeasonalEngine.activeSeason(on: date(month: 12, day: 25)) == .winterHoliday)
    }

    @Test func offSeasonHasNoSeason() {
        #expect(SeasonalEngine.activeSeason(on: date(month: 1, day: 15)) == nil)
        #expect(SeasonalEngine.activeSeason(on: date(month: 6, day: 15)) == nil)
    }

    // MARK: - Comparisons

    @Test func thanksgivingConvertsWeightToTurkeys() {
        // 70 kg / 7 kg per turkey = 10 turkeys.
        let c = SeasonalEngine.comparison(for: .thanksgiving, totalWeightKg: 70, totalDistanceKm: 0)
        #expect(c?.emoji == "🦃")
        #expect(c?.text.contains("10 roast turkeys") == true)
    }

    @Test func halloweenConvertsWeightToPumpkins() {
        // 4 kg / 4 kg per pumpkin = 1 pumpkin (singular).
        let c = SeasonalEngine.comparison(for: .halloween, totalWeightKg: 4, totalDistanceKm: 0)
        #expect(c?.emoji == "🎃")
        #expect(c?.text.contains("1 carving pumpkin ") == true)   // singular, no trailing "s"
    }

    @Test func winterConvertsDistanceToCandyCanes() {
        let c = SeasonalEngine.comparison(for: .winterHoliday, totalWeightKg: 0, totalDistanceKm: 1.5)
        #expect(c?.emoji == "🍬")
        #expect(c?.text.contains("candy canes") == true)
    }

    @Test func comparisonIsNilWhenRelevantTotalIsZero() {
        #expect(SeasonalEngine.comparison(for: .thanksgiving, totalWeightKg: 0, totalDistanceKm: 100) == nil)
        #expect(SeasonalEngine.comparison(for: .winterHoliday, totalWeightKg: 100, totalDistanceKm: 0) == nil)
    }

    @Test func currentComparisonCombinesWindowAndTotals() {
        // In-season with data → present; off-season → nil.
        #expect(SeasonalEngine.currentComparison(on: date(month: 11, day: 20), totalWeightKg: 70, totalDistanceKm: 0) != nil)
        #expect(SeasonalEngine.currentComparison(on: date(month: 6, day: 1), totalWeightKg: 70, totalDistanceKm: 0) == nil)
    }
}
