//
//  TrackedCaloriesTests.swift
//  FunFitnessTests
//
//  FB-0020 item 4: tracked walks and runs save estimated active energy to Health, so they count
//  toward the Move ring. Distance-based (≈ 0.5 kcal/kg/km walking, ≈ 1.0 running).
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Tracked walk/run calories")
struct TrackedCaloriesTests {

    @Test func walkingIsHalfAKcalPerKgPerKm() throws {
        let kcal = try #require(CalorieEstimator.kcal(distanceMeters: 5_000, kind: .walk, weightKg: 70))
        #expect(abs(kcal - 175) < 0.001)
    }

    @Test func runningIsAboutOneKcalPerKgPerKm() throws {
        let kcal = try #require(CalorieEstimator.kcal(distanceMeters: 5_000, kind: .run, weightKg: 70))
        #expect(abs(kcal - 350) < 0.001)
    }

    @Test func noWeightOrDistanceMeansNoEstimate() {
        #expect(CalorieEstimator.kcal(distanceMeters: 5_000, kind: .walk, weightKg: nil) == nil)
        #expect(CalorieEstimator.kcal(distanceMeters: 5_000, kind: .walk, weightKg: 0) == nil)
        #expect(CalorieEstimator.kcal(distanceMeters: 0, kind: .run, weightKg: 70) == nil)
    }
}
