//
//  UnitConverter.swift
//  FunFitness
//
//  Unit conversion between stored SI values (km, kg) and display units (mi, lbs).
//

import Foundation

enum UnitPreference: String, Codable, CaseIterable {
    case imperial
    case metric

    var displayName: String {
        switch self {
        case .imperial: return "Imperial (mi, lbs)"
        case .metric:   return "Metric (km, kg)"
        }
    }

    var distanceUnit: String { self == .imperial ? "mi" : "km" }
    var weightUnit: String   { self == .imperial ? "lbs" : "kg" }
}

struct UnitConverter {

    // MARK: - Constants

    static let kmPerMile: Double  = 1.60934
    static let milesPerKm: Double = 0.621371
    static let kgPerLb: Double    = 0.453592
    static let lbsPerKg: Double   = 2.20462

    // MARK: - User input → SI (for storage)

    static func toKm(_ value: Double, from pref: UnitPreference) -> Double {
        pref == .imperial ? value * kmPerMile : value
    }

    static func toKg(_ value: Double, from pref: UnitPreference) -> Double {
        pref == .imperial ? value * kgPerLb : value
    }

    // MARK: - SI → display value (for reading back)

    static func fromKm(_ km: Double, to pref: UnitPreference) -> Double {
        pref == .imperial ? km * milesPerKm : km
    }

    static func fromKg(_ kg: Double, to pref: UnitPreference) -> Double {
        pref == .imperial ? kg * lbsPerKg : kg
    }

    // MARK: - Formatted display strings

    static func distanceString(_ km: Double, pref: UnitPreference) -> String {
        String(format: "%.1f %@", fromKm(km, to: pref), pref.distanceUnit)
    }

    /// Formats a weight value. If reps > 1, appends "× N".
    static func weightString(_ kg: Double, reps: Int? = nil, pref: UnitPreference) -> String {
        let value = fromKg(kg, to: pref)
        let formatted = pref == .imperial
            ? String(format: "%.0f %@", value, pref.weightUnit)
            : String(format: "%.1f %@", value, pref.weightUnit)
        if let reps, reps > 1 { return "\(formatted) × \(reps)" }
        return formatted
    }

    // MARK: - Pre-fill helpers for text fields

    static func distanceInputString(_ km: Double, pref: UnitPreference) -> String {
        String(format: "%.1f", fromKm(km, to: pref))
    }

    static func weightInputString(_ kg: Double, pref: UnitPreference) -> String {
        let value = fromKg(kg, to: pref)
        return pref == .imperial ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    // MARK: - Type-dispatched helpers (v2.2)
    // A single place that maps an ActivityType to the right conversion/format above, so
    // callers no longer branch on `type == .distance`. Each switch is exhaustive, so a new
    // activity type forces every conversion path to be handled explicitly.

    /// Converts a user-entered display value to the stored SI value for the given type.
    static func toSI(_ value: Double, type: ActivityType, from pref: UnitPreference) -> Double {
        switch type {
        case .distance: return toKm(value, from: pref)
        case .weight:   return toKg(value, from: pref)
        }
    }

    /// Converts a stored SI value back to a display value for the given type.
    static func fromSI(_ si: Double, type: ActivityType, to pref: UnitPreference) -> Double {
        switch type {
        case .distance: return fromKm(si, to: pref)
        case .weight:   return fromKg(si, to: pref)
        }
    }

    /// Formatted, unit-suffixed display string for a stored SI value of the given type.
    static func displayString(_ si: Double, type: ActivityType, reps: Int? = nil, pref: UnitPreference) -> String {
        switch type {
        case .distance: return distanceString(si, pref: pref)
        case .weight:   return weightString(si, reps: reps, pref: pref)
        }
    }

    /// Text-field pre-fill string (no unit suffix) for a stored SI value of the given type.
    static func inputString(_ si: Double, type: ActivityType, pref: UnitPreference) -> String {
        switch type {
        case .distance: return distanceInputString(si, pref: pref)
        case .weight:   return weightInputString(si, pref: pref)
        }
    }

    /// The display-unit label (e.g. "mi"/"km") for the given type + preference.
    static func displayUnit(for type: ActivityType, pref: UnitPreference) -> String {
        switch type {
        case .distance: return pref.distanceUnit
        case .weight:   return pref.weightUnit
        }
    }

    /// The canonical SI unit tag (e.g. "km"/"kg") for the given type, used in exports.
    static func siUnit(for type: ActivityType) -> String {
        switch type {
        case .distance: return "km"
        case .weight:   return "kg"
        }
    }
}
