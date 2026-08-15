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
        }
    }

    /// Emoji shorthand used in buttons and summaries.
    var emoji: String {
        switch self {
        case .distance: return "🏃"
        case .weight:   return "💪"
        }
    }

    /// Whether a logged value is multiplied by a rep count when accumulating totals.
    /// Only weight uses reps; distance accumulates its value directly.
    var usesReps: Bool {
        switch self {
        case .distance: return false
        case .weight:   return true
        }
    }

    /// Whether the stored value differs between metric and imperial (needs conversion).
    /// Distance (km↔mi) and weight (kg↔lbs) convert; count/time-based types would not.
    var hasUnitConversion: Bool {
        switch self {
        case .distance, .weight: return true
        }
    }

    /// Keyboard uses a decimal point (distance) vs. whole numbers.
    var usesDecimalInput: Bool {
        switch self {
        case .distance: return true
        case .weight:   return false
        }
    }

    /// Stable lowercase tag for exports and notification identifiers (matches rawValue).
    var exportName: String { rawValue }
}
