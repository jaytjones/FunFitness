//
//  Challenge.swift
//  FunFitness
//
//  Monthly challenges (v2.2). Each challenge is a locally-evaluated, badge-rewarded goal in
//  FunFitness's own voice ("Lift a Hippo March"). Challenges are YEAR-AGNOSTIC: one is active in
//  its calendar month every year, so completing it is a fresh badge each year — the renewable
//  content calendar. Progress is the total effective value of the challenge's activity type logged
//  within that month; the challenge completes when it reaches `targetSI`.
//

import Foundation

struct Challenge: Identifiable, Equatable {
    let id: String            // stable slug, e.g. "hippo-march"
    let month: Int            // calendar month it's active (1 = Jan … 12 = Dec)
    let title: String         // FunFitness-voice name shown on the card
    let blurb: String         // what to do this month
    let emoji: String
    let type: ActivityType
    let targetSI: Double      // goal in stored SI units (km / kg / minutes / reps)
}

enum ChallengeCatalog {

    // One challenge per calendar month, cycling through all four activity types. Targets are a
    // month's stretch, expressed in SI (km / kg / minutes / reps). Voice stays playful.
    static let all: [Challenge] = [
        Challenge(id: "frosty-mile-chase",  month: 1,  title: "Frosty Mile Chase",
                  blurb: "Outrun the cold — cover 25 miles before the thaw.",
                  emoji: "❄️", type: .distance, targetSI: 40.234),      // 25 mi
        Challenge(id: "heart-pumper",       month: 2,  title: "Heart-Pumper February",
                  blurb: "Show your heart some love with 5 hours of movement.",
                  emoji: "💗", type: .duration, targetSI: 300),          // 5 hr
        Challenge(id: "hippo-march",        month: 3,  title: "Lift a Hippo March",
                  blurb: "Hoist a whole hippo this month — 1,500 kg of lifting.",
                  emoji: "🦛", type: .weight,   targetSI: 1500),
        Challenge(id: "april-showers",      month: 4,  title: "April Showers Steps",
                  blurb: "Dance between the raindrops for 40 miles.",
                  emoji: "🌧️", type: .distance, targetSI: 64.374),      // 40 mi
        Challenge(id: "mighty-muscles",     month: 5,  title: "Mighty Muscles May",
                  blurb: "Crank out 1,000 reps and flex like you mean it.",
                  emoji: "💪", type: .reps,     targetSI: 1000),
        Challenge(id: "marathon-june",      month: 6,  title: "Marathon June",
                  blurb: "Log a full marathon's distance — 26.2 miles — your way.",
                  emoji: "🏃", type: .distance, targetSI: 42.195),
        Challenge(id: "hot-streak",         month: 7,  title: "Hot Streak July",
                  blurb: "Beat the heat with 8 hours of sweat.",
                  emoji: "☀️", type: .duration, targetSI: 480),          // 8 hr
        Challenge(id: "iron-august",        month: 8,  title: "Iron August",
                  blurb: "Move 5,000 kg of iron before summer's out.",
                  emoji: "🏋️", type: .weight,   targetSI: 5000),
        Challenge(id: "rep-rally",          month: 9,  title: "Rep Rally September",
                  blurb: "Rally the reps — 1,500 of them this month.",
                  emoji: "🤸", type: .reps,     targetSI: 1500),
        Challenge(id: "spooky-distance",    month: 10, title: "Spooky Distance October",
                  blurb: "Rack up a spooky 66.6 km before the pumpkins rot.",
                  emoji: "🎃", type: .distance, targetSI: 66.6),
        Challenge(id: "gobble-wobble",      month: 11, title: "Gobble 'Til You Wobble",
                  blurb: "Earn the feast with 10 hours of moving.",
                  emoji: "🦃", type: .duration, targetSI: 600),          // 10 hr
        Challenge(id: "deck-the-reps",      month: 12, title: "Deck the Reps December",
                  blurb: "Deck the halls with 2,500 festive reps.",
                  emoji: "🎄", type: .reps,     targetSI: 2500),
    ]

    static let byId: [String: Challenge] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func challenge(id: String) -> Challenge? { byId[id] }
}

/// Pure, deterministic evaluation of monthly-challenge progress. Every function takes an explicit
/// reference date so behavior is testable and never depends on the wall clock.
enum ChallengeEngine {

    /// Composite badge key: "<challengeId>#<year>", so each year's occurrence is its own badge.
    static func unlockKey(id: String, year: Int) -> String { "\(id)#\(year)" }

    /// The challenge active for the month containing `date`, if any.
    static func activeChallenge(on date: Date, calendar: Calendar = .current) -> Challenge? {
        let month = calendar.component(.month, from: date)
        return ChallengeCatalog.all.first { $0.month == month }
    }

    /// Total effective value of the challenge's type logged in the same calendar month+year as
    /// `date`. Weight entries multiply by reps via `effectiveValue`; other types accumulate value.
    static func progress(
        for challenge: Challenge,
        in activities: [ActivityLog],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double {
        let month = calendar.component(.month, from: date)
        let year  = calendar.component(.year, from: date)
        return activities.lazy
            .filter { $0.activityType == challenge.type }
            .filter {
                calendar.component(.month, from: $0.loggedAt) == month &&
                calendar.component(.year,  from: $0.loggedAt) == year
            }
            .reduce(0) { $0 + $1.effectiveValue }
    }

    static func isComplete(
        _ challenge: Challenge,
        in activities: [ActivityLog],
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        progress(for: challenge, in: activities, on: date, calendar: calendar) >= challenge.targetSI
    }

    /// Fractional progress in [0, 1] toward the target.
    static func fractionComplete(
        _ challenge: Challenge,
        in activities: [ActivityLog],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double {
        guard challenge.targetSI > 0 else { return 0 }
        let p = progress(for: challenge, in: activities, on: date, calendar: calendar)
        return min(max(p / challenge.targetSI, 0), 1)
    }
}
