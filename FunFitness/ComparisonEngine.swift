//
//  ComparisonEngine.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import Foundation

enum Theme: String, CaseIterable {
    case animals
    case cities
    case landmarks

    var displayName: String {
        switch self {
        case .animals:   return "Animals"
        case .cities:    return "Cities"
        case .landmarks: return "Landmarks"
        }
    }
}

enum ActivityUnit {
    case miles
    case pounds
}

struct Milestone: Identifiable {
    let id: String
    let threshold: Double
    let unit: ActivityUnit
    // title is identical across all themes — stored once
    let title: String
    let emoji: [Theme: String]
    let comparisonText: [Theme: String]

    func getEmoji(for theme: Theme) -> String {
        emoji[theme] ?? "🎯"
    }

    func getComparison(for theme: Theme) -> String {
        comparisonText[theme] ?? "Great work!"
    }
}

struct ComparisonEngine {

    // MARK: - Distance Milestones (sorted ascending — required by progressToNextMilestone)

    static let distanceMilestones: [Milestone] = [
        Milestone(
            id: "D1", threshold: 1.0, unit: .miles,
            title: "You've run 1 mile!",
            emoji: [.animals: "🦒", .cities: "🏙", .landmarks: "🗼"],
            comparisonText: [
                .animals: "That's like walking past 270 giraffes stacked head to tail!",
                .cities: "That's the distance across 18 NYC blocks!",
                .landmarks: "That's 4 Eiffel Towers laid flat!"
            ]
        ),
        Milestone(
            id: "D2", threshold: 5.0, unit: .miles,
            title: "You've run 5 miles!",
            emoji: [.animals: "🐳", .cities: "🌳", .landmarks: "🌉"],
            comparisonText: [
                .animals: "That's the length of 2 blue whales!",
                .cities: "That's a full lap around Central Park!",
                .landmarks: "That's across the Golden Gate Bridge and back!"
            ]
        ),
        Milestone(
            id: "D3", threshold: 13.1, unit: .miles,
            title: "Half Marathon Complete!",
            emoji: [.animals: "🏃", .cities: "🏙", .landmarks: "🎰"],
            comparisonText: [
                .animals: "You've completed a half marathon distance!",
                .cities: "That's the length of Manhattan island!",
                .landmarks: "That's half the Las Vegas Strip, 5 times over!"
            ]
        ),
        Milestone(
            id: "D4", threshold: 26.2, unit: .miles,
            title: "Full Marathon Complete!",
            emoji: [.animals: "🏅", .cities: "🤖", .landmarks: "🇨🇳"],
            comparisonText: [
                .animals: "You've completed a full marathon distance!",
                .cities: "That's from Austin to Round Rock!",
                .landmarks: "That's a full section of the Great Wall at Badaling!"
            ]
        ),
        Milestone(
            id: "D5", threshold: 50.0, unit: .miles,
            title: "You've run 50 miles!",
            emoji: [.animals: "🐃", .cities: "🚗", .landmarks: "🧗"],
            comparisonText: [
                .animals: "That's the migration distance of 1 wildebeest!",
                .cities: "That's from Austin to San Antonio!",
                .landmarks: "That's day 3 on the Appalachian Trail!"
            ]
        ),
        Milestone(
            id: "D6", threshold: 100.0, unit: .miles,
            title: "You've run 100 miles!",
            emoji: [.animals: "🦋", .cities: "🏙", .landmarks: "🌊"],
            comparisonText: [
                .animals: "That's a Monarch butterfly's daily flight!",
                .cities: "That's from Austin to Houston!",
                .landmarks: "That's across the English Channel 4 times!"
            ]
        ),
    ]

    // MARK: - Weight Milestones (sorted ascending)

    static let weightMilestones: [Milestone] = [
        Milestone(
            id: "W1", threshold: 500, unit: .pounds,
            title: "You've lifted 500 lbs!",
            emoji: [.animals: "🦁", .cities: "🚗", .landmarks: "🔔"],
            comparisonText: [
                .animals: "That's the weight of a male lion!",
                .cities: "That's the weight of a Smart Car!",
                .landmarks: "That's the weight of a church bell!"
            ]
        ),
        Milestone(
            id: "W2", threshold: 2500, unit: .pounds,
            title: "You've lifted 2,500 lbs!",
            emoji: [.animals: "🦛", .cities: "🚗", .landmarks: "🗽"],
            comparisonText: [
                .animals: "That's the weight of a hippo!",
                .cities: "That's the weight of a Mini Cooper!",
                .landmarks: "That's the weight of the Statue of Liberty's torch!"
            ]
        ),
        Milestone(
            id: "W3", threshold: 10000, unit: .pounds,
            title: "You've lifted 10,000 lbs!",
            emoji: [.animals: "🐘", .cities: "🚌", .landmarks: "🔔"],
            comparisonText: [
                .animals: "That's the weight of an elephant!",
                .cities: "That's the weight of a city transit bus!",
                .landmarks: "That's the weight of a Liberty Bell replica!"
            ]
        ),
        Milestone(
            id: "W4", threshold: 25000, unit: .pounds,
            title: "You've lifted 25,000 lbs!",
            emoji: [.animals: "🦴", .cities: "🚒", .landmarks: "🧱"],
            comparisonText: [
                .animals: "That's the weight of a T-Rex skull!",
                .cities: "That's the weight of a fire truck!",
                .landmarks: "That's the weight of a section of the Berlin Wall!"
            ]
        ),
        Milestone(
            id: "W5", threshold: 50000, unit: .pounds,
            title: "You've lifted 50,000 lbs!",
            emoji: [.animals: "🐳", .cities: "🚚", .landmarks: "🗿"],
            comparisonText: [
                .animals: "That's the weight of a humpback whale!",
                .cities: "That's the weight of a loaded semi-truck!",
                .landmarks: "That's the weight of a section of Stonehenge!"
            ]
        ),
        Milestone(
            id: "W6", threshold: 100000, unit: .pounds,
            title: "You've lifted 100,000 lbs!",
            emoji: [.animals: "💙", .cities: "🚀", .landmarks: "🛕"],
            comparisonText: [
                .animals: "That's the weight of a blue whale's heart!",
                .cities: "That's the weight of a space shuttle main engine!",
                .landmarks: "That's the weight of a Pyramid capstone block!"
            ]
        ),
    ]

    // MARK: - All Milestones

    static let allMilestones: [Milestone] = distanceMilestones + weightMilestones

    // O(1) lookup by ID
    static let byId: [String: Milestone] = Dictionary(
        uniqueKeysWithValues: allMilestones.map { ($0.id, $0) }
    )

    // MARK: - Helpers

    static func nextMilestone(for type: ActivityType, currentTotal: Double) -> Milestone? {
        let milestones = type == .distance ? distanceMilestones : weightMilestones
        return milestones.first { $0.threshold > currentTotal }
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
        let milestones = type == .distance ? distanceMilestones : weightMilestones
        return milestones.filter { milestone in
            milestone.threshold > previousTotal &&
            milestone.threshold <= newTotal &&
            !unlockedIds.contains(milestone.id)
        }.sorted { $0.threshold < $1.threshold }
    }
}
