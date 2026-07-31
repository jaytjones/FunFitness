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
}
