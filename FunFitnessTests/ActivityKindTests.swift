//
//  ActivityKindTests.swift
//  FunFitnessTests
//
//  Locks in the v2.2 activity-type descriptor + UnitConverter dispatch so the behavior-
//  preserving Segment 1 refactor can't silently drift, and so new types added later must be
//  handled everywhere the switches live.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("ActivityType descriptor")
struct ActivityKindTests {

    @Test func onlyWeightUsesReps() {
        #expect(ActivityType.weight.usesReps == true)
        #expect(ActivityType.distance.usesReps == false)
    }

    @Test func distanceAndWeightConvertUnits() {
        #expect(ActivityType.distance.hasUnitConversion == true)
        #expect(ActivityType.weight.hasUnitConversion == true)
    }

    @Test func displayNamesAreStable() {
        #expect(ActivityType.distance.displayName == "Distance")
        #expect(ActivityType.weight.displayName == "Weight")
    }

    // effectiveValue must multiply by reps only for rep-using types.
    @Test func effectiveValueRespectsUsesReps() {
        let weighted = ActivityLog(type: .weight, value: 100, reps: 3)
        #expect(weighted.effectiveValue == 300)

        let distance = ActivityLog(type: .distance, value: 5, reps: 3) // reps ignored for distance
        #expect(distance.effectiveValue == 5)
    }

    // Dispatch helpers must agree with the type-specific converters they wrap.
    @Test func toSIMatchesTypedConverters() {
        #expect(UnitConverter.toSI(1, type: .distance, from: .imperial) == UnitConverter.toKm(1, from: .imperial))
        #expect(UnitConverter.toSI(1, type: .weight, from: .imperial) == UnitConverter.toKg(1, from: .imperial))
    }

    @Test func displayStringMatchesTypedFormatters() {
        let km = 8.04672
        #expect(UnitConverter.displayString(km, type: .distance, pref: .metric)
                == UnitConverter.distanceString(km, pref: .metric))
        let kg = 100.0
        #expect(UnitConverter.displayString(kg, type: .weight, reps: 3, pref: .metric)
                == UnitConverter.weightString(kg, reps: 3, pref: .metric))
    }
}
