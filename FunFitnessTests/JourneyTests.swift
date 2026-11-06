//
//  JourneyTests.swift
//  FunFitnessTests
//
//  Journey Mode (3.1): the bundled journeys and JourneyEngine progress.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Journey Mode")
@MainActor
struct JourneyTests {

    private let mile = JourneyCatalog.kmPerMile

    private var sample: Journey {
        Journey(id: "test", name: "Test", emoji: "🧪", blurb: "", checkpoints: [
            Checkpoint(name: "A", cumulativeKm: 0, latitude: 0, longitude: 0, fact: "a"),
            Checkpoint(name: "B", cumulativeKm: 10, latitude: 0, longitude: 10, fact: "b"),
            Checkpoint(name: "C", cumulativeKm: 30, latitude: 10, longitude: 10, fact: "c"),
        ])
    }

    @Test func bothJourneysShipWithOrderedCheckpoints() throws {
        let ids = JourneyCatalog.all.map(\.id)
        #expect(ids.contains("texas-triangle"))
        #expect(ids.contains("appalachian-trail"))
        for journey in JourneyCatalog.all {
            let distances = journey.checkpoints.map(\.cumulativeKm)
            #expect(distances.first == 0, "\(journey.id) must start at 0")
            #expect(distances == distances.sorted(), "\(journey.id) out of order")
            #expect(Set(journey.checkpoints.map(\.id)).count == journey.checkpoints.count, "\(journey.id) duplicate names")
            #expect(journey.checkpoints.allSatisfy { !$0.fact.isEmpty })
            #expect(journey.checkpoints.allSatisfy { (-90...90).contains($0.latitude) && (-180...180).contains($0.longitude) })
        }
        // The AT should match the published ~2,197 mi (and the D10 badge at 2,190 mi).
        let at = try #require(JourneyCatalog.journey(id: "appalachian-trail"))
        #expect(abs(at.totalKm / mile - 2197.4) < 1)
        let texas = try #require(JourneyCatalog.journey(id: "texas-triangle"))
        #expect(abs(texas.totalKm / mile - 714) < 1)
    }

    @Test func progressBetweenCheckpoints() {
        let progress = JourneyEngine.progress(journey: sample, distanceKm: 15)
        #expect(progress.reached.map(\.name) == ["A", "B"])
        #expect(progress.next?.name == "C")
        #expect(abs(progress.kmToNext - 15) < 1e-9)
        #expect(abs(progress.fraction - 0.5) < 1e-9)
        #expect(progress.isComplete == false)
        // A quarter of the way from B (0,10) to C (10,10).
        #expect(progress.position.map { abs($0.latitude - 2.5) < 1e-9 && abs($0.longitude - 10) < 1e-9 } == true)
    }

    @Test func landingExactlyOnACheckpointCounts() {
        let progress = JourneyEngine.progress(journey: sample, distanceKm: 10)
        #expect(progress.latest?.name == "B")
    }

    @Test func progressCapsAtTheFinish() {
        let progress = JourneyEngine.progress(journey: sample, distanceKm: 500)
        #expect(progress.isComplete)
        #expect(progress.distanceKm == 30)
        #expect(progress.fraction == 1)
        #expect(progress.kmToNext == 0)
        #expect(progress.position.map { $0.latitude == 10 && $0.longitude == 10 } == true)
    }

    @Test func onlyDistanceSinceTheStartCounts() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let km = JourneyEngine.distanceSince(start, entries: [
            (date: start.addingTimeInterval(-60), km: 100),   // before the journey
            (date: start, km: 5),
            (date: start.addingTimeInterval(3_600), km: 2.5),
        ])
        #expect(abs(km - 7.5) < 1e-9)
    }

    @Test func newlyReachedListsCrossedCheckpoints() {
        #expect(JourneyEngine.newlyReached(journey: sample, previousKm: 5, newKm: 31).map(\.name) == ["B", "C"])
        #expect(JourneyEngine.newlyReached(journey: sample, previousKm: 11, newKm: 12).isEmpty)
    }

    @Test func celebratesEachNewCheckpointOnceAndNeverTheStart() {
        // At the start: nothing to celebrate.
        #expect(JourneyEngine.checkpointsToCelebrate(journey: sample, distanceKm: 0, alreadyCelebrated: 0).isEmpty)
        // Past B, nothing celebrated yet (count 1 = only the start).
        #expect(JourneyEngine.checkpointsToCelebrate(journey: sample, distanceKm: 12, alreadyCelebrated: 1).map(\.name) == ["B"])
        // B already celebrated (A + B = 2): nothing new until C.
        #expect(JourneyEngine.checkpointsToCelebrate(journey: sample, distanceKm: 20, alreadyCelebrated: 2).isEmpty)
        #expect(JourneyEngine.checkpointsToCelebrate(journey: sample, distanceKm: 30, alreadyCelebrated: 2).map(\.name) == ["C"])
    }
}
