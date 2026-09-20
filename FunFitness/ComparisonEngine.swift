//
//  ComparisonEngine.swift
//  FunFitness
//

import Foundation

// Stored-unit tags for milestone thresholds (SI since v1.2).
enum ActivityUnit: Equatable, Sendable {
    case kilometers
    case kilograms
    case minutes      // v2.2 duration thresholds (total minutes)
    case reps         // v2.2 rep-count thresholds (total reps)
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

    // MARK: - Duration Milestones (sorted ascending; thresholds in total minutes) (v2.2)

    static let durationMilestones: [Milestone] = [
        Milestone(id: "T1", threshold: 30,   unit: .minutes, title: "30 Minutes Moving!"),
        Milestone(id: "T2", threshold: 60,   unit: .minutes, title: "1 Hour Logged!"),
        Milestone(id: "T3", threshold: 150,  unit: .minutes, title: "150 Minutes — WHO Weekly Goal!"),
        Milestone(id: "T4", threshold: 300,  unit: .minutes, title: "5 Hours In Motion!"),
        Milestone(id: "T5", threshold: 600,  unit: .minutes, title: "10 Hours of Effort!"),
        Milestone(id: "T6", threshold: 1200, unit: .minutes, title: "20 Hours Strong!"),
        Milestone(id: "T7", threshold: 3000, unit: .minutes, title: "50 Hours Committed!"),
        Milestone(id: "T8", threshold: 6000, unit: .minutes, title: "100 Hours — A Century of Time!"),
    ]

    // MARK: - Reps Milestones (sorted ascending; thresholds in total reps) (v2.2)

    static let repsMilestones: [Milestone] = [
        Milestone(id: "R1", threshold: 50,    unit: .reps, title: "50 Reps Done!"),
        Milestone(id: "R2", threshold: 100,   unit: .reps, title: "100 Reps Club!"),
        Milestone(id: "R3", threshold: 250,   unit: .reps, title: "250 Reps Strong!"),
        Milestone(id: "R4", threshold: 500,   unit: .reps, title: "500 Reps!"),
        Milestone(id: "R5", threshold: 1000,  unit: .reps, title: "1,000 Reps!"),
        Milestone(id: "R6", threshold: 2500,  unit: .reps, title: "2,500 Reps!"),
        Milestone(id: "R7", threshold: 5000,  unit: .reps, title: "5,000 Reps!"),
        Milestone(id: "R8", threshold: 10000, unit: .reps, title: "10,000 Reps — Legend!"),
    ]

    // MARK: - All Milestones

    static let allMilestones: [Milestone] =
        distanceMilestones + weightMilestones + durationMilestones + repsMilestones

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
        ThemePackCatalog.food.id:      foodContent,
        ThemePackCatalog.dinosaurs.id: dinosaursContent,
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
        "T1":  MilestoneContent(emoji: "🐆", comparison: "That's how long a cheetah rests between sprints!", ticker: "a cheetah's rest"),
        "T2":  MilestoneContent(emoji: "🦥", comparison: "That's a sloth's entire daily activity budget!", ticker: "a sloth's busy day"),
        "T3":  MilestoneContent(emoji: "🐘", comparison: "That's how long an elephant naps standing up!", ticker: "an elephant's nap"),
        "T4":  MilestoneContent(emoji: "🦁", comparison: "That's a lion's afternoon snooze — 5 hours flat!", ticker: "a lion's snooze"),
        "T5":  MilestoneContent(emoji: "🐨", comparison: "That's a koala's daily sleep — 10 hours of it!", ticker: "a koala's sleep"),
        "T6":  MilestoneContent(emoji: "🐻", comparison: "That's a hibernating bear's first day of winter!", ticker: "a bear's winter day"),
        "T7":  MilestoneContent(emoji: "🐋", comparison: "That's a gray whale migrating nonstop for 50 hours!", ticker: "a whale's migration leg"),
        "T8":  MilestoneContent(emoji: "🦅", comparison: "That's an albatross gliding for 100 hours straight!", ticker: "an albatross flight"),
        "R1":  MilestoneContent(emoji: "🦘", comparison: "That's 50 kangaroo hops across the outback!", ticker: "kangaroo hops"),
        "R2":  MilestoneContent(emoji: "🐇", comparison: "That's 100 bunny hops through the meadow!", ticker: "bunny hops"),
        "R3":  MilestoneContent(emoji: "🐝", comparison: "That's 250 waggle-dances from a busy bee!", ticker: "bee waggle-dances"),
        "R4":  MilestoneContent(emoji: "🐿️", comparison: "That's 500 acorns buried by an industrious squirrel!", ticker: "buried acorns"),
        "R5":  MilestoneContent(emoji: "🐦", comparison: "That's 1,000 pecks from a hungry woodpecker!", ticker: "woodpecker pecks"),
        "R6":  MilestoneContent(emoji: "🦗", comparison: "That's 2,500 chirps from a summer cricket!", ticker: "cricket chirps"),
        "R7":  MilestoneContent(emoji: "🐜", comparison: "That's 5,000 ants marching in a single line!", ticker: "marching ants"),
        "R8":  MilestoneContent(emoji: "🐝", comparison: "That's a whole hive's worth of bees — 10,000 strong!", ticker: "a beehive"),
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
        "T1":  MilestoneContent(emoji: "🚕", comparison: "That's a cross-town cab ride in Manhattan traffic!", ticker: "a Manhattan cab ride"),
        "T2":  MilestoneContent(emoji: "🚇", comparison: "That's a full loop on the London Underground!", ticker: "a Tube loop"),
        "T3":  MilestoneContent(emoji: "🎭", comparison: "That's a Broadway show, start to curtain call!", ticker: "a Broadway show"),
        "T4":  MilestoneContent(emoji: "🏙", comparison: "That's a walking tour clear across Paris!", ticker: "a Paris walking tour"),
        "T5":  MilestoneContent(emoji: "🚗", comparison: "That's the drive from LA to San Francisco!", ticker: "the LA-to-SF drive"),
        "T6":  MilestoneContent(emoji: "🚆", comparison: "That's a bullet-train day the length of Japan!", ticker: "a bullet-train day"),
        "T7":  MilestoneContent(emoji: "✈️", comparison: "That's 50 hours aloft — nearly London to Sydney twice!", ticker: "London-to-Sydney flights"),
        "T8":  MilestoneContent(emoji: "🌍", comparison: "That's 100 hours — enough to circle the globe by rail!", ticker: "a globe-circling trip"),
        "R1":  MilestoneContent(emoji: "🚦", comparison: "That's 50 traffic lights on a cross-town commute!", ticker: "city traffic lights"),
        "R2":  MilestoneContent(emoji: "🏢", comparison: "That's 100 floors up a downtown skyscraper!", ticker: "skyscraper floors"),
        "R3":  MilestoneContent(emoji: "🚕", comparison: "That's 250 taxi honks in one rush hour!", ticker: "taxi honks"),
        "R4":  MilestoneContent(emoji: "🪟", comparison: "That's 500 windows on a city high-rise!", ticker: "high-rise windows"),
        "R5":  MilestoneContent(emoji: "🚪", comparison: "That's 1,000 apartment doors on a single block!", ticker: "apartment doors"),
        "R6":  MilestoneContent(emoji: "🧱", comparison: "That's 2,500 bricks in a brownstone wall!", ticker: "brownstone bricks"),
        "R7":  MilestoneContent(emoji: "💡", comparison: "That's 5,000 bulbs on a Times Square billboard!", ticker: "billboard lights"),
        "R8":  MilestoneContent(emoji: "🏙", comparison: "That's 10,000 windows across a whole skyline!", ticker: "a skyline of windows"),
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
        "T1":  MilestoneContent(emoji: "🗼", comparison: "That's the elevator wait at the Eiffel Tower in July!", ticker: "an Eiffel Tower queue"),
        "T2":  MilestoneContent(emoji: "🎡", comparison: "That's two full turns of the London Eye!", ticker: "London Eye spins"),
        "T3":  MilestoneContent(emoji: "🏛", comparison: "That's a full guided tour of the Louvre!", ticker: "a Louvre tour"),
        "T4":  MilestoneContent(emoji: "🗽", comparison: "That's the ferry-and-climb to Lady Liberty, twice over!", ticker: "Statue of Liberty trips"),
        "T5":  MilestoneContent(emoji: "🏜️", comparison: "That's a rim-to-rim hike across the Grand Canyon!", ticker: "a Grand Canyon hike"),
        "T6":  MilestoneContent(emoji: "⛰️", comparison: "That's a summit day on Mount Kilimanjaro!", ticker: "a Kilimanjaro summit day"),
        "T7":  MilestoneContent(emoji: "🧗", comparison: "That's the time to climb El Capitan the hard way!", ticker: "an El Cap ascent"),
        "T8":  MilestoneContent(emoji: "🏔", comparison: "That's a full expedition push on Everest!", ticker: "an Everest push"),
        "R1":  MilestoneContent(emoji: "🪜", comparison: "That's 50 steps up inside the Statue of Liberty!", ticker: "Liberty steps"),
        "R2":  MilestoneContent(emoji: "🗼", comparison: "That's 100 steps up the Eiffel Tower!", ticker: "Eiffel steps"),
        "R3":  MilestoneContent(emoji: "🏛", comparison: "That's 250 arches around the Roman Colosseum!", ticker: "Colosseum arches"),
        "R4":  MilestoneContent(emoji: "🧗", comparison: "That's 500 steps up the Leaning Tower of Pisa and back!", ticker: "Pisa steps"),
        "R5":  MilestoneContent(emoji: "⛩️", comparison: "That's 1,000 torii gates at Fushimi Inari shrine!", ticker: "torii gates"),
        "R6":  MilestoneContent(emoji: "🪜", comparison: "That's 2,500 steps along the Great Wall of China!", ticker: "Great Wall steps"),
        "R7":  MilestoneContent(emoji: "🧱", comparison: "That's 5,000 blocks in the Great Pyramid's base!", ticker: "pyramid blocks"),
        "R8":  MilestoneContent(emoji: "🗿", comparison: "That's 10,000 stones in Machu Picchu's terraces!", ticker: "Machu Picchu stones"),
    ]

    private static let foodContent: [String: MilestoneContent] = [
        "D1":  MilestoneContent(emoji: "🍌", comparison: "That's about 8,000 bananas laid end to end!", ticker: "a banana bridge"),
        "D1b": MilestoneContent(emoji: "🥖", comparison: "That's 6,700 baguettes lined up nose to tail!", ticker: "a baguette highway"),
        "D2":  MilestoneContent(emoji: "🍕", comparison: "That's 5,800 pizzas lined up crust to crust!", ticker: "a pizza runway"),
        "D2b": MilestoneContent(emoji: "🌭", comparison: "That's 105,000 hot dogs end to end!", ticker: "a hot-dog marathon"),
        "D3":  MilestoneContent(emoji: "🥨", comparison: "That's a half marathon paved entirely in pretzels!", ticker: "a pretzel half-marathon"),
        "D3b": MilestoneContent(emoji: "🍜", comparison: "That's 28 km of ramen noodles slurped straight!", ticker: "a ramen river"),
        "D4":  MilestoneContent(emoji: "🍩", comparison: "That's a full marathon ringed with donuts!", ticker: "a donut marathon"),
        "D4b": MilestoneContent(emoji: "🥞", comparison: "That's a stack of pancakes toppling for 56 km!", ticker: "a pancake avalanche"),
        "D5":  MilestoneContent(emoji: "🍇", comparison: "That's a single vineyard row 80 km long!", ticker: "a grapevine trail"),
        "D5b": MilestoneContent(emoji: "🌯", comparison: "That's 120 km of burritos rolled tip to tip!", ticker: "a burrito border-run"),
        "D6":  MilestoneContent(emoji: "🍝", comparison: "That's a single strand of spaghetti 160 km long!", ticker: "an endless spaghetti noodle"),
        "W1":  MilestoneContent(emoji: "🥔", comparison: "That's a 227 kg sack of potatoes!", ticker: "a potato sack"),
        "W1b": MilestoneContent(emoji: "🧀", comparison: "That's a cheese wheel fit for a giant — 454 kg!", ticker: "a giant cheese wheel"),
        "W2":  MilestoneContent(emoji: "🎃", comparison: "That's the world's biggest pumpkin — 1,134 kg!", ticker: "a record pumpkin"),
        "W2b": MilestoneContent(emoji: "🍫", comparison: "That's 2,268 kg of chocolate — a dentist's nightmare!", ticker: "a chocolate mountain"),
        "W3":  MilestoneContent(emoji: "🍞", comparison: "That's 4,536 kg of bread dough, rising!", ticker: "a mountain of dough"),
        "W3b": MilestoneContent(emoji: "🥓", comparison: "That's 6,804 kg of bacon — a very happy morning!", ticker: "a bacon hoard"),
        "W4":  MilestoneContent(emoji: "🍔", comparison: "That's 11,340 kg of burgers stacked to the sky!", ticker: "a burger tower"),
        "W4b": MilestoneContent(emoji: "🍦", comparison: "That's 15,876 kg of ice cream before it melts!", ticker: "an ice-cream glacier"),
        "W5":  MilestoneContent(emoji: "🍉", comparison: "That's 22,680 kg of watermelons!", ticker: "a watermelon avalanche"),
        "W5b": MilestoneContent(emoji: "🥫", comparison: "That's 34,019 kg of canned beans!", ticker: "a bean-can vault"),
        "W6":  MilestoneContent(emoji: "🎂", comparison: "That's a wedding cake weighing 45,359 kg!", ticker: "a colossal cake"),
        "T1":  MilestoneContent(emoji: "☕", comparison: "That's long enough to brew and savor 10 coffees!", ticker: "a coffee break"),
        "T2":  MilestoneContent(emoji: "🍞", comparison: "That's one full rise of a sourdough loaf!", ticker: "a sourdough rise"),
        "T3":  MilestoneContent(emoji: "🍲", comparison: "That's a pot of stew simmered to perfection!", ticker: "a slow-simmered stew"),
        "T4":  MilestoneContent(emoji: "🦃", comparison: "That's roasting a Thanksgiving turkey — twice!", ticker: "two turkey roasts"),
        "T5":  MilestoneContent(emoji: "🧀", comparison: "That's how long a fresh cheese sets before aging!", ticker: "a cheese-setting session"),
        "T6":  MilestoneContent(emoji: "🥩", comparison: "That's a brisket smoked low and slow — 20 hours!", ticker: "a brisket smoke"),
        "T7":  MilestoneContent(emoji: "🍷", comparison: "That's the first 50 hours of grape fermentation!", ticker: "a wine fermentation"),
        "T8":  MilestoneContent(emoji: "🍲", comparison: "That's 100 hours of a stockpot bubbling away!", ticker: "an eternal stockpot"),
        "R1":  MilestoneContent(emoji: "🥟", comparison: "That's 50 dumplings pleated by hand!", ticker: "hand-pleated dumplings"),
        "R2":  MilestoneContent(emoji: "🍣", comparison: "That's 100 pieces of sushi rolled to order!", ticker: "sushi pieces"),
        "R3":  MilestoneContent(emoji: "🥐", comparison: "That's 250 croissants folded before dawn!", ticker: "folded croissants"),
        "R4":  MilestoneContent(emoji: "🍪", comparison: "That's 500 cookies scooped onto the tray!", ticker: "scooped cookies"),
        "R5":  MilestoneContent(emoji: "🧁", comparison: "That's 1,000 cupcakes frosted swirl by swirl!", ticker: "frosted cupcakes"),
        "R6":  MilestoneContent(emoji: "🥧", comparison: "That's 2,500 pie crusts crimped by thumb!", ticker: "crimped pie crusts"),
        "R7":  MilestoneContent(emoji: "🫓", comparison: "That's 5,000 tortillas pressed by hand!", ticker: "pressed tortillas"),
        "R8":  MilestoneContent(emoji: "🍤", comparison: "That's 10,000 shrimp peeled — chef's got claws!", ticker: "peeled shrimp"),
    ]

    private static let dinosaursContent: [String: MilestoneContent] = [
        "D1":  MilestoneContent(emoji: "🦖", comparison: "That's a T-Rex's morning stomp around the territory!", ticker: "a T-Rex stomp"),
        "D1b": MilestoneContent(emoji: "🦕", comparison: "That's a Brachiosaurus's stroll to the water hole!", ticker: "a Brachiosaurus stroll"),
        "D2":  MilestoneContent(emoji: "🦴", comparison: "That's a herd of Triceratops on the move!", ticker: "a Triceratops migration"),
        "D2b": MilestoneContent(emoji: "🦶", comparison: "That's 14,000 fossilized dinosaur footprints in a row!", ticker: "a footprint trail"),
        "D3":  MilestoneContent(emoji: "🦖", comparison: "That's a Velociraptor's full hunting sprint circuit!", ticker: "a raptor hunt"),
        "D3b": MilestoneContent(emoji: "🦕", comparison: "That's a Sauropod's daily graze across the valley!", ticker: "a sauropod graze"),
        "D4":  MilestoneContent(emoji: "🦴", comparison: "That's a full migration leg of a Hadrosaur herd!", ticker: "a Hadrosaur migration"),
        "D4b": MilestoneContent(emoji: "🐊", comparison: "That's a Spinosaurus patrolling its river — twice!", ticker: "a Spinosaurus patrol"),
        "D5":  MilestoneContent(emoji: "🌋", comparison: "That's a full flee from an erupting Cretaceous volcano!", ticker: "a volcano escape"),
        "D5b": MilestoneContent(emoji: "🦖", comparison: "That's a Gallimimus flock's cross-plains dash!", ticker: "a Gallimimus dash"),
        "D6":  MilestoneContent(emoji: "🦕", comparison: "That's an entire dinosaur migration route!", ticker: "a dino migration route"),
        "W1":  MilestoneContent(emoji: "🦕", comparison: "That's the weight of a baby Triceratops!", ticker: "a baby Triceratops"),
        "W1b": MilestoneContent(emoji: "🦖", comparison: "That's a full-grown Pachycephalosaurus — 454 kg!", ticker: "a Pachycephalosaurus"),
        "W2":  MilestoneContent(emoji: "🦏", comparison: "That's a Styracosaurus, horns and all — 1,134 kg!", ticker: "a Styracosaurus"),
        "W2b": MilestoneContent(emoji: "🦕", comparison: "That's an Ankylosaurus, club included — 2,268 kg!", ticker: "an Ankylosaurus"),
        "W3":  MilestoneContent(emoji: "🦖", comparison: "That's a T-Rex, teeth and tail — 4,536 kg!", ticker: "a T-Rex"),
        "W3b": MilestoneContent(emoji: "🦕", comparison: "That's a Triceratops at full charge — 6,804 kg!", ticker: "a Triceratops"),
        "W4":  MilestoneContent(emoji: "🦴", comparison: "That's a whole Stegosaurus herd — 11,340 kg!", ticker: "a Stegosaurus herd"),
        "W4b": MilestoneContent(emoji: "🦕", comparison: "That's an Apatosaurus — 15,876 kg of gentle giant!", ticker: "an Apatosaurus"),
        "W5":  MilestoneContent(emoji: "🦖", comparison: "That's a Brachiosaurus reaching for treetops — 22,680 kg!", ticker: "a Brachiosaurus"),
        "W5b": MilestoneContent(emoji: "🦕", comparison: "That's a Diplodocus stretched nose to tail — 34,019 kg!", ticker: "a Diplodocus"),
        "W6":  MilestoneContent(emoji: "🦴", comparison: "That's an Argentinosaurus, the heavyweight champ — 45,359 kg!", ticker: "an Argentinosaurus"),
        "T1":  MilestoneContent(emoji: "🥚", comparison: "That's a hatchling cracking out of its egg!", ticker: "a dino hatching"),
        "T2":  MilestoneContent(emoji: "🦖", comparison: "That's a T-Rex's post-feast nap!", ticker: "a T-Rex nap"),
        "T3":  MilestoneContent(emoji: "🦕", comparison: "That's a Sauropod's leisurely afternoon graze!", ticker: "a sauropod graze"),
        "T4":  MilestoneContent(emoji: "🌿", comparison: "That's a herd browsing a whole fern prairie!", ticker: "a fern-prairie browse"),
        "T5":  MilestoneContent(emoji: "🦴", comparison: "That's a full day guarding the nesting grounds!", ticker: "a nest-guard shift"),
        "T6":  MilestoneContent(emoji: "🌋", comparison: "That's a 20-hour trek to new feeding grounds!", ticker: "a feeding-grounds trek"),
        "T7":  MilestoneContent(emoji: "🦕", comparison: "That's 50 hours of a great herd migration!", ticker: "a herd migration"),
        "T8":  MilestoneContent(emoji: "🦖", comparison: "That's 100 hours across the Cretaceous plains!", ticker: "a Cretaceous expedition"),
        "R1":  MilestoneContent(emoji: "🦖", comparison: "That's 50 mighty T-Rex chomps!", ticker: "T-Rex chomps"),
        "R2":  MilestoneContent(emoji: "🦶", comparison: "That's 100 ground-shaking dino stomps!", ticker: "dino stomps"),
        "R3":  MilestoneContent(emoji: "🦴", comparison: "That's 250 tail swings from a Stegosaurus!", ticker: "tail swings"),
        "R4":  MilestoneContent(emoji: "🥚", comparison: "That's 500 eggs across the nesting colony!", ticker: "nesting eggs"),
        "R5":  MilestoneContent(emoji: "🦕", comparison: "That's 1,000 neck stretches to the treetops!", ticker: "neck stretches"),
        "R6":  MilestoneContent(emoji: "🦷", comparison: "That's 2,500 teeth regrown in a lifetime!", ticker: "regrown teeth"),
        "R7":  MilestoneContent(emoji: "🦶", comparison: "That's 5,000 fossilized footprints unearthed!", ticker: "fossil footprints"),
        "R8":  MilestoneContent(emoji: "🦖", comparison: "That's 10,000 roars echoing across the ages!", ticker: "prehistoric roars"),
    ]

    // MARK: - Helpers

    /// The milestone array backing a given activity type. One switch that every type-specific
    /// lookup routes through, so a new activity type must be handled here (and only here). (v2.2)
    static func milestones(for type: ActivityType) -> [Milestone] {
        switch type {
        case .distance: return distanceMilestones
        case .weight:   return weightMilestones
        case .duration: return durationMilestones
        case .reps:     return repsMilestones
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
