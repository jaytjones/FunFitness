//
//  NowTrackingTests.swift
//  FunFitnessTests
//
//  TestFlight FB-0003: the pinned "now tracking" bar's text for walks/runs and strength sessions.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Now tracking bar")
@MainActor
struct NowTrackingTests {

    private func content(
        tracker: WorkoutTracker.Phase = .idle,
        strength: StrengthSessionManager.Phase = .idle,
        sets: Int = 0,
        rest: TimeInterval = 0
    ) -> NowTrackingContent? {
        NowTrackingContent.make(
            trackerPhase: tracker, kindName: "Walk", distanceKm: 1.6, movingSeconds: 1_122,
            strengthPhase: strength, setCount: sets, restRemaining: rest, strengthSeconds: 600,
            pref: .imperial
        )
    }

    private var distance: String { UnitConverter.distanceString(1.6, pref: .imperial) }

    @Test func nothingRunningShowsNothing() {
        #expect(content() == nil)
    }

    @Test func activeWalkShowsDistanceAndTime() throws {
        let walk = try #require(content(tracker: .active))
        #expect(walk.destination == .tracker)
        #expect(walk.title == "Walk")
        #expect(walk.detail == "\(distance) · \(UnitConverter.elapsedString(1_122))")
        #expect(walk.isLive)
    }

    @Test func pausedAndFinishedWalksSaySo() throws {
        let paused = try #require(content(tracker: .paused))
        #expect(paused.title == "Walk paused")
        #expect(!paused.isLive)
        let finished = try #require(content(tracker: .finished))
        #expect(finished.title == "Walk finished")
        #expect(finished.detail == "Tap to review and save")
    }

    @Test func strengthShowsSetsAndRestOrTime() throws {
        let resting = try #require(content(strength: .active, sets: 3, rest: 45))
        #expect(resting.destination == .strength)
        #expect(resting.detail == "3 sets · Rest \(UnitConverter.elapsedString(45))")

        let lifting = try #require(content(strength: .active, sets: 1))
        #expect(lifting.detail == "1 set · \(UnitConverter.elapsedString(600))")

        let done = try #require(content(strength: .finished, sets: 3))
        #expect(done.title == "Strength session done")
    }
}
