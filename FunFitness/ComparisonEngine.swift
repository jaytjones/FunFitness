//
//  ComparisonEngine.swift
//  FunFitness
//

import Foundation

// Stored-unit tags for milestone thresholds (SI since v1.2).
enum ActivityUnit: Equatable, Sendable {
    case kilometers
    case kilograms
}

// A milestone definition — theme-agnostic (v2.2). The silly per-theme copy lives in the
// pack-keyed content store below so a new theme pack is added as one content block rather than
// by editing every milestone.
struct Milestone: Identifiable {
    let id: String
    let threshold: Double       // km for distance; kg for weight
    let unit: ActivityUnit
    let title: String

    func getEmoji(for pack: ThemePack) -> String {
        ComparisonEngine.content(packId: pack.id, milestoneId: id)?.emoji ?? "🎯"
    }
    func getComparison(for pack: ThemePack) -> String {
        ComparisonEngine.content(packId: pack.id, milestoneId: id)?.comparison ?? "Great work!"
    }
    func getTicker(for pack: ThemePack) -> String {
        ComparisonEngine.content(packId: pack.id, milestoneId: id)?.ticker ?? "your next goal"
    }
}

// Per-pack, per-milestone silly copy.
struct MilestoneContent {
    let emoji: String
    let comparison: String   // full sentence shown on the milestone/achievement card
    let ticker: String       // short noun phrase for the Home ticker: "You're X% of [ticker]"
}

struct ComparisonEngine {

    // MARK: - Distance Milestones (sorted ascending; thresholds in km)

    static let distanceMilestones: [Milestone] = [
        Milestone(id: "D1",  threshold: 1.60934,  unit: .kilometers, title: "You've run 1 mile!"),
        Milestone(id: "D1b", threshold: 4.02336,  unit: .kilometers, title: "You've run 2.5 miles!"),
        Milestone(id: "D2",  threshold: 8.04672,  unit: .kilometers, title: "You've run 5 miles!"),
        Milestone(id: "D2b", threshold: 16.0934,  unit: .kilometers, title: "You've run 10 miles!"),
        Milestone(id: "D3",  threshold: 21.0975,  unit: .kilometers, title: "Half Marathon Complete!"),
        Milestone(id: "D3b", threshold: 28.1635,  unit: .kilometers, title: "You've run 17.5 miles!"),
        Milestone(id: "D4",  threshold: 42.195,   unit: .kilometers, title: "Full Marathon Complete!"),
        Milestone(id: "D4b", threshold: 56.3270,  unit: .kilometers, title: "You've run 35 miles!"),
        Milestone(id: "D5",  threshold: 80.4672,  unit: .kilometers, title: "You've run 50 miles!"),
        Milestone(id: "D5b", threshold: 120.701,  unit: .kilometers, title: "You've run 75 miles!"),
        Milestone(id: "D6",  threshold: 160.934,  unit: .kilometers, title: "You've run 100 miles!"),
    ]

    // MARK: - Weight Milestones (sorted ascending; thresholds in kg)

    static let weightMilestones: [Milestone] = [
        Milestone(id: "W1",  threshold: 226.796,  unit: .kilograms, title: "You've lifted 500 lbs!"),
        Milestone(id: "W1b", threshold: 453.592,  unit: .kilograms, title: "You've lifted 1,000 lbs!"),
        Milestone(id: "W2",  threshold: 1133.98,  unit: .kilograms, title: "You've lifted 2,500 lbs!"),
        Milestone(id: "W2b", threshold: 2267.96,  unit: .kilograms, title: "You've lifted 5,000 lbs!"),
        Milestone(id: "W3",  threshold: 4535.92,  unit: .kilograms, title: "You've lifted 10,000 lbs!"),
        Milestone(id: "W3b", threshold: 6803.89,  unit: .kilograms, title: "You've lifted 15,000 lbs!"),
        Milestone(id: "W4",  threshold: 11339.8,  unit: .kilograms, title: "You've lifted 25,000 lbs!"),
        Milestone(id: "W4b", threshold: 15875.7,  unit: .kilograms, title: "You've lifted 35,000 lbs!"),
        Milestone(id: "W5",  threshold: 22679.6,  unit: .kilograms, title: "You've lifted 50,000 lbs!"),
        Milestone(id: "W5b", threshold: 34019.4,  unit: .kilograms, title: "You've lifted 75,000 lbs!"),
        Milestone(id: "W6",  threshold: 45359.2,  unit: .kilograms, title: "You've lifted 100,000 lbs!"),
    ]

    // MARK: - All Milestones

    static let allMilestones: [Milestone] = distanceMilestones + weightMilestones

    static let byId: [String: Milestone] = Dictionary(
        uniqueKeysWithValues: allMilestones.map { ($0.id, $0) }
    )

    // MARK: - Theme pack content
    // Keyed [packId: [milestoneId: MilestoneContent]]. Each pack is one self-contained block,
    // so adding a pack means adding a block here (Segment 4) — no milestone edits.

    static let content: [String: [String: MilestoneContent]] = [
        ThemePackCatalog.animals.id:   animalsContent,
        ThemePackCatalog.cities.id:    citiesContent,
        ThemePackCatalog.landmarks.id: landmarksContent,
    ]

    static func content(packId: String, milestoneId: String) -> MilestoneContent? {
        content[packId]?[milestoneId]
    }

    private static let animalsContent: [String: MilestoneContent] = [
        "D1":  MilestoneContent(emoji: "🦒", comparison: "That's like walking past 270 giraffes stacked head to tail!", ticker: "a giraffe parade"),
        "D1b": MilestoneContent(emoji: "🐱", comparison: "That's 450 house cats laid nose-to-tail!", ticker: "a cat parade"),
        "D2":  MilestoneContent(emoji: "🐳", comparison: "That's the length of 2 blue whales!", ticker: "2 blue whales"),
        "D2b": MilestoneContent(emoji: "🦅", comparison: "That's a bald eagle's full afternoon patrol route!", ticker: "an eagle's patrol route"),
        "D3":  MilestoneContent(emoji: "🏃", comparison: "You've completed a half marathon distance!", ticker: "a half marathon"),
        "D3b": MilestoneContent(emoji: "🦁", comparison: "That's the daily hunting range of a mountain lion!", ticker: "a mountain lion's daily hunt"),
        "D4":  MilestoneContent(emoji: "🏅", comparison: "You've completed a full marathon distance!", ticker: "a full marathon"),
        "D4b": MilestoneContent(emoji: "🐺", comparison: "That's the nightly roaming distance of a timber wolf!", ticker: "a wolf's nightly hunt"),
        "D5":  MilestoneContent(emoji: "🐃", comparison: "That's the migration distance of 1 wildebeest!", ticker: "a wildebeest migration"),
        "D5b": MilestoneContent(emoji: "🐬", comparison: "That's a bottlenose dolphin's daily swim!", ticker: "a dolphin's daily swim"),
        "D6":  MilestoneContent(emoji: "🦋", comparison: "That's a Monarch butterfly's daily flight!", ticker: "a Monarch butterfly's day"),
        "W1":  MilestoneContent(emoji: "🦁", comparison: "That's the weight of a male lion!", ticker: "a male lion"),
        "W1b": MilestoneContent(emoji: "🐻", comparison: "That's a full-grown grizzly bear — and he skipped leg day!", ticker: "a grizzly bear"),
        "W2":  MilestoneContent(emoji: "🦛", comparison: "That's the weight of a hippo!", ticker: "a hippo"),
        "W2b": MilestoneContent(emoji: "🦏", comparison: "That's heavier than a white rhinoceros!", ticker: "a white rhinoceros"),
        "W3":  MilestoneContent(emoji: "🐘", comparison: "That's the weight of an elephant!", ticker: "an elephant"),
        "W3b": MilestoneContent(emoji: "🦒", comparison: "That's 3 fully grown giraffes — one for each leg day!", ticker: "3 giraffes"),
        "W4":  MilestoneContent(emoji: "🦴", comparison: "That's the weight of a T-Rex skull!", ticker: "a T-Rex skull"),
        "W4b": MilestoneContent(emoji: "🐋", comparison: "That's a young humpback whale, fresh out of college!", ticker: "a college-age humpback"),
        "W5":  MilestoneContent(emoji: "🐳", comparison: "That's the weight of a humpback whale!", ticker: "a humpback whale"),
        "W5b": MilestoneContent(emoji: "🐳", comparison: "That's the weight of an average sperm whale!", ticker: "a sperm whale"),
        "W6":  MilestoneContent(emoji: "💙", comparison: "That's the weight of a blue whale's heart!", ticker: "a blue whale's heart"),
    ]

    private static let citiesContent: [String: MilestoneContent] = [
        "D1":  MilestoneContent(emoji: "🏙", comparison: "That's the distance across 18 NYC blocks!", ticker: "18 NYC blocks"),
        "D1b": MilestoneContent(emoji: "🌳", comparison: "That's halfway across Central Park!", ticker: "half of Central Park"),
        "D2":  MilestoneContent(emoji: "🌳", comparison: "That's a full lap around Central Park!", ticker: "Central Park"),
        "D2b": MilestoneContent(emoji: "✈️", comparison: "That's from downtown Manhattan to JFK airport!", ticker: "the Manhattan-to-JFK trip"),
        "D3":  MilestoneContent(emoji: "🏙", comparison: "That's the length of Manhattan island!", ticker: "Manhattan island"),
        "D3b": MilestoneContent(emoji: "🌆", comparison: "That's from downtown LA to Santa Monica and back, twice!", ticker: "LA-to-Santa Monica laps"),
        "D4":  MilestoneContent(emoji: "🤖", comparison: "That's from Austin to Round Rock!", ticker: "Austin to Round Rock"),
        "D4b": MilestoneContent(emoji: "🏙️", comparison: "That's from Philadelphia to New York City!", ticker: "the Philly-to-NYC trip"),
        "D5":  MilestoneContent(emoji: "🚗", comparison: "That's from Austin to San Antonio!", ticker: "Austin to San Antonio"),
        "D5b": MilestoneContent(emoji: "🚂", comparison: "That's from New York City to Philadelphia!", ticker: "the NYC-to-Philly trip"),
        "D6":  MilestoneContent(emoji: "🏙", comparison: "That's from Austin to Houston!", ticker: "Austin to Houston"),
        "W1":  MilestoneContent(emoji: "🚗", comparison: "That's the weight of a Smart Car!", ticker: "a Smart Car"),
        "W1b": MilestoneContent(emoji: "🚗", comparison: "That's the weight of a Honda Civic!", ticker: "a Honda Civic"),
        "W2":  MilestoneContent(emoji: "🚗", comparison: "That's the weight of a Mini Cooper!", ticker: "a Mini Cooper"),
        "W2b": MilestoneContent(emoji: "🛻", comparison: "That's a fully-loaded Ford F-150!", ticker: "a loaded F-150"),
        "W3":  MilestoneContent(emoji: "🚌", comparison: "That's the weight of a city transit bus!", ticker: "a transit bus"),
        "W3b": MilestoneContent(emoji: "🚌", comparison: "That's an empty city transit bus!", ticker: "an empty city bus"),
        "W4":  MilestoneContent(emoji: "🚒", comparison: "That's the weight of a fire truck!", ticker: "a fire truck"),
        "W4b": MilestoneContent(emoji: "🚌", comparison: "That's a school bus packed with students!", ticker: "a loaded school bus"),
        "W5":  MilestoneContent(emoji: "🚚", comparison: "That's the weight of a loaded semi-truck!", ticker: "a loaded semi-truck"),
        "W5b": MilestoneContent(emoji: "🚛", comparison: "That's a fully loaded 18-wheel tractor-trailer!", ticker: "an 18-wheeler"),
        "W6":  MilestoneContent(emoji: "🚀", comparison: "That's the weight of a space shuttle main engine!", ticker: "a shuttle main engine"),
    ]

    private static let landmarksContent: [String: MilestoneContent] = [
        "D1":  MilestoneContent(emoji: "🗼", comparison: "That's 4 Eiffel Towers laid flat!", ticker: "4 Eiffel Towers"),
        "D1b": MilestoneContent(emoji: "🗽", comparison: "That's the Statue of Liberty, stacked 25 times!", ticker: "25 Statues of Liberty"),
        "D2":  MilestoneContent(emoji: "🌉", comparison: "That's across the Golden Gate Bridge and back!", ticker: "the Golden Gate Bridge"),
        "D2b": MilestoneContent(emoji: "🏜️", comparison: "That's crossing the Grand Canyon rim-to-rim, 2.5 times!", ticker: "2.5 Grand Canyon crossings"),
        "D3":  MilestoneContent(emoji: "🎰", comparison: "That's half the Las Vegas Strip, 5 times over!", ticker: "5 Vegas Strips"),
        "D3b": MilestoneContent(emoji: "🌸", comparison: "That's along the full Champs-Élysées, 45 times!", ticker: "45 Champs-Élysées strolls"),
        "D4":  MilestoneContent(emoji: "🇨🇳", comparison: "That's a full section of the Great Wall at Badaling!", ticker: "the Great Wall section"),
        "D4b": MilestoneContent(emoji: "🛤️", comparison: "That's the Hudson River Greenway, 10 times over!", ticker: "10 Hudson River Greenways"),
        "D5":  MilestoneContent(emoji: "🧗", comparison: "That's day 3 on the Appalachian Trail!", ticker: "an Appalachian Trail day"),
        "D5b": MilestoneContent(emoji: "🌊", comparison: "That's crossing the English Channel, 3 times!", ticker: "3 English Channel crossings"),
        "D6":  MilestoneContent(emoji: "🌊", comparison: "That's across the English Channel 4 times!", ticker: "4 English Channels"),
        "W1":  MilestoneContent(emoji: "🔔", comparison: "That's the weight of a church bell!", ticker: "a church bell"),
        "W1b": MilestoneContent(emoji: "🔔", comparison: "That's two Liberty Bells!", ticker: "2 Liberty Bells"),
        "W2":  MilestoneContent(emoji: "🗽", comparison: "That's the weight of the Statue of Liberty's torch!", ticker: "Liberty's torch"),
        "W2b": MilestoneContent(emoji: "🚌", comparison: "That's the weight of a school bus engine!", ticker: "a school bus engine"),
        "W3":  MilestoneContent(emoji: "🔔", comparison: "That's the weight of a Liberty Bell replica!", ticker: "a Liberty Bell replica"),
        "W3b": MilestoneContent(emoji: "🗿", comparison: "That's the weight of a Stonehenge trilithon!", ticker: "a Stonehenge trilithon"),
        "W4":  MilestoneContent(emoji: "🧱", comparison: "That's the weight of a section of the Berlin Wall!", ticker: "a Berlin Wall section"),
        "W4b": MilestoneContent(emoji: "✈️", comparison: "That's the Wright Brothers' first airplane, 525 times over!", ticker: "525 Wright Flyers"),
        "W5":  MilestoneContent(emoji: "🗿", comparison: "That's the weight of a section of Stonehenge!", ticker: "a Stonehenge section"),
        "W5b": MilestoneContent(emoji: "🚀", comparison: "That's 3 Space Shuttle solid rocket booster casings!", ticker: "3 rocket booster casings"),
        "W6":  MilestoneContent(emoji: "🛕", comparison: "That's the weight of a Pyramid capstone block!", ticker: "a pyramid capstone"),
    ]

    // MARK: - Helpers

    /// The milestone array backing a given activity type. One switch that every type-specific
    /// lookup routes through, so a new activity type must be handled here (and only here). (v2.2)
    static func milestones(for type: ActivityType) -> [Milestone] {
        switch type {
        case .distance: return distanceMilestones
        case .weight:   return weightMilestones
        }
    }

    static func nextMilestone(for type: ActivityType, currentTotal: Double) -> Milestone? {
        milestones(for: type).first { $0.threshold > currentTotal }
    }

    static func milestone(withId id: String) -> Milestone? {
        byId[id]
    }

    static func checkForNewMilestones(
        type: ActivityType,
        previousTotal: Double,
        newTotal: Double,
        unlockedIds: Set<String>
    ) -> [Milestone] {
        return milestones(for: type).filter { milestone in
            milestone.threshold > previousTotal &&
            milestone.threshold <= newTotal &&
            !unlockedIds.contains(milestone.id)
        }.sorted { $0.threshold < $1.threshold }
    }
}
