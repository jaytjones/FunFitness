//
//  HeartRateTests.swift
//  FunFitnessTests
//
//  3.1 B2 heart rate: summarizing Health readings over a tracked walk/run's moving time, and
//  keeping the summary on the saved entry.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: 1_000_000 + seconds)
}

private func sample(_ bpm: Double, at seconds: TimeInterval) -> HeartRateSample {
    HeartRateSample(bpm: bpm, date: date(seconds))
}

@Suite("Heart rate summary")
struct HeartRateMathTests {

    @Test func averagesAndFindsTheMaximum() throws {
        let samples = [sample(120, at: 10), sample(140, at: 20), sample(160, at: 30)]
        let summary = try #require(HeartRateMath.summary(samples: samples, start: date(0), end: date(60)))
        #expect(summary.average == 140)
        #expect(summary.maximum == 160)
    }

    @Test func noSamplesMeansNoSummary() {
        #expect(HeartRateMath.summary(samples: [], start: date(0), end: date(60)) == nil)
    }

    @Test func ignoresReadingsOutsideTheWorkout() throws {
        let samples = [sample(70, at: -30), sample(130, at: 30), sample(75, at: 90)]
        let summary = try #require(HeartRateMath.summary(samples: samples, start: date(0), end: date(60)))
        #expect(summary.average == 130)
        #expect(summary.maximum == 130)
    }

    @Test func skipsPausedStretches() throws {
        let samples = [sample(150, at: 10), sample(90, at: 40), sample(150, at: 70)]
        let pause = DateInterval(start: date(30), end: date(50))
        let summary = try #require(HeartRateMath.summary(samples: samples, start: date(0), end: date(100), pauses: [pause]))
        #expect(summary.average == 150)
    }

    @Test func dropsImplausibleReadings() throws {
        let samples = [sample(0, at: 10), sample(135, at: 20), sample(400, at: 30)]
        let summary = try #require(HeartRateMath.summary(samples: samples, start: date(0), end: date(60)))
        #expect(summary.average == 135)
        #expect(summary.maximum == 135)
    }

    @Test func onlyPausedOrImplausibleReadingsMeansNoSummary() {
        let samples = [sample(140, at: 40), sample(500, at: 10)]
        let pause = DateInterval(start: date(30), end: date(50))
        #expect(HeartRateMath.summary(samples: samples, start: date(0), end: date(60), pauses: [pause]) == nil)
    }

    @Test func displaysWholeBeatsPerMinute() {
        let summary = HeartRateSummary(average: 131.6, maximum: 158.2)
        #expect(summary.averageText == "132")
        #expect(summary.maximumText == "158")
    }
}

@Suite("Tracked workout heart rate")
@MainActor
struct TrackedHeartRateSavingTests {
    // Kept as a property so the in-memory store outlives each test's context.
    let container: ModelContainer

    init() throws {
        let schema = Schema([UserProfile.self, ActivityLog.self, UnlockedAchievement.self, RouteSummary.self, WorkoutSession.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    private func result() -> TrackedWorkoutResult {
        TrackedWorkoutResult(
            kind: .walk, startedAt: date(0), endedAt: date(600), distanceMeters: 800,
            movingSeconds: 600, points: [], pauseIntervals: []
        )
    }

    @Test func savesTheHeartRateOnTheEntry() throws {
        let context = container.mainContext
        ActivityWriter.logTracked(
            result(), heartRate: HeartRateSummary(average: 118, maximum: 141),
            context: context, viewModel: AppViewModel(), writeBackToHealth: false
        )
        let log = try #require(try context.fetch(FetchDescriptor<ActivityLog>()).first)
        #expect(log.avgHeartRate == 118)
        #expect(log.maxHeartRate == 141)
    }

    @Test func noHeartRateLeavesTheFieldsEmpty() throws {
        let context = container.mainContext
        ActivityWriter.logTracked(result(), context: context, viewModel: AppViewModel(), writeBackToHealth: false)
        let log = try #require(try context.fetch(FetchDescriptor<ActivityLog>()).first)
        #expect(log.avgHeartRate == nil)
        #expect(log.maxHeartRate == nil)
    }
}
