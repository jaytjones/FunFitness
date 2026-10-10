//
//  ComparisonEngine.swift
//  FunFitness
//

import Foundation

// Stored-unit tags for milestone thresholds (SI since v1.2).
enum ActivityUnit: Hashable, Sendable {
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
    // Handwritten title for named milestones (Half Marathon, WHO goal, duration/reps). When nil,
    // the title is generated from the threshold in the user's units. (v2.3)
    private let fixedTitle: String?

    init(id: String, threshold: Double, unit: ActivityUnit, title: String? = nil) {
        self.id = id
        self.threshold = threshold
        self.unit = unit
        self.fixedTitle = title
    }

    /// Display title in the user's preferred units, e.g. "You've run 5 miles!" / "You've run 8 km!".
    func title(pref: UnitPreference) -> String {
        if let fixedTitle { return fixedTitle }
        switch unit {
        case .kilometers:
            let value = UnitConverter.fromKm(threshold, to: pref)
            let amount = value.formatted(.number.precision(.fractionLength(0...1)))
            if pref == .metric { return "You've run \(amount) km!" }
            return "You've run \(amount) \(amount == "1" ? "mile" : "miles")!"
        case .kilograms:
            let value = UnitConverter.fromKg(threshold, to: pref)
            let amount = value.formatted(.number.precision(.fractionLength(0)))
            return "You've lifted \(amount) \(pref.weightUnit)!"
        case .minutes, .reps:
            // Every duration/reps milestone has a handwritten title; this is only a fallback.
            return "Milestone reached!"
        }
    }

    /// Whether `total` has reached this milestone. The tiny relative slack absorbs
    /// floating-point error from summing entries (3 × 25 mi can land a hair under 75 mi).
    func isReached(by total: Double) -> Bool {
        total >= threshold * (1 - 1e-9)
    }

    func getEmoji(for pack: ThemePack) -> String {
        ComparisonEngine.content(packId: pack.id, milestoneId: id)?.emoji ?? "🎯"
    }
    func getComparison(for pack: ThemePack) -> String {
        ComparisonEngine.content(packId: pack.id, milestoneId: id)?.comparison ?? "Great work!"
    }
}

// Per-pack, per-milestone silly copy.
struct MilestoneContent {
    let emoji: String
    let comparison: String   // full sentence shown on the milestone/achievement card
}

struct ComparisonEngine {

    // MARK: - Distance Milestones (sorted ascending; thresholds in km)

    // Imperial-titled thresholds are derived from their source unit with the same constant the
    // log sheet uses for input, so logging exactly "75 mi" lands on the threshold. Never raise
    // an existing threshold — users who earned the badge would lose it. (v2.3)
    private static func miles(_ value: Double) -> Double { value * UnitConverter.kmPerMile }
    private static func pounds(_ value: Double) -> Double { value * UnitConverter.kgPerLb }

    static let distanceMilestones: [Milestone] = [
        Milestone(id: "D1",  threshold: miles(1),    unit: .kilometers),
        Milestone(id: "D1b", threshold: miles(2.5),  unit: .kilometers),
        Milestone(id: "D2",  threshold: miles(5),    unit: .kilometers),
        Milestone(id: "D2b", threshold: miles(10),   unit: .kilometers),
        Milestone(id: "D3",  threshold: 21.0975,     unit: .kilometers, title: "Half Marathon Complete!"),
        Milestone(id: "D3b", threshold: miles(17.5), unit: .kilometers),
        Milestone(id: "D4",  threshold: 42.195,      unit: .kilometers, title: "Full Marathon Complete!"),
        Milestone(id: "D4b", threshold: miles(35),   unit: .kilometers),
        Milestone(id: "D5",  threshold: miles(50),   unit: .kilometers),
        Milestone(id: "D5b", threshold: miles(75),   unit: .kilometers),
        Milestone(id: "D6",  threshold: miles(100),  unit: .kilometers),
        // v2.3 Journey anchors for GPS-era totals. New ids only; existing ids never change.
        Milestone(id: "D7",  threshold: miles(250),   unit: .kilometers),
        Milestone(id: "D8",  threshold: miles(500),   unit: .kilometers),
        Milestone(id: "D9",  threshold: miles(1_000), unit: .kilometers),
        Milestone(id: "D10", threshold: miles(2_190), unit: .kilometers, title: "Appalachian Trail Complete!"),
    ]

    // MARK: - Weight Milestones (sorted ascending; thresholds in kg)

    static let weightMilestones: [Milestone] = [
        Milestone(id: "W1",  threshold: pounds(500),     unit: .kilograms),
        Milestone(id: "W1b", threshold: pounds(1_000),   unit: .kilograms),
        Milestone(id: "W2",  threshold: pounds(2_500),   unit: .kilograms),
        Milestone(id: "W2b", threshold: pounds(5_000),   unit: .kilograms),
        Milestone(id: "W3",  threshold: pounds(10_000),  unit: .kilograms),
        Milestone(id: "W3b", threshold: pounds(15_000),  unit: .kilograms),
        Milestone(id: "W4",  threshold: pounds(25_000),  unit: .kilograms),
        // Kept at the original literal: pounds(35_000) is 0.02 kg higher, and thresholds never rise.
        Milestone(id: "W4b", threshold: 15875.7,         unit: .kilograms),
        Milestone(id: "W5",  threshold: pounds(50_000),  unit: .kilograms),
        Milestone(id: "W5b", threshold: pounds(75_000),  unit: .kilograms),
        Milestone(id: "W6",  threshold: pounds(100_000), unit: .kilograms),
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
        "D1":  MilestoneContent(emoji: "🦒", comparison: "That's like walking past 270 giraffes stacked head to tail!"),
        "D1b": MilestoneContent(emoji: "🐱", comparison: "That's about 5,500 house cats laid nose-to-tail!"),
        "D2":  MilestoneContent(emoji: "🐳", comparison: "That's about 270 blue whales lined up nose to tail!"),
        "D2b": MilestoneContent(emoji: "🦅", comparison: "That's a bald eagle's full afternoon patrol route!"),
        "D3":  MilestoneContent(emoji: "🏃", comparison: "You've completed a half marathon distance!"),
        "D3b": MilestoneContent(emoji: "🦁", comparison: "That's a mountain lion's longest night of prowling for prey!"),
        "D4":  MilestoneContent(emoji: "🏅", comparison: "You've completed a full marathon distance!"),
        "D4b": MilestoneContent(emoji: "🐺", comparison: "That's the nightly roaming distance of a timber wolf!"),
        "D5":  MilestoneContent(emoji: "🐃", comparison: "That's a few days on the great wildebeest migration!"),
        "D5b": MilestoneContent(emoji: "🐬", comparison: "That's a bottlenose dolphin's daily swim!"),
        "D6":  MilestoneContent(emoji: "🦋", comparison: "That's a Monarch butterfly's daily flight!"),
        "D7":  MilestoneContent(emoji: "🐪", comparison: "That's ten days with a desert camel caravan!"),
        "D8":  MilestoneContent(emoji: "🐃", comparison: "That's one full lap of the great wildebeest migration!"),
        "D9":  MilestoneContent(emoji: "🐃", comparison: "That's two full laps of the great wildebeest migration!"),
        "D10": MilestoneContent(emoji: "🦋", comparison: "That's a Monarch butterfly's entire fall migration to Mexico!"),
        "W1":  MilestoneContent(emoji: "🦁", comparison: "That's the weight of a male lion!"),
        "W1b": MilestoneContent(emoji: "🐻", comparison: "That's a full-grown coastal brown bear — and he skipped leg day!"),
        "W2":  MilestoneContent(emoji: "🦛", comparison: "That's the weight of a mama hippo!"),
        "W2b": MilestoneContent(emoji: "🦏", comparison: "That's heavier than a white rhinoceros!"),
        "W3":  MilestoneContent(emoji: "🐘", comparison: "That's the weight of an elephant!"),
        "W3b": MilestoneContent(emoji: "🦒", comparison: "That's 5 fully grown male giraffes — one for every leg day!"),
        "W4":  MilestoneContent(emoji: "🐘", comparison: "That's Henry, the giant elephant in the Smithsonian's rotunda!"),
        "W4b": MilestoneContent(emoji: "🐋", comparison: "That's a young humpback whale, fresh out of college!"),
        "W5":  MilestoneContent(emoji: "🦈", comparison: "That's the biggest whale shark ever measured!"),
        "W5b": MilestoneContent(emoji: "🐳", comparison: "That's the weight of an average sperm whale!"),
        "W6":  MilestoneContent(emoji: "🐋", comparison: "That's a full-grown gray whale!"),
        "T1":  MilestoneContent(emoji: "🐆", comparison: "That's how long a cheetah rests between sprints!"),
        "T2":  MilestoneContent(emoji: "🐋", comparison: "That's one deep dive by a Cuvier's beaked whale!"),
        "T3":  MilestoneContent(emoji: "🐘", comparison: "That's how long an elephant naps standing up!"),
        "T4":  MilestoneContent(emoji: "🦁", comparison: "That's a lion's afternoon snooze — 5 hours flat!"),
        "T5":  MilestoneContent(emoji: "🦥", comparison: "That's a wild sloth's entire day of sleep!"),
        "T6":  MilestoneContent(emoji: "🐻", comparison: "That's a hibernating bear's first day of winter!"),
        "T7":  MilestoneContent(emoji: "🐋", comparison: "That's a gray whale migrating nonstop for 50 hours!"),
        "T8":  MilestoneContent(emoji: "🐦", comparison: "That's a great snipe's nonstop flight from Sweden to Africa!"),
        "R1":  MilestoneContent(emoji: "🦘", comparison: "That's 50 kangaroo hops across the outback!"),
        "R2":  MilestoneContent(emoji: "🐇", comparison: "That's 100 bunny hops through the meadow!"),
        "R3":  MilestoneContent(emoji: "🐝", comparison: "That's 250 waggle-dances from a busy bee!"),
        "R4":  MilestoneContent(emoji: "🐿️", comparison: "That's 500 acorns buried by an industrious squirrel!"),
        "R5":  MilestoneContent(emoji: "🐦", comparison: "That's 1,000 pecks from a hungry woodpecker!"),
        "R6":  MilestoneContent(emoji: "🦗", comparison: "That's 2,500 chirps from a summer cricket!"),
        "R7":  MilestoneContent(emoji: "🐜", comparison: "That's 5,000 ants marching in a single line!"),
        "R8":  MilestoneContent(emoji: "🐝", comparison: "That's a whole honeybee swarm hunting for a new home!"),
    ]

    private static let citiesContent: [String: MilestoneContent] = [
        "D1":  MilestoneContent(emoji: "🏙", comparison: "That's the distance across 18 NYC blocks!"),
        "D1b": MilestoneContent(emoji: "🌳", comparison: "That's the full length of Central Park!"),
        "D2":  MilestoneContent(emoji: "🌳", comparison: "That's most of the way around Central Park's loop!"),
        "D2b": MilestoneContent(emoji: "✈️", comparison: "That's the entire Las Vegas Strip, end to end, more than twice!"),
        "D3":  MilestoneContent(emoji: "🏙", comparison: "That's the length of Manhattan island!"),
        "D3b": MilestoneContent(emoji: "🌆", comparison: "That's downtown LA to the Santa Monica Pier — and then some!"),
        "D4":  MilestoneContent(emoji: "🤖", comparison: "That's from Austin to Georgetown!"),
        "D4b": MilestoneContent(emoji: "🏙️", comparison: "That's from Baltimore to Washington, D.C.!"),
        "D5":  MilestoneContent(emoji: "🚗", comparison: "That's from San Francisco to San Jose!"),
        "D5b": MilestoneContent(emoji: "🚂", comparison: "That's from Austin to San Antonio!"),
        "D6":  MilestoneContent(emoji: "🏙", comparison: "That's from New York City to Philadelphia!"),
        "D7":  MilestoneContent(emoji: "🎰", comparison: "That's from Los Angeles to Las Vegas!"),
        "D8":  MilestoneContent(emoji: "🚆", comparison: "That's the whole Northeast Corridor, Boston to Washington, D.C.!"),
        "D9":  MilestoneContent(emoji: "🤠", comparison: "That's from Chicago to Dallas!"),
        "D10": MilestoneContent(emoji: "🌁", comparison: "That's from Chicago to San Francisco!"),
        "W1":  MilestoneContent(emoji: "🏍️", comparison: "That's a Harley-Davidson Nightster, ready to roar!"),
        "W1b": MilestoneContent(emoji: "🏍️", comparison: "That's a Honda Gold Wing touring motorcycle!"),
        "W2":  MilestoneContent(emoji: "🚗", comparison: "That's the weight of a Mini Cooper!"),
        "W2b": MilestoneContent(emoji: "🛻", comparison: "That's a Ford F-150 pickup truck!"),
        "W3":  MilestoneContent(emoji: "🚙", comparison: "That's a GMC Hummer EV, the heavyweight of pickups!"),
        "W3b": MilestoneContent(emoji: "🚌", comparison: "That's an empty yellow school bus, waiting for the bell!"),
        "W4":  MilestoneContent(emoji: "🚒", comparison: "That's a fire engine before its water tank is filled!"),
        "W4b": MilestoneContent(emoji: "🚌", comparison: "That's a school bus packed with students!"),
        "W5":  MilestoneContent(emoji: "🚌", comparison: "That's two empty city buses parked bumper to bumper!"),
        "W5b": MilestoneContent(emoji: "🚛", comparison: "That's a fully loaded 18-wheel tractor-trailer!"),
        "W6":  MilestoneContent(emoji: "✈️", comparison: "That's an empty Boeing 737 airliner!"),
        "T1":  MilestoneContent(emoji: "🚕", comparison: "That's a cross-town cab ride in Manhattan traffic!"),
        "T2":  MilestoneContent(emoji: "🚇", comparison: "That's a ride on London's Circle line, end to end!"),
        "T3":  MilestoneContent(emoji: "🎭", comparison: "That's a Broadway show, start to curtain call!"),
        "T4":  MilestoneContent(emoji: "🏙", comparison: "That's a walking tour clear across Paris!"),
        "T5":  MilestoneContent(emoji: "🚗", comparison: "That's the LA-to-San Francisco drive the scenic way, up Highway 1!"),
        "T6":  MilestoneContent(emoji: "🚆", comparison: "That's the overnight train from New York to Chicago!"),
        "T7":  MilestoneContent(emoji: "✈️", comparison: "That's 50 hours aloft — more than London to Sydney twice!"),
        "T8":  MilestoneContent(emoji: "🚂", comparison: "That's VIA Rail's Canadian, Toronto all the way to Vancouver!"),
        "R1":  MilestoneContent(emoji: "🚦", comparison: "That's 50 traffic lights on a cross-town commute!"),
        "R2":  MilestoneContent(emoji: "🏢", comparison: "That's 100 floors up a downtown skyscraper!"),
        "R3":  MilestoneContent(emoji: "🚕", comparison: "That's 250 taxi honks in one rush hour!"),
        "R4":  MilestoneContent(emoji: "🪟", comparison: "That's 500 windows on a city high-rise!"),
        "R5":  MilestoneContent(emoji: "🚪", comparison: "That's 1,000 apartment doors on a single block!"),
        "R6":  MilestoneContent(emoji: "🧱", comparison: "That's 2,500 bricks in a brownstone wall!"),
        "R7":  MilestoneContent(emoji: "💡", comparison: "That's 5,000 bulbs on a Times Square billboard!"),
        "R8":  MilestoneContent(emoji: "🏢", comparison: "That's every window on the Empire State Building — and half again!"),
    ]

    private static let landmarksContent: [String: MilestoneContent] = [
        "D1":  MilestoneContent(emoji: "🗼", comparison: "That's 5 Eiffel Towers laid end to end!"),
        "D1b": MilestoneContent(emoji: "🗽", comparison: "That's the Statue of Liberty, stacked 43 times!"),
        "D2":  MilestoneContent(emoji: "🌉", comparison: "That's across the Golden Gate Bridge three times!"),
        "D2b": MilestoneContent(emoji: "🏜️", comparison: "That's almost halfway across the Grand Canyon, rim to rim!"),
        "D3":  MilestoneContent(emoji: "🎰", comparison: "That's the entire Las Vegas Strip, three times over!"),
        "D3b": MilestoneContent(emoji: "🌸", comparison: "That's the full Champs-Élysées, 15 times over!"),
        "D4":  MilestoneContent(emoji: "🏛️", comparison: "That's the legendary run from Marathon to Athens!"),
        "D4b": MilestoneContent(emoji: "🛤️", comparison: "That's the Hudson River Greenway, three times over!"),
        "D5":  MilestoneContent(emoji: "🧗", comparison: "That's the full length of the Panama Canal!"),
        "D5b": MilestoneContent(emoji: "🌊", comparison: "That's the full length of Hadrian's Wall, coast to coast!"),
        "D6":  MilestoneContent(emoji: "🌊", comparison: "That's swimming the English Channel nearly 5 times!"),
        "D7":  MilestoneContent(emoji: "🏰", comparison: "That's Hadrian's Wall, end to end, more than three times!"),
        "D8":  MilestoneContent(emoji: "🐚", comparison: "That's the entire Camino de Santiago pilgrimage!"),
        "D9":  MilestoneContent(emoji: "🇬🇧", comparison: "That's Land's End to John o' Groats — the length of Britain!"),
        "D10": MilestoneContent(emoji: "🥾", comparison: "That's the entire Appalachian Trail, Georgia to Maine!"),
        "W1":  MilestoneContent(emoji: "🔔", comparison: "That's the weight of a church bell!"),
        "W1b": MilestoneContent(emoji: "🔔", comparison: "That's half the Liberty Bell!"),
        "W2":  MilestoneContent(emoji: "🔔", comparison: "That's the Liberty Bell, crack and all!"),
        "W2b": MilestoneContent(emoji: "🔔", comparison: "That's two Liberty Bells ringing side by side!"),
        "W3":  MilestoneContent(emoji: "🔔", comparison: "That's the Bicentennial Bell, Britain's birthday gift to America!"),
        "W3b": MilestoneContent(emoji: "🗿", comparison: "That's a Stonehenge lintel, the stone laid across the top!"),
        "W4":  MilestoneContent(emoji: "🕰️", comparison: "That's Big Ben, the great bell of London!"),
        "W4b": MilestoneContent(emoji: "✈️", comparison: "That's the Wright Brothers' first airplane, 58 times over!"),
        "W5":  MilestoneContent(emoji: "🗿", comparison: "That's the weight of a section of Stonehenge!"),
        "W5b": MilestoneContent(emoji: "🗿", comparison: "That's three Stonehenge sarsens standing in a row!"),
        "W6":  MilestoneContent(emoji: "🚀", comparison: "That's the steel shell of a Space Shuttle rocket booster!"),
        "T1":  MilestoneContent(emoji: "🗼", comparison: "That's the elevator wait at the Eiffel Tower in July!"),
        "T2":  MilestoneContent(emoji: "🎡", comparison: "That's two full turns of the London Eye!"),
        "T3":  MilestoneContent(emoji: "🏛", comparison: "That's a full guided tour of the Louvre!"),
        "T4":  MilestoneContent(emoji: "🗽", comparison: "That's the ferry-and-climb to Lady Liberty, twice over!"),
        "T5":  MilestoneContent(emoji: "🏜️", comparison: "That's a rim-to-rim hike across the Grand Canyon!"),
        "T6":  MilestoneContent(emoji: "⛰️", comparison: "That's summit day on Kilimanjaro's Marangu route, midnight start to Horombo Hut!"),
        "T7":  MilestoneContent(emoji: "🧗", comparison: "That's a speedy two-day ascent of El Capitan's Nose!"),
        "T8":  MilestoneContent(emoji: "🏔", comparison: "That's a fast summit push on Everest, base camp to the top and back!"),
        "R1":  MilestoneContent(emoji: "🪜", comparison: "That's 50 steps up inside the Statue of Liberty!"),
        "R2":  MilestoneContent(emoji: "🗼", comparison: "That's 100 steps up the Eiffel Tower!"),
        "R3":  MilestoneContent(emoji: "🏛", comparison: "That's 250 arches around the Roman Colosseum!"),
        "R4":  MilestoneContent(emoji: "🧗", comparison: "That's 500 steps up the Leaning Tower of Pisa and back!"),
        "R5":  MilestoneContent(emoji: "⛩️", comparison: "That's Fushimi Inari's Senbon Torii — the famous 'thousand gates' tunnel!"),
        "R6":  MilestoneContent(emoji: "🪜", comparison: "That's 2,500 steps along the Great Wall of China!"),
        "R7":  MilestoneContent(emoji: "🪜", comparison: "That's every step of Italy's Calà del Sasso, the longest public staircase!"),
        "R8":  MilestoneContent(emoji: "🏔️", comparison: "That's the Niesen stairway in Switzerland — the longest staircase on Earth!"),
    ]

    private static let foodContent: [String: MilestoneContent] = [
        "D1":  MilestoneContent(emoji: "🍌", comparison: "That's about 8,000 bananas laid end to end!"),
        "D1b": MilestoneContent(emoji: "🥖", comparison: "That's 6,700 baguettes lined up nose to tail!"),
        "D2":  MilestoneContent(emoji: "🍕", comparison: "That's about 22,000 large pizzas lined up crust to crust!"),
        "D2b": MilestoneContent(emoji: "🌭", comparison: "That's 105,000 hot dogs end to end!"),
        "D3":  MilestoneContent(emoji: "🥨", comparison: "That's a half marathon paved entirely in pretzels!"),
        "D3b": MilestoneContent(emoji: "🍜", comparison: "That's one ramen noodle slurped straight across town!"),
        "D4":  MilestoneContent(emoji: "🍩", comparison: "That's a full marathon ringed with donuts!"),
        "D4b": MilestoneContent(emoji: "🥞", comparison: "That's a toppled pancake tower stretching to the horizon!"),
        "D5":  MilestoneContent(emoji: "🍇", comparison: "That's a single vineyard row running past the horizon!"),
        "D5b": MilestoneContent(emoji: "🌯", comparison: "That's burritos rolled tip to tip all the way to the border!"),
        "D6":  MilestoneContent(emoji: "🍝", comparison: "That's a single strand of spaghetti longer than a highway!"),
        "D7":  MilestoneContent(emoji: "🍣", comparison: "That's a conveyor-belt sushi line running across a whole state!"),
        "D8":  MilestoneContent(emoji: "🍕", comparison: "That's a trail of pizza boxes stretching across several states!"),
        "D9":  MilestoneContent(emoji: "🥖", comparison: "That's a baguette chain long enough to cross France and keep going!"),
        "D10": MilestoneContent(emoji: "🌭", comparison: "That's a hot-dog line stretching most of the way coast to coast!"),
        "W1":  MilestoneContent(emoji: "🥔", comparison: "That's a sack of potatoes big enough to feed a town!"),
        "W1b": MilestoneContent(emoji: "🧀", comparison: "That's a cheese wheel fit for a giant!"),
        "W2":  MilestoneContent(emoji: "🎃", comparison: "That's the world's biggest pumpkin!"),
        "W2b": MilestoneContent(emoji: "🍫", comparison: "That's a mountain of chocolate — a dentist's nightmare!"),
        "W3":  MilestoneContent(emoji: "🍞", comparison: "That's a mountain of bread dough, still rising!"),
        "W3b": MilestoneContent(emoji: "🥓", comparison: "That's a lifetime supply of bacon — a very happy morning!"),
        "W4":  MilestoneContent(emoji: "🍔", comparison: "That's a tower of burgers stacked to the sky!"),
        "W4b": MilestoneContent(emoji: "🍦", comparison: "That's a glacier of ice cream racing the sun!"),
        "W5":  MilestoneContent(emoji: "🍉", comparison: "That's a whole truckload of watermelons!"),
        "W5b": MilestoneContent(emoji: "🥫", comparison: "That's a warehouse vault full of canned beans!"),
        "W6":  MilestoneContent(emoji: "🎂", comparison: "That's a wedding cake the size of a house!"),
        "T1":  MilestoneContent(emoji: "🍫", comparison: "That's a pan of fudge brownies, oven to table!"),
        "T2":  MilestoneContent(emoji: "🍞", comparison: "That's one full rise of a yeasted bread dough!"),
        "T3":  MilestoneContent(emoji: "🍲", comparison: "That's a pot of stew simmered to perfection!"),
        "T4":  MilestoneContent(emoji: "🦃", comparison: "That's roasting a Thanksgiving turkey — twice!"),
        "T5":  MilestoneContent(emoji: "🧀", comparison: "That's how long a fresh cheese sets before aging!"),
        "T6":  MilestoneContent(emoji: "🥩", comparison: "That's a brisket smoked low and slow — 20 hours!"),
        "T7":  MilestoneContent(emoji: "🍷", comparison: "That's the first 50 hours of grape fermentation!"),
        "T8":  MilestoneContent(emoji: "🍲", comparison: "That's 100 hours of a stockpot bubbling away!"),
        "R1":  MilestoneContent(emoji: "🥟", comparison: "That's 50 dumplings pleated by hand!"),
        "R2":  MilestoneContent(emoji: "🍣", comparison: "That's 100 pieces of sushi rolled to order!"),
        "R3":  MilestoneContent(emoji: "🥐", comparison: "That's 250 croissants folded before dawn!"),
        "R4":  MilestoneContent(emoji: "🍪", comparison: "That's 500 cookies scooped onto the tray!"),
        "R5":  MilestoneContent(emoji: "🧁", comparison: "That's 1,000 cupcakes frosted swirl by swirl!"),
        "R6":  MilestoneContent(emoji: "🥧", comparison: "That's 2,500 pie crusts crimped by thumb!"),
        "R7":  MilestoneContent(emoji: "🫓", comparison: "That's 5,000 tortillas pressed by hand!"),
        "R8":  MilestoneContent(emoji: "🍤", comparison: "That's 10,000 shrimp peeled — chef's got claws!"),
    ]

    private static let dinosaursContent: [String: MilestoneContent] = [
        "D1":  MilestoneContent(emoji: "🦖", comparison: "That's a T-Rex's morning stomp around the territory!"),
        "D1b": MilestoneContent(emoji: "🦕", comparison: "That's a Brachiosaurus's stroll to the water hole!"),
        "D2":  MilestoneContent(emoji: "🦴", comparison: "That's a herd of Triceratops on the move!"),
        "D2b": MilestoneContent(emoji: "🦶", comparison: "That's 14,000 fossilized dinosaur footprints in a row!"),
        "D3":  MilestoneContent(emoji: "🦖", comparison: "That's a Velociraptor's full hunting sprint circuit!"),
        "D3b": MilestoneContent(emoji: "🦕", comparison: "That's a Sauropod's daily graze across the valley!"),
        "D4":  MilestoneContent(emoji: "🦴", comparison: "That's a full migration leg of a Hadrosaur herd!"),
        "D4b": MilestoneContent(emoji: "🐊", comparison: "That's a Spinosaurus patrolling its river — twice!"),
        "D5":  MilestoneContent(emoji: "🌋", comparison: "That's a full flee from an erupting Cretaceous volcano!"),
        "D5b": MilestoneContent(emoji: "🦖", comparison: "That's a Gallimimus flock's cross-plains dash!"),
        "D6":  MilestoneContent(emoji: "🦕", comparison: "That's an entire dinosaur migration route!"),
        "D7":  MilestoneContent(emoji: "🌊", comparison: "That's the Jurassic Coast, end to end, more than twice!"),
        "D8":  MilestoneContent(emoji: "🦕", comparison: "That's a sauropod herd's long seasonal trek!"),
        "D9":  MilestoneContent(emoji: "🦴", comparison: "That's Alberta's Dinosaur Trail more than thirty times over!"),
        "D10": MilestoneContent(emoji: "🦖", comparison: "That's a Velociraptor sprint across most of North America!"),
        "W1":  MilestoneContent(emoji: "🦕", comparison: "That's the weight of a baby Triceratops!"),
        "W1b": MilestoneContent(emoji: "🦖", comparison: "That's a full-grown Pachycephalosaurus, dome and all!"),
        "W2":  MilestoneContent(emoji: "🦕", comparison: "That's a Kentrosaurus, spikes and all!"),
        "W2b": MilestoneContent(emoji: "🦏", comparison: "That's a Styracosaurus, horns and all!"),
        "W3":  MilestoneContent(emoji: "🦕", comparison: "That's a full-grown Stegosaurus, plates and all!"),
        "W3b": MilestoneContent(emoji: "🦖", comparison: "That's a T-Rex, teeth and tail!"),
        "W4":  MilestoneContent(emoji: "🦕", comparison: "That's a Triceratops at full charge!"),
        "W4b": MilestoneContent(emoji: "🦕", comparison: "That's an Apatosaurus — a true gentle giant!"),
        "W5":  MilestoneContent(emoji: "🦕", comparison: "That's a Diplodocus hallorum, the giant once called Seismosaurus!"),
        "W5b": MilestoneContent(emoji: "🦒", comparison: "That's a Giraffatitan, Brachiosaurus's towering African cousin!"),
        "W6":  MilestoneContent(emoji: "🦕", comparison: "That's a Brachiosaurus reaching for the treetops!"),
        "T1":  MilestoneContent(emoji: "🥚", comparison: "That's a hatchling cracking out of its egg!"),
        "T2":  MilestoneContent(emoji: "🦖", comparison: "That's a T-Rex's post-feast nap!"),
        "T3":  MilestoneContent(emoji: "🦕", comparison: "That's a Sauropod's leisurely afternoon graze!"),
        "T4":  MilestoneContent(emoji: "🌿", comparison: "That's a herd browsing a whole fern prairie!"),
        "T5":  MilestoneContent(emoji: "🦴", comparison: "That's a full day guarding the nesting grounds!"),
        "T6":  MilestoneContent(emoji: "🌋", comparison: "That's a 20-hour trek to new feeding grounds!"),
        "T7":  MilestoneContent(emoji: "🦕", comparison: "That's 50 hours of a great herd migration!"),
        "T8":  MilestoneContent(emoji: "🦖", comparison: "That's 100 hours across the Cretaceous plains!"),
        "R1":  MilestoneContent(emoji: "🦖", comparison: "That's 50 mighty T-Rex chomps!"),
        "R2":  MilestoneContent(emoji: "🦶", comparison: "That's 100 ground-shaking dino stomps!"),
        "R3":  MilestoneContent(emoji: "🦴", comparison: "That's 250 tail swings from a Stegosaurus!"),
        "R4":  MilestoneContent(emoji: "🥚", comparison: "That's 500 eggs across the nesting colony!"),
        "R5":  MilestoneContent(emoji: "🦕", comparison: "That's 1,000 neck stretches to the treetops!"),
        "R6":  MilestoneContent(emoji: "🦷", comparison: "That's 2,500 teeth regrown in a lifetime!"),
        "R7":  MilestoneContent(emoji: "🦶", comparison: "That's 5,000 fossilized footprints unearthed!"),
        "R8":  MilestoneContent(emoji: "🦖", comparison: "That's 10,000 roars echoing across the ages!"),
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
        milestones(for: type).first { !$0.isReached(by: currentTotal) }
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
            !milestone.isReached(by: previousTotal) &&
            milestone.isReached(by: newTotal) &&
            !unlockedIds.contains(milestone.id)
        }.sorted { $0.threshold < $1.threshold }
    }
}
