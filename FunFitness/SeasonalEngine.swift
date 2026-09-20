//
//  SeasonalEngine.swift
//  FunFitness
//
//  Seasonal comparison variants (v2.2). A date-gated overlay that, during a holiday window,
//  reframes the user's running totals as a festive absurd comparison (the first holiday season
//  gets turkeys). Pure and deterministic — every function takes an explicit reference date so the
//  active season never depends on the wall clock.
//

import Foundation

enum Season: String, CaseIterable {
    case halloween
    case thanksgiving
    case winterHoliday

    var name: String {
        switch self {
        case .halloween:     return "Halloween"
        case .thanksgiving:  return "Thanksgiving"
        case .winterHoliday: return "Winter Holidays"
        }
    }

    var emoji: String {
        switch self {
        case .halloween:     return "🎃"
        case .thanksgiving:  return "🦃"
        case .winterHoliday: return "🎄"
        }
    }
}

/// A festive comparison line for the Home seasonal card.
struct SeasonalComparison: Equatable {
    let emoji: String
    let text: String
}

enum SeasonalEngine {

    /// The season active on `date`, if any. Windows: all of October (Halloween), Nov 15–30
    /// (Thanksgiving), all of December (Winter Holidays).
    static func activeSeason(on date: Date, calendar: Calendar = .current) -> Season? {
        let month = calendar.component(.month, from: date)
        let day   = calendar.component(.day, from: date)
        switch month {
        case 10:                 return .halloween
        case 11 where day >= 15: return .thanksgiving
        case 12:                 return .winterHoliday
        default:                 return nil
        }
    }

    // Reference weights/lengths for the absurd conversions (SI).
    private static let turkeyKg      = 7.0      // an average roast turkey
    private static let pumpkinKg     = 4.0      // a carving pumpkin
    private static let candyCaneM    = 0.15     // a standard candy cane, laid flat

    /// A seasonal comparison derived from the user's SI totals, or nil when no season is active
    /// or the relevant total is zero.
    static func comparison(
        for season: Season,
        totalWeightKg: Double,
        totalDistanceKm: Double
    ) -> SeasonalComparison? {
        switch season {
        case .thanksgiving:
            let turkeys = Int((totalWeightKg / turkeyKg).rounded())
            guard turkeys > 0 else { return nil }
            return SeasonalComparison(
                emoji: "🦃",
                text: "You've hoisted \(turkeys.formatted()) roast turkey\(turkeys == 1 ? "" : "s") this season!"
            )
        case .halloween:
            let pumpkins = Int((totalWeightKg / pumpkinKg).rounded())
            guard pumpkins > 0 else { return nil }
            return SeasonalComparison(
                emoji: "🎃",
                text: "That's \(pumpkins.formatted()) carving pumpkin\(pumpkins == 1 ? "" : "s") lifted — spooky strong!"
            )
        case .winterHoliday:
            let canes = Int((totalDistanceKm * 1000 / candyCaneM).rounded())
            guard canes > 0 else { return nil }
            return SeasonalComparison(
                emoji: "🍬",
                text: "That's \(canes.formatted()) candy canes laid end to end!"
            )
        }
    }

    /// Convenience: the active season's comparison for the given totals on `date`, or nil.
    static func currentComparison(
        on date: Date,
        totalWeightKg: Double,
        totalDistanceKm: Double,
        calendar: Calendar = .current
    ) -> (season: Season, comparison: SeasonalComparison)? {
        guard let season = activeSeason(on: date, calendar: calendar),
              let comparison = comparison(for: season, totalWeightKg: totalWeightKg, totalDistanceKm: totalDistanceKm)
        else { return nil }
        return (season, comparison)
    }
}
