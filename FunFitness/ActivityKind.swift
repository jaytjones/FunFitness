//
//  ActivityKind.swift
//  FunFitness
//
//  Single source of truth for per-activity-type behavior (v2.2). Before this, ~30 sites
//  branched on `type == .distance ? … : …`, which silently misroutes any new type into the
//  "weight" branch. Everything type-specific now flows through these descriptor properties and
//  the matching switches in UnitConverter / ComparisonEngine, so adding a case forces the
//  compiler to flag every place that must handle it.
//

import Foundation

extension ActivityType {

    /// User-facing name for pickers, buttons, and labels.
    var displayName: String {
        switch self {
        case .distance: return "Distance"
        case .weight:   return "Weight"
        case .duration: return "Duration"
        case .reps:     return "Reps"
        }
    }

    /// Emoji shorthand used in buttons and summaries.
    var emoji: String {
        switch self {
        case .distance: return "🏃"
        case .weight:   return "💪"
        case .duration: return "⏱️"
        case .reps:     return "🤸"
        }
    }

    /// Whether a logged value is multiplied by a rep count when accumulating totals.
    /// Only weight uses the rep *multiplier*; every other type accumulates its value directly.
    /// (The `.reps` type is itself count-based — the count is the value, so no multiplier.)
    var usesReps: Bool {
        switch self {
        case .distance: return false
        case .weight:   return true
        case .duration: return false
        case .reps:     return false
        }
    }

    /// Whether the stored value differs between metric and imperial (needs conversion).
    /// Distance (km↔mi) and weight (kg↔lbs) convert; time (minutes) and count (reps) do not.
    var hasUnitConversion: Bool {
        switch self {
        case .distance, .weight: return true
        case .duration, .reps:   return false
        }
    }

    /// Keyboard uses a decimal point (distance) vs. whole numbers.
    var usesDecimalInput: Bool {
        switch self {
        case .distance: return true
        case .weight:   return false
        case .duration: return false   // whole minutes
        case .reps:     return false   // whole counts
        }
    }

    /// Whether this type's card is always shown on Home/Progress. The two core types
    /// (distance, weight) always appear; time/count cards surface only once they have data. (v2.2)
    var alwaysShowsCard: Bool {
        switch self {
        case .distance, .weight: return true
        case .duration, .reps:   return false
        }
    }

    /// Stable lowercase tag for exports and notification identifiers (matches rawValue).
    var exportName: String { rawValue }
}
