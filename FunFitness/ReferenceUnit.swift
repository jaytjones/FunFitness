//
//  ReferenceUnit.swift
//  FunFitness
//
//  Real-world "absurd units" with a known size, so any total can be restated as a count of
//  something ("1,200 lbs is 2 grizzly bears"). Unlike milestones there's no ceiling: bestFit
//  picks whichever unit gives a readable count at the current total. Magnitudes are SI (km, kg,
//  minutes, reps) like everything else stored in the app. (v2.3)
//

import Foundation

struct ReferenceUnit: Identifiable, Sendable {
    let id: String
    let emoji: String
    let singular: String     // "hippo"
    let plural: String       // "hippos"
    let type: ActivityType
    let magnitude: Double    // SI amount of one unit
}

/// A total restated as a count of a reference unit.
struct ReferenceFit: Sendable {
    let unit: ReferenceUnit
    let count: Double

    /// "2.3 hippos", "1 hippo", "8,700 house cats", "0.4 Liberty Bells".
    var phrase: String {
        let formatted: String
        if count < 1 {
            formatted = count.formatted(.number.precision(.significantDigits(1...2)))
        } else if count < 10 {
            formatted = count.formatted(.number.precision(.fractionLength(0...1)))
        } else {
            formatted = count.formatted(.number.precision(.fractionLength(0)))
        }
        return "\(formatted) \(formatted == "1" ? unit.singular : unit.plural)"
    }
}

enum ReferenceUnitEngine {

    /// "2.3 km is 1 honeybee flight 🐝" for a single distance (a tracked run, not a running
    /// total). nil for zero. Shared by the tracking summary and the Live Activity. (3.1)
    static func distancePhrase(distanceKm: Double, pref: UnitPreference, packId: String) -> String? {
        guard let fit = bestFit(total: distanceKm, type: .distance, packId: packId) else { return nil }
        return "\(UnitConverter.distanceString(distanceKm, pref: pref)) is \(fit.phrase) \(fit.unit.emoji)"
    }

    /// Restates `total` (SI) as a count of the active pack's units for `type`.
    ///
    /// Picks the largest unit the total covers at least once, so counts stay small and readable;
    /// below the smallest unit it returns a fraction of that unit. Returns nil for a zero total.
    static func bestFit(total: Double, type: ActivityType, packId: String) -> ReferenceFit? {
        guard total > 0 else { return nil }
        let units = ReferenceUnitCatalog.units(packId: packId, type: type)
        guard let smallest = units.first else { return nil }
        let unit = units.last { total / $0.magnitude >= 1 } ?? smallest
        return ReferenceFit(unit: unit, count: total / unit.magnitude)
    }
}

enum ReferenceUnitCatalog {

    /// Units for a pack and type, sorted by magnitude. Falls back to Animals if a pack has none
    /// for that type, so a new pack can't leave the ticker blank.
    static func units(packId: String, type: ActivityType) -> [ReferenceUnit] {
        let own = (byPack[packId] ?? []).filter { $0.type == type }
        let units = own.isEmpty ? animals.filter { $0.type == type } : own
        return units.sorted { $0.magnitude < $1.magnitude }
    }

    static let byPack: [String: [ReferenceUnit]] = [
        ThemePackCatalog.animals.id:   animals,
        ThemePackCatalog.cities.id:    cities,
        ThemePackCatalog.landmarks.id: landmarks,
        ThemePackCatalog.food.id:      food,
        ThemePackCatalog.dinosaurs.id: dinosaurs,
    ]

    // Magnitudes are approximate, commonly cited figures. Distance in km, weight in kg,
    // duration in minutes, reps as a count.

    private static let animals: [ReferenceUnit] = [
        ReferenceUnit(id: "animals.blueWhaleLength", emoji: "🐳", singular: "blue whale length", plural: "blue whale lengths", type: .distance, magnitude: 0.03),
        ReferenceUnit(id: "animals.beeForagingFlight", emoji: "🐝", singular: "honeybee flight to the flowers", plural: "honeybee flights to the flowers", type: .distance, magnitude: 2.3),
        ReferenceUnit(id: "animals.elephantDailyWalk", emoji: "🐘", singular: "wild elephant's daily walk", plural: "wild elephant daily walks", type: .distance, magnitude: 10),
        ReferenceUnit(id: "animals.camelTrek", emoji: "🐪", singular: "camel day-trek", plural: "camel day-treks", type: .distance, magnitude: 40),
        ReferenceUnit(id: "animals.wildebeestMigration", emoji: "🐃", singular: "wildebeest migration", plural: "wildebeest migrations", type: .distance, magnitude: 800),
        ReferenceUnit(id: "animals.ternMigration", emoji: "🐦", singular: "Arctic tern migration", plural: "Arctic tern migrations", type: .distance, magnitude: 70_000),

        ReferenceUnit(id: "animals.houseCat", emoji: "🐱", singular: "house cat", plural: "house cats", type: .weight, magnitude: 4.5),
        ReferenceUnit(id: "animals.grizzly", emoji: "🐻", singular: "grizzly bear", plural: "grizzly bears", type: .weight, magnitude: 220),
        ReferenceUnit(id: "animals.hippo", emoji: "🦛", singular: "hippo", plural: "hippos", type: .weight, magnitude: 1_500),
        ReferenceUnit(id: "animals.elephant", emoji: "🐘", singular: "African elephant", plural: "African elephants", type: .weight, magnitude: 6_000),
        ReferenceUnit(id: "animals.blueWhale", emoji: "🐋", singular: "blue whale", plural: "blue whales", type: .weight, magnitude: 150_000),

        ReferenceUnit(id: "animals.giraffeSleep", emoji: "🦒", singular: "giraffe night's sleep", plural: "giraffe nights' sleep", type: .duration, magnitude: 60),
        ReferenceUnit(id: "animals.koalaSnooze", emoji: "🐨", singular: "koala daily snooze", plural: "koala daily snoozes", type: .duration, magnitude: 1_200),
        ReferenceUnit(id: "animals.penguinEggWatch", emoji: "🐧", singular: "emperor penguin egg-watch", plural: "emperor penguin egg-watches", type: .duration, magnitude: 93_600),

        ReferenceUnit(id: "animals.hummingbirdWings", emoji: "🐦", singular: "second of hummingbird wingbeats", plural: "seconds of hummingbird wingbeats", type: .reps, magnitude: 50),
        ReferenceUnit(id: "animals.hummingbirdHeart", emoji: "💓", singular: "minute of hummingbird heartbeats", plural: "minutes of hummingbird heartbeats", type: .reps, magnitude: 1_200),
        ReferenceUnit(id: "animals.woodpeckerDay", emoji: "🪵", singular: "woodpecker's day of pecking", plural: "woodpecker days of pecking", type: .reps, magnitude: 12_000),
    ]

    private static let cities: [ReferenceUnit] = [
        ReferenceUnit(id: "cities.manhattanBlock", emoji: "🏙", singular: "Manhattan block", plural: "Manhattan blocks", type: .distance, magnitude: 0.08),
        ReferenceUnit(id: "cities.manhattanLength", emoji: "🗽", singular: "trip down Manhattan", plural: "trips down Manhattan", type: .distance, magnitude: 21.6),
        ReferenceUnit(id: "cities.nycBoston", emoji: "🚗", singular: "NYC-to-Boston drive", plural: "NYC-to-Boston drives", type: .distance, magnitude: 346),
        ReferenceUnit(id: "cities.coastToCoast", emoji: "🇺🇸", singular: "coast-to-coast road trip", plural: "coast-to-coast road trips", type: .distance, magnitude: 4_500),

        ReferenceUnit(id: "cities.manholeCover", emoji: "🕳️", singular: "manhole cover", plural: "manhole covers", type: .weight, magnitude: 113),
        ReferenceUnit(id: "cities.smartCar", emoji: "🚙", singular: "Smart car", plural: "Smart cars", type: .weight, magnitude: 900),
        ReferenceUnit(id: "cities.cityBus", emoji: "🚌", singular: "city bus", plural: "city buses", type: .weight, magnitude: 12_000),
        ReferenceUnit(id: "cities.boeing747", emoji: "✈️", singular: "Boeing 747", plural: "Boeing 747s", type: .weight, magnitude: 180_000),

        ReferenceUnit(id: "cities.broadwayShow", emoji: "🎭", singular: "Broadway show", plural: "Broadway shows", type: .duration, magnitude: 150),
        ReferenceUnit(id: "cities.nycChicagoTrain", emoji: "🚆", singular: "NYC-to-Chicago train ride", plural: "NYC-to-Chicago train rides", type: .duration, magnitude: 1_140),
        ReferenceUnit(id: "cities.transSiberian", emoji: "🚂", singular: "Trans-Siberian railway trip", plural: "Trans-Siberian railway trips", type: .duration, magnitude: 10_080),

        ReferenceUnit(id: "cities.spanishSteps", emoji: "🪜", singular: "climb of Rome's Spanish Steps", plural: "climbs of Rome's Spanish Steps", type: .reps, magnitude: 135),
        ReferenceUnit(id: "cities.empireStateStairs", emoji: "🏢", singular: "Empire State Building stair climb", plural: "Empire State Building stair climbs", type: .reps, magnitude: 1_576),
        ReferenceUnit(id: "cities.marathonHighFives", emoji: "🙌", singular: "high-five line for the whole NYC Marathon field", plural: "high-five lines for the whole NYC Marathon field", type: .reps, magnitude: 59_000),
    ]

    private static let landmarks: [ReferenceUnit] = [
        ReferenceUnit(id: "landmarks.eiffelHeight", emoji: "🗼", singular: "Eiffel Tower height", plural: "Eiffel Tower heights", type: .distance, magnitude: 0.33),
        ReferenceUnit(id: "landmarks.goldenGate", emoji: "🌉", singular: "Golden Gate Bridge crossing", plural: "Golden Gate Bridge crossings", type: .distance, magnitude: 2.7),
        ReferenceUnit(id: "landmarks.panamaCanal", emoji: "🚢", singular: "Panama Canal transit", plural: "Panama Canal transits", type: .distance, magnitude: 82),
        ReferenceUnit(id: "landmarks.route66", emoji: "🛣️", singular: "Route 66 road trip", plural: "Route 66 road trips", type: .distance, magnitude: 3_940),
        ReferenceUnit(id: "landmarks.greatWall", emoji: "🇨🇳", singular: "Great Wall of China", plural: "Great Walls of China", type: .distance, magnitude: 21_196),

        ReferenceUnit(id: "landmarks.oscar", emoji: "🏆", singular: "Oscar statuette", plural: "Oscar statuettes", type: .weight, magnitude: 3.85),
        ReferenceUnit(id: "landmarks.libertyBell", emoji: "🔔", singular: "Liberty Bell", plural: "Liberty Bells", type: .weight, magnitude: 943),
        ReferenceUnit(id: "landmarks.bigBenBell", emoji: "🕰️", singular: "Big Ben bell", plural: "Big Ben bells", type: .weight, magnitude: 13_760),
        ReferenceUnit(id: "landmarks.statueOfLiberty", emoji: "🗽", singular: "Statue of Liberty", plural: "Statues of Liberty", type: .weight, magnitude: 204_000),
        ReferenceUnit(id: "landmarks.eiffelIron", emoji: "🗼", singular: "Eiffel Tower", plural: "Eiffel Towers", type: .weight, magnitude: 7_300_000),

        ReferenceUnit(id: "landmarks.oldFaithful", emoji: "⛲", singular: "Old Faithful wait", plural: "Old Faithful waits", type: .duration, magnitude: 90),
        ReferenceUnit(id: "landmarks.kilimanjaro", emoji: "🏔️", singular: "Kilimanjaro climb", plural: "Kilimanjaro climbs", type: .duration, magnitude: 8_640),
        ReferenceUnit(id: "landmarks.eiffelBuild", emoji: "🏗️", singular: "Eiffel Tower build", plural: "Eiffel Tower builds", type: .duration, magnitude: 1_144_800),

        ReferenceUnit(id: "landmarks.libertyCrown", emoji: "👑", singular: "Statue of Liberty crown climb", plural: "Statue of Liberty crown climbs", type: .reps, magnitude: 354),
        ReferenceUnit(id: "landmarks.toriiGates", emoji: "⛩️", singular: "walk through Fushimi Inari's torii gates", plural: "walks through Fushimi Inari's torii gates", type: .reps, magnitude: 10_000),
        ReferenceUnit(id: "landmarks.pyramidBlocks", emoji: "🔺", singular: "Great Pyramid's worth of blocks", plural: "Great Pyramids' worth of blocks", type: .reps, magnitude: 2_300_000),
    ]

    private static let food: [ReferenceUnit] = [
        ReferenceUnit(id: "food.baguette", emoji: "🥖", singular: "baguette laid end to end", plural: "baguettes laid end to end", type: .distance, magnitude: 0.00065),
        ReferenceUnit(id: "food.recordHotDog", emoji: "🌭", singular: "world-record hot dog", plural: "world-record hot dogs", type: .distance, magnitude: 0.2038),
        ReferenceUnit(id: "food.recordPizza", emoji: "🍕", singular: "world-record pizza", plural: "world-record pizzas", type: .distance, magnitude: 1.93),
        ReferenceUnit(id: "food.recordSausage", emoji: "🥓", singular: "world-record sausage", plural: "world-record sausages", type: .distance, magnitude: 62.75),

        ReferenceUnit(id: "food.watermelon", emoji: "🍉", singular: "watermelon", plural: "watermelons", type: .weight, magnitude: 9),
        ReferenceUnit(id: "food.parmesanWheel", emoji: "🧀", singular: "Parmesan wheel", plural: "Parmesan wheels", type: .weight, magnitude: 40),
        ReferenceUnit(id: "food.recordPumpkin", emoji: "🎃", singular: "record-breaking pumpkin", plural: "record-breaking pumpkins", type: .weight, magnitude: 1_247),
        ReferenceUnit(id: "food.potatoTruck", emoji: "🥔", singular: "semi-truckload of potatoes", plural: "semi-truckloads of potatoes", type: .weight, magnitude: 20_000),

        ReferenceUnit(id: "food.softBoiledEgg", emoji: "🥚", singular: "soft-boiled egg", plural: "soft-boiled eggs", type: .duration, magnitude: 6),
        ReferenceUnit(id: "food.brisket", emoji: "🥩", singular: "brisket smoke", plural: "brisket smokes", type: .duration, magnitude: 720),
        ReferenceUnit(id: "food.dryAgedSteak", emoji: "🍖", singular: "dry-aged steak", plural: "dry-aged steaks", type: .duration, magnitude: 40_320),
        ReferenceUnit(id: "food.parmesanAging", emoji: "🧀", singular: "year of Parmesan aging", plural: "years of Parmesan aging", type: .duration, magnitude: 525_600),

        ReferenceUnit(id: "food.sesameSeeds", emoji: "🍔", singular: "Big Mac bun's worth of sesame seeds", plural: "Big Mac buns' worth of sesame seeds", type: .reps, magnitude: 390),
        ReferenceUnit(id: "food.cornKernels", emoji: "🌽", singular: "ear's worth of corn kernels", plural: "ears' worth of corn kernels", type: .reps, magnitude: 800),
    ]

    private static let dinosaurs: [ReferenceUnit] = [
        ReferenceUnit(id: "dinosaurs.tRexLength", emoji: "🦖", singular: "T-Rex, nose to tail", plural: "T-Rexes, nose to tail", type: .distance, magnitude: 0.012),
        ReferenceUnit(id: "dinosaurs.argentinosaurusLength", emoji: "🦕", singular: "Argentinosaurus, nose to tail", plural: "Argentinosauruses, nose to tail", type: .distance, magnitude: 0.035),
        ReferenceUnit(id: "dinosaurs.plagneTrackway", emoji: "🦕", singular: "walk along the Plagne sauropod trackway", plural: "walks along the Plagne sauropod trackway", type: .distance, magnitude: 0.155),
        ReferenceUnit(id: "dinosaurs.calOrckoWall", emoji: "🦶", singular: "Cal Orck'o footprint wall", plural: "Cal Orck'o footprint walls", type: .distance, magnitude: 1.5),
        ReferenceUnit(id: "dinosaurs.dinosaurRidge", emoji: "🦴", singular: "round trip on Colorado's Dinosaur Ridge", plural: "round trips on Colorado's Dinosaur Ridge", type: .distance, magnitude: 3.2),
        ReferenceUnit(id: "dinosaurs.dinosaurTrail", emoji: "🦴", singular: "loop of Alberta's Dinosaur Trail", plural: "loops of Alberta's Dinosaur Trail", type: .distance, magnitude: 48),
        ReferenceUnit(id: "dinosaurs.jurassicCoast", emoji: "🌊", singular: "Jurassic Coast", plural: "Jurassic Coasts", type: .distance, magnitude: 154),

        ReferenceUnit(id: "dinosaurs.velociraptor", emoji: "🦖", singular: "Velociraptor", plural: "Velociraptors", type: .weight, magnitude: 15),
        ReferenceUnit(id: "dinosaurs.gallimimus", emoji: "🦕", singular: "Gallimimus", plural: "Gallimimus", type: .weight, magnitude: 440),
        ReferenceUnit(id: "dinosaurs.tRex", emoji: "🦖", singular: "T-Rex", plural: "T-Rexes", type: .weight, magnitude: 8_000),
        ReferenceUnit(id: "dinosaurs.argentinosaurus", emoji: "🦕", singular: "Argentinosaurus", plural: "Argentinosauruses", type: .weight, magnitude: 70_000),

        ReferenceUnit(id: "dinosaurs.jurassicPark", emoji: "🎬", singular: "Jurassic Park viewing", plural: "Jurassic Park viewings", type: .duration, magnitude: 127),
        ReferenceUnit(id: "dinosaurs.jurassicMarathon", emoji: "🍿", singular: "six-film Jurassic marathon", plural: "six-film Jurassic marathons", type: .duration, magnitude: 747),
        ReferenceUnit(id: "dinosaurs.protoceratopsEgg", emoji: "🥚", singular: "Protoceratops egg hatching", plural: "Protoceratops egg hatchings", type: .duration, magnitude: 119_520),

        ReferenceUnit(id: "dinosaurs.tRexTeeth", emoji: "🦷", singular: "T-Rex mouthful of teeth", plural: "T-Rex mouthfuls of teeth", type: .reps, magnitude: 60),
        ReferenceUnit(id: "dinosaurs.triceratopsTeeth", emoji: "🦴", singular: "Triceratops mouthful of teeth", plural: "Triceratops mouthfuls of teeth", type: .reps, magnitude: 800),
    ]
}
