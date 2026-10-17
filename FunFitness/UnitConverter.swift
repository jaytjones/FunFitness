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

    // Display strings use locale grouping ("1,234.5 mi"); the *InputString pre-fills below stay
    // ungrouped so text fields can parse them back. (v2.4)
    static func distanceString(_ km: Double, pref: UnitPreference) -> String {
        "\(fromKm(km, to: pref).formatted(.number.precision(.fractionLength(1)))) \(pref.distanceUnit)"
    }

    /// Formats a weight value. If reps > 1, appends "× N".
    static func weightString(_ kg: Double, reps: Int? = nil, pref: UnitPreference) -> String {
        let value = fromKg(kg, to: pref)
        let digits = pref == .imperial ? 0 : 1
        let formatted = "\(value.formatted(.number.precision(.fractionLength(digits)))) \(pref.weightUnit)"
        if let reps, reps > 1 { return "\(formatted) × \(reps)" }
        return formatted
    }

    // MARK: - Duration & reps (v2.2, no unit conversion — stored value is display value)

    /// Formats stored minutes. Reads as hours once it crosses an hour so big totals stay legible.
    static func durationString(_ minutes: Double) -> String {
        if minutes >= 60 {
            return "\((minutes / 60).formatted(.number.precision(.fractionLength(1)))) hr"
        }
        return "\(minutes.formatted(.number.precision(.fractionLength(0)))) min"
    }

    /// Formats a stored rep count.
    static func repsString(_ count: Double) -> String {
        "\(count.formatted(.number.precision(.fractionLength(0)))) reps"
    }

    // MARK: - Live tracking (3.1)

    /// Stopwatch-style elapsed time: "12:05", or "1:02:05" past an hour.
    static func elapsedString(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Pace per display unit, e.g. "9:41 /mi". "--:--" when there isn't a pace yet.
    static func paceString(secondsPerKm: Double?, pref: UnitPreference) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else {
            return "--:-- /\(pref.distanceUnit)"
        }
        let perUnit = pref == .imperial ? secondsPerKm * kmPerMile : secondsPerKm
        // Slower than 99 minutes per unit is standing around, not a pace.
        guard perUnit < 99 * 60 else { return "--:-- /\(pref.distanceUnit)" }
        let total = Int(perUnit.rounded())
        return String(format: "%d:%02d /%@", total / 60, total % 60, pref.distanceUnit)
    }

    // MARK: - Pre-fill helpers for text fields

    static func distanceInputString(_ km: Double, pref: UnitPreference) -> String {
        String(format: "%.1f", fromKm(km, to: pref))
    }

    static func weightInputString(_ kg: Double, pref: UnitPreference) -> String {
        let value = fromKg(kg, to: pref)
        return pref == .imperial ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    /// Whole-number pre-fill for duration/reps (the field is always edited in its own unit).
    static func wholeInputString(_ value: Double) -> String {
        String(format: "%.0f", value)
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
        case .duration, .reps: return value   // no unit conversion
        }
    }

    /// Converts a stored SI value back to a display value for the given type.
    static func fromSI(_ si: Double, type: ActivityType, to pref: UnitPreference) -> Double {
        switch type {
        case .distance: return fromKm(si, to: pref)
        case .weight:   return fromKg(si, to: pref)
        case .duration, .reps: return si      // no unit conversion
        }
    }

    /// Formatted, unit-suffixed display string for a stored SI value of the given type.
    static func displayString(_ si: Double, type: ActivityType, reps: Int? = nil, pref: UnitPreference) -> String {
        switch type {
        case .distance: return distanceString(si, pref: pref)
        case .weight:   return weightString(si, reps: reps, pref: pref)
        case .duration: return durationString(si)
        case .reps:     return repsString(si)
        }
    }

    /// Text-field pre-fill string (no unit suffix) for a stored SI value of the given type.
    static func inputString(_ si: Double, type: ActivityType, pref: UnitPreference) -> String {
        switch type {
        case .distance: return distanceInputString(si, pref: pref)
        case .weight:   return weightInputString(si, pref: pref)
        case .duration, .reps: return wholeInputString(si)
        }
    }

    /// The display-unit label (e.g. "mi"/"km") for the given type + preference.
    static func displayUnit(for type: ActivityType, pref: UnitPreference) -> String {
        switch type {
        case .distance: return pref.distanceUnit
        case .weight:   return pref.weightUnit
        case .duration: return "min"
        case .reps:     return "reps"
        }
    }

    /// The canonical SI unit tag (e.g. "km"/"kg") for the given type, used in exports.
    static func siUnit(for type: ActivityType) -> String {
        switch type {
        case .distance: return "km"
        case .weight:   return "kg"
        case .duration: return "min"
        case .reps:     return "reps"
        }
    }

    /// Field header like "Distance (mi)" or "Duration (min)". Drops the redundant parenthetical
    /// when the type name and unit are the same word (so `.reps` shows "Reps", not "Reps (reps)").
    static func fieldLabel(for type: ActivityType, pref: UnitPreference) -> String {
        let unit = displayUnit(for: type, pref: pref)
        let name = type.displayName
        return unit.caseInsensitiveCompare(name) == .orderedSame ? name : "\(name) (\(unit))"
    }
}
