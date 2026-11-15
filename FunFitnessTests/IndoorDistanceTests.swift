//
//  IndoorDistanceTests.swift
//  FunFitnessTests
//
//  FB-0020: a treadmill walk tracked on iPhone got no GPS distance, so it couldn't be saved and
//  never reached Health. Indoor (picked at start) now counts distance from the step counter.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Indoor (treadmill) distance")
@MainActor
struct IndoorDistanceTests {

    @Test func stepDistanceSkipsPausedTime() {
        var steps = StepDistance()
        steps.update(total: 100)
        steps.isPaused = true
        steps.update(total: 150)   // walked while paused: not counted
        steps.isPaused = false
        steps.update(total: 220)
        #expect(steps.countedMeters == 170)
    }

    @Test func stepDistanceIgnoresTotalsGoingBackwards() {
        var steps = StepDistance()
        steps.update(total: 200)
        steps.update(total: 180)
        steps.update(total: 250)
        #expect(steps.countedMeters == 250)
    }

    @Test func stepDistanceCatchesUpAfterAGap() {
        // Updates stop while the app is suspended; the next total covers the gap.
        var steps = StepDistance()
        steps.update(total: 300)
        steps.update(total: 1_900)
        #expect(steps.countedMeters == 1_900)
    }

    @Test func outdoorIsTheDefault() {
        let result = TrackedWorkoutResult(
            kind: .walk, startedAt: Date(), endedAt: Date().addingTimeInterval(600),
            distanceMeters: 800, movingSeconds: 600, points: [], pauseIntervals: []
        )
        #expect(!result.isIndoor)
    }

    @Test func indoorTreadmillResultIsSavable() {
        let start = Date()
        let result = TrackedWorkoutResult(
            kind: .walk, startedAt: start, endedAt: start.addingTimeInterval(1_200),
            distanceMeters: 1_600, movingSeconds: 1_200, points: [], pauseIntervals: [], isIndoor: true
        )
        #expect(result.isSavable)
        #expect(result.isIndoor)
    }

    @Test func noStepsIsntSavable() {
        let start = Date()
        let result = TrackedWorkoutResult(
            kind: .walk, startedAt: start, endedAt: start.addingTimeInterval(30),
            distanceMeters: 0, movingSeconds: 30, points: [], pauseIntervals: [], isIndoor: true
        )
        #expect(!result.isSavable)
    }
}
