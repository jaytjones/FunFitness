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
        #expect(ActivityType.duration.displayName == "Duration")
        #expect(ActivityType.reps.displayName == "Reps")
    }

    // v2.2 types are count/time-based: no rep multiplier, no unit conversion, whole-number input.
    @Test func newTypesAreUnitAgnostic() {
        for type in [ActivityType.duration, .reps] {
            #expect(type.usesReps == false)
            #expect(type.hasUnitConversion == false)
            #expect(type.usesDecimalInput == false)
            // Identity conversion in both directions.
            #expect(UnitConverter.toSI(42, type: type, from: .imperial) == 42)
            #expect(UnitConverter.fromSI(42, type: type, to: .metric) == 42)
        }
    }

    // Core types always show a card; the new types surface only once they have data.
    @Test func onlyCoreTypesAlwaysShowCards() {
        #expect(ActivityType.distance.alwaysShowsCard == true)
        #expect(ActivityType.weight.alwaysShowsCard == true)
        #expect(ActivityType.duration.alwaysShowsCard == false)
        #expect(ActivityType.reps.alwaysShowsCard == false)
    }

    // The "Reps (reps)" redundancy is collapsed to just "Reps"; others keep the unit suffix.
    @Test func fieldLabelDropsRedundantUnit() {
        #expect(UnitConverter.fieldLabel(for: .reps, pref: .metric) == "Reps")
        #expect(UnitConverter.fieldLabel(for: .duration, pref: .metric) == "Duration (min)")
        #expect(UnitConverter.fieldLabel(for: .distance, pref: .metric) == "Distance (km)")
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
