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
    // Short noun phrase for the Home ticker: "You're X% of [ticker]"
    let ticker: [Theme: String]

    func getEmoji(for theme: Theme) -> String {
        emoji[theme] ?? "🎯"
    }

    func getComparison(for theme: Theme) -> String {
        comparisonText[theme] ?? "Great work!"
    }

    func getTicker(for theme: Theme) -> String {
        ticker[theme] ?? "your next goal"
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
            ],
            ticker: [
                .animals: "a giraffe parade",
                .cities: "18 NYC blocks",
                .landmarks: "4 Eiffel Towers"
            ]
        ),
        Milestone(
            id: "D1b", threshold: 2.5, unit: .miles,
            title: "You've run 2.5 miles!",
            emoji: [.animals: "🐱", .cities: "🌳", .landmarks: "🗽"],
            comparisonText: [
                .animals: "That's 450 house cats laid nose-to-tail!",
                .cities: "That's halfway across Central Park!",
                .landmarks: "That's the Statue of Liberty, stacked 25 times!"
            ],
            ticker: [
                .animals: "a cat parade",
                .cities: "half of Central Park",
                .landmarks: "25 Statues of Liberty"
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
            ],
            ticker: [
                .animals: "2 blue whales",
                .cities: "Central Park",
                .landmarks: "the Golden Gate Bridge"
            ]
        ),
        Milestone(
            id: "D2b", threshold: 10.0, unit: .miles,
            title: "You've run 10 miles!",
            emoji: [.animals: "🦅", .cities: "✈️", .landmarks: "🏜️"],
            comparisonText: [
                .animals: "That's a bald eagle's full afternoon patrol route!",
                .cities: "That's from downtown Manhattan to JFK airport!",
                .landmarks: "That's crossing the Grand Canyon rim-to-rim, 2.5 times!"
            ],
            ticker: [
                .animals: "an eagle's patrol route",
                .cities: "the Manhattan-to-JFK trip",
                .landmarks: "2.5 Grand Canyon crossings"
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
            ],
            ticker: [
                .animals: "a half marathon",
                .cities: "Manhattan island",
                .landmarks: "5 Vegas Strips"
            ]
        ),
        Milestone(
            id: "D3b", threshold: 17.5, unit: .miles,
            title: "You've run 17.5 miles!",
            emoji: [.animals: "🦁", .cities: "🌆", .landmarks: "🌸"],
            comparisonText: [
                .animals: "That's the daily hunting range of a mountain lion!",
                .cities: "That's from downtown LA to Santa Monica and back, twice!",
                .landmarks: "That's along the full Champs-Élysées, 45 times!"
            ],
            ticker: [
                .animals: "a mountain lion's daily hunt",
                .cities: "LA-to-Santa Monica laps",
                .landmarks: "45 Champs-Élysées strolls"
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
            ],
            ticker: [
                .animals: "a full marathon",
                .cities: "Austin to Round Rock",
                .landmarks: "the Great Wall section"
            ]
        ),
        Milestone(
            id: "D4b", threshold: 35.0, unit: .miles,
            title: "You've run 35 miles!",
            emoji: [.animals: "🐺", .cities: "🏙️", .landmarks: "🛤️"],
            comparisonText: [
                .animals: "That's the nightly roaming distance of a timber wolf!",
                .cities: "That's from Philadelphia to New York City!",
                .landmarks: "That's the Hudson River Greenway, 10 times over!"
            ],
            ticker: [
                .animals: "a wolf's nightly hunt",
                .cities: "the Philly-to-NYC trip",
                .landmarks: "10 Hudson River Greenways"
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
            ],
            ticker: [
                .animals: "a wildebeest migration",
                .cities: "Austin to San Antonio",
                .landmarks: "an Appalachian Trail day"
            ]
        ),
        Milestone(
            id: "D5b", threshold: 75.0, unit: .miles,
            title: "You've run 75 miles!",
            emoji: [.animals: "🐬", .cities: "🚂", .landmarks: "🌊"],
            comparisonText: [
                .animals: "That's a bottlenose dolphin's daily swim!",
                .cities: "That's from New York City to Philadelphia!",
                .landmarks: "That's crossing the English Channel, 3 times!"
            ],
            ticker: [
                .animals: "a dolphin's daily swim",
                .cities: "the NYC-to-Philly trip",
                .landmarks: "3 English Channel crossings"
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
            ],
            ticker: [
                .animals: "a Monarch butterfly's day",
                .cities: "Austin to Houston",
                .landmarks: "4 English Channels"
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
            ],
            ticker: [
                .animals: "a male lion",
                .cities: "a Smart Car",
                .landmarks: "a church bell"
            ]
        ),
        Milestone(
            id: "W1b", threshold: 1000, unit: .pounds,
            title: "You've lifted 1,000 lbs!",
            emoji: [.animals: "🐻", .cities: "🚗", .landmarks: "🔔"],
            comparisonText: [
                .animals: "That's a full-grown grizzly bear — and he skipped leg day!",
                .cities: "That's the weight of a Honda Civic!",
                .landmarks: "That's two Liberty Bells!"
            ],
            ticker: [
                .animals: "a grizzly bear",
                .cities: "a Honda Civic",
                .landmarks: "2 Liberty Bells"
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
            ],
            ticker: [
                .animals: "a hippo",
                .cities: "a Mini Cooper",
                .landmarks: "Liberty's torch"
            ]
        ),
        Milestone(
            id: "W2b", threshold: 5000, unit: .pounds,
            title: "You've lifted 5,000 lbs!",
            emoji: [.animals: "🦏", .cities: "🛻", .landmarks: "🚌"],
            comparisonText: [
                .animals: "That's heavier than a white rhinoceros!",
                .cities: "That's a fully-loaded Ford F-150!",
                .landmarks: "That's the weight of a school bus engine!"
            ],
            ticker: [
                .animals: "a white rhinoceros",
                .cities: "a loaded F-150",
                .landmarks: "a school bus engine"
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
            ],
            ticker: [
                .animals: "an elephant",
                .cities: "a transit bus",
                .landmarks: "a Liberty Bell replica"
            ]
        ),
        Milestone(
            id: "W3b", threshold: 15000, unit: .pounds,
            title: "You've lifted 15,000 lbs!",
            emoji: [.animals: "🦒", .cities: "🚌", .landmarks: "🗿"],
            comparisonText: [
                .animals: "That's 3 fully grown giraffes — one for each leg day!",
                .cities: "That's an empty city transit bus!",
                .landmarks: "That's the weight of a Stonehenge trilithon!"
            ],
            ticker: [
                .animals: "3 giraffes",
                .cities: "an empty city bus",
                .landmarks: "a Stonehenge trilithon"
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
            ],
            ticker: [
                .animals: "a T-Rex skull",
                .cities: "a fire truck",
                .landmarks: "a Berlin Wall section"
            ]
        ),
        Milestone(
            id: "W4b", threshold: 35000, unit: .pounds,
            title: "You've lifted 35,000 lbs!",
            emoji: [.animals: "🐋", .cities: "🚌", .landmarks: "✈️"],
            comparisonText: [
                .animals: "That's a young humpback whale, fresh out of college!",
                .cities: "That's a school bus packed with students!",
                .landmarks: "That's the Wright Brothers' first airplane, 525 times over!"
            ],
            ticker: [
                .animals: "a college-age humpback",
                .cities: "a loaded school bus",
                .landmarks: "525 Wright Flyers"
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
            ],
            ticker: [
                .animals: "a humpback whale",
                .cities: "a loaded semi-truck",
                .landmarks: "a Stonehenge section"
            ]
        ),
        Milestone(
            id: "W5b", threshold: 75000, unit: .pounds,
            title: "You've lifted 75,000 lbs!",
            emoji: [.animals: "🐳", .cities: "🚛", .landmarks: "🚀"],
            comparisonText: [
                .animals: "That's the weight of an average sperm whale!",
                .cities: "That's a fully loaded 18-wheel tractor-trailer!",
                .landmarks: "That's 3 Space Shuttle solid rocket booster casings!"
            ],
            ticker: [
                .animals: "a sperm whale",
                .cities: "an 18-wheeler",
                .landmarks: "3 rocket booster casings"
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
            ],
            ticker: [
                .animals: "a blue whale's heart",
                .cities: "a shuttle main engine",
                .landmarks: "a pyramid capstone"
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
