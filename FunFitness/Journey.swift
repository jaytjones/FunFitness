//
//  Journey.swift
//  FunFitness
//
//  Journey Mode (3.1): walk or run a real route, one logged mile at a time. Journeys are bundled,
//  pack-independent data (`Journeys.json`), not CloudKit records; only the person's choice is
//  stored (`UserProfile.activeJourneyID` + `journeyStartedAt`). See
//  docs/20261010_3.1_design_decisions.md §4.
//
//  Jay's decision (2026-11-06): ship both the Texas Triangle and the Appalachian Trail, with a
//  picker. Progress counts distance logged since the journey started, so starting one is a
//  fresh adventure rather than finishing instantly from lifetime totals. Checkpoint miles and
//  facts are approximate and need the same sourced fact-check as the 2.3 copy before release.
//

import Foundation

nonisolated struct Checkpoint: Equatable, Identifiable, Sendable {
    let name: String
    /// Distance from the start, in km.
    let cumulativeKm: Double
    let latitude: Double
    let longitude: Double
    let fact: String

    var id: String { name }
}

nonisolated struct Journey: Equatable, Identifiable, Sendable {
    /// Persisted in `UserProfile.activeJourneyID`, so never rename.
    let id: String
    let name: String
    let emoji: String
    let blurb: String
    /// Ordered by distance; the first is the start (0 km), the last is the finish.
    let checkpoints: [Checkpoint]

    var totalKm: Double { checkpoints.last?.cumulativeKm ?? 0 }
}

// MARK: - Catalog

nonisolated enum JourneyCatalog {

    static let kmPerMile = 1.60934

    /// The JSON shape: checkpoint distances are authored in miles, as published for both routes.
    private struct Entry: Codable {
        struct Stop: Codable {
            let name: String
            let miles: Double
            let latitude: Double
            let longitude: Double
            let fact: String
        }
        let id: String
        let name: String
        let emoji: String
        let blurb: String
        let checkpoints: [Stop]
    }

    /// Decodes journey JSON, sorting each journey's checkpoints by distance.
    static func decode(_ data: Data) throws -> [Journey] {
        try JSONDecoder().decode([Entry].self, from: data).map { entry in
            Journey(
                id: entry.id,
                name: entry.name,
                emoji: entry.emoji,
                blurb: entry.blurb,
                checkpoints: entry.checkpoints
                    .map { Checkpoint(name: $0.name, cumulativeKm: $0.miles * kmPerMile, latitude: $0.latitude, longitude: $0.longitude, fact: $0.fact) }
                    .sorted { $0.cumulativeKm < $1.cumulativeKm }
            )
        }
    }

    static let all: [Journey] = {
        guard let url = Bundle.main.url(forResource: "Journeys", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let journeys = try? decode(data) else { return [] }
        return journeys
    }()

    static func journey(id: String) -> Journey? {
        all.first { $0.id == id }
    }
}

// MARK: - Progress (pure)

nonisolated struct JourneyProgress: Equatable, Sendable {
    let journey: Journey
    /// Distance covered since the journey started, capped at the journey's length.
    let distanceKm: Double
    /// Checkpoints passed so far, including the start.
    let reached: [Checkpoint]
    /// The next checkpoint, or nil once finished.
    let next: Checkpoint?

    var isComplete: Bool { next == nil }
    var latest: Checkpoint? { reached.last }
    var fraction: Double { journey.totalKm > 0 ? min(1, distanceKm / journey.totalKm) : 0 }
    var kmToNext: Double { next.map { max(0, $0.cumulativeKm - distanceKm) } ?? 0 }

    /// Where on the map the person is: straight-line interpolation between the last checkpoint
    /// passed and the next one.
    var position: (latitude: Double, longitude: Double)? {
        guard let from = latest else { return nil }
        guard let to = next else { return (from.latitude, from.longitude) }
        let span = to.cumulativeKm - from.cumulativeKm
        let t = span > 0 ? min(1, max(0, (distanceKm - from.cumulativeKm) / span)) : 0
        return (from.latitude + (to.latitude - from.latitude) * t,
                from.longitude + (to.longitude - from.longitude) * t)
    }
}

nonisolated enum JourneyEngine {

    /// Progress along `journey` after `distanceKm`.
    static func progress(journey: Journey, distanceKm: Double) -> JourneyProgress {
        let covered = min(max(0, distanceKm), journey.totalKm)
        // A tiny relative slack so landing exactly on a checkpoint counts (like Milestone.isReached).
        let reached = journey.checkpoints.filter { $0.cumulativeKm <= covered * (1 + 1e-9) + 1e-9 }
        let next = journey.checkpoints.first { $0.cumulativeKm > covered * (1 + 1e-9) + 1e-9 }
        return JourneyProgress(journey: journey, distanceKm: covered, reached: reached, next: next)
    }

    /// Distance logged on or after `start`, from (date, km) pairs of distance entries.
    static func distanceSince(_ start: Date, entries: [(date: Date, km: Double)]) -> Double {
        entries.filter { $0.date >= start }.reduce(0) { $0 + max(0, $1.km) }
    }

    /// Checkpoints reached but not celebrated yet, given how many (including the start) already
    /// were. The start is never celebrated. Used for the "you reached…" moment (3.2).
    static func checkpointsToCelebrate(journey: Journey, distanceKm: Double, alreadyCelebrated: Int) -> [Checkpoint] {
        let reached = progress(journey: journey, distanceKm: distanceKm).reached
        return Array(reached.dropFirst(max(1, alreadyCelebrated)))
    }

    /// Checkpoints newly passed going from `previousKm` to `newKm` (for a "you reached…" moment).
    static func newlyReached(journey: Journey, previousKm: Double, newKm: Double) -> [Checkpoint] {
        let before = Set(progress(journey: journey, distanceKm: previousKm).reached.map(\.id))
        return progress(journey: journey, distanceKm: newKm).reached.filter { !before.contains($0.id) }
    }
}
