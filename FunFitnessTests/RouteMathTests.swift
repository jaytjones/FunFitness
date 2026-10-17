//
//  RouteMathTests.swift
//  FunFitnessTests
//
//  3.1 B1a live walk/run tracking: GPS filtering, distance/moving-time accumulation across
//  pauses, pace, downsampling, polyline encoding, formatting, and saving a tracked workout.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

// Builds fixes walking due north from a fixed origin.
private let origin = (lat: 30.2672, lon: -97.7431)   // Austin
private let metersPerDegreeLat = 6_371_000.0 * .pi / 180

private func point(northMeters: Double, eastMeters: Double = 0, at seconds: TimeInterval, accuracy: Double = 5) -> RoutePoint {
    RoutePoint(
        latitude: origin.lat + northMeters / metersPerDegreeLat,
        longitude: origin.lon + eastMeters / (metersPerDegreeLat * cos(origin.lat * .pi / 180)),
        timestamp: Date(timeIntervalSince1970: 1_000_000 + seconds),
        horizontalAccuracy: accuracy
    )
}

private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: 1_000_000 + seconds)
}

@Suite("Route math")
@MainActor
struct RouteMathTests {

    // MARK: Geometry

    @Test func oneDegreeOfLatitudeIsAbout111Km() {
        let d = RouteMath.distance(lat1: 0, lon1: 0, lat2: 1, lon2: 0)
        #expect(abs(d - 111_195) < 1)
    }

    @Test func rejectsInvalidAndImpreciseFixes() {
        #expect(RouteMath.isAccurate(point(northMeters: 0, at: 0, accuracy: 10)))
        #expect(!RouteMath.isAccurate(point(northMeters: 0, at: 0, accuracy: -1)))
        #expect(!RouteMath.isAccurate(point(northMeters: 0, at: 0, accuracy: 60)))
    }

    @Test func paceNeedsFiftyMeters() {
        #expect(RouteMath.paceSecondsPerKm(distanceMeters: 40, movingSeconds: 30) == nil)
        #expect(RouteMath.paceSecondsPerKm(distanceMeters: 1000, movingSeconds: 360) == 360)
    }

    // MARK: Accumulator

    @Test func sumsDistanceAlongARoute() {
        var acc = RouteAccumulator(kind: .walk)
        acc.start(at: date(0))
        for i in 0...10 { acc.add(point(northMeters: Double(i) * 10, at: Double(i) * 8)) }
        #expect(abs(acc.distanceMeters - 100) < 0.5)
        #expect(acc.points.count == 11)
    }

    @Test func ignoresFixesBeforeStart() {
        var acc = RouteAccumulator(kind: .walk)
        let accepted1 = acc.add(point(northMeters: 0, at: 0))
        #expect(!accepted1)
        #expect(acc.points.isEmpty)
    }

    @Test func dropsInaccurateFixesJumpsAndJitter() {
        var acc = RouteAccumulator(kind: .walk)
        acc.start(at: date(0))
        acc.add(point(northMeters: 0, at: 0))
        let accepted2 = acc.add(point(northMeters: 10, at: 8, accuracy: 80))
        #expect(!accepted2)  // too imprecise
        let accepted3 = acc.add(point(northMeters: 500, at: 10))
        #expect(!accepted3)  // 500 m in 10 s
        let accepted4 = acc.add(point(northMeters: 1, at: 12))
        #expect(!accepted4)  // standing-still jitter
        let accepted5 = acc.add(point(northMeters: 10, at: 16))
        #expect(accepted5)
        #expect(abs(acc.distanceMeters - 10) < 0.1)
    }

    @Test func runAllowsFasterMovementThanWalk() {
        var walk = RouteAccumulator(kind: .walk)
        var run = RouteAccumulator(kind: .run)
        walk.start(at: date(0)); run.start(at: date(0))
        walk.add(point(northMeters: 0, at: 0)); run.add(point(northMeters: 0, at: 0))
        // 6 m/s: a quick run, too fast for a walk.
        let accepted6 = walk.add(point(northMeters: 60, at: 10))
        #expect(!accepted6)
        let accepted7 = run.add(point(northMeters: 60, at: 10))
        #expect(accepted7)
    }

    @Test func pauseDoesNotJoinSegmentsOrCountTime() {
        var acc = RouteAccumulator(kind: .walk)
        acc.start(at: date(0))
        acc.add(point(northMeters: 0, at: 0))
        acc.add(point(northMeters: 50, at: 40))
        acc.pause(at: date(60))
        let accepted8 = acc.add(point(northMeters: 80, at: 90))
        #expect(!accepted8)  // ignored while paused
        acc.resume(at: date(300))
        // Drove 1 km while paused: the first fix after resuming starts a new segment.
        acc.add(point(northMeters: 1_050, at: 301))
        acc.add(point(northMeters: 1_100, at: 340))
        #expect(abs(acc.distanceMeters - 100) < 0.5)
        #expect(acc.movingSeconds(at: date(340)) == 60 + 40)
        #expect(acc.pauseIntervals == [DateInterval(start: date(60), end: date(300))])
    }

    @Test func finishClosesAnOpenPause() {
        var acc = RouteAccumulator(kind: .run)
        acc.start(at: date(0))
        acc.pause(at: date(100))
        acc.finish(at: date(160))
        #expect(acc.movingSeconds(at: date(999)) == 100)
        #expect(acc.pauseIntervals == [DateInterval(start: date(100), end: date(160))])
    }

    @Test func finishWhileMovingRecordsNoPause() {
        var acc = RouteAccumulator(kind: .walk)
        acc.start(at: date(0))
        acc.finish(at: date(120))
        #expect(acc.movingSeconds(at: date(500)) == 120)
        #expect(acc.pauseIntervals.isEmpty)
    }

    // MARK: Downsampling

    @Test func straightLineCollapsesToEndpoints() {
        let line = (0..<1_000).map { point(northMeters: Double($0) * 3, at: Double($0)) }
        let simplified = RouteMath.downsample(line)
        #expect(simplified.count == 2)
        #expect(simplified.first == line.first)
        #expect(simplified.last == line.last)
    }

    @Test func zigzagIsCappedAndKeepsEndpoints() {
        let zigzag = (0..<3_000).map { i in
            point(northMeters: Double(i) * 3, eastMeters: i.isMultiple(of: 2) ? 0 : 30, at: Double(i))
        }
        let simplified = RouteMath.downsample(zigzag, maxPoints: 500)
        #expect(simplified.count == 500)
        #expect(simplified.first == zigzag.first)
        #expect(simplified.last == zigzag.last)
    }

    @Test func shortRoutesAreUnchanged() {
        let two = [point(northMeters: 0, at: 0), point(northMeters: 10, at: 5)]
        #expect(RouteMath.downsample(two) == two)
    }

    // MARK: Polyline

    @Test func polylineRoundTrips() {
        let points = (0..<20).map { point(northMeters: Double($0) * 7, eastMeters: Double($0 % 3), at: Double($0)) }
        let decoded = RoutePolyline.decode(RoutePolyline.encode(points))
        #expect(decoded.count == points.count)
        for (d, p) in zip(decoded, points) {
            #expect(d.latitude == p.latitude)
            #expect(d.longitude == p.longitude)
        }
    }

    @Test func polylineRejectsUnknownOrMalformedData() {
        #expect(RoutePolyline.decode(Data([9, 0, 0])).isEmpty)
        #expect(RoutePolyline.decode(Data([RoutePolyline.version, 1, 2, 3])).isEmpty)
        #expect(RoutePolyline.decode(RoutePolyline.encode([])).isEmpty)
    }

    // MARK: Formatting

    @Test func elapsedStringFormats() {
        #expect(UnitConverter.elapsedString(0) == "0:00")
        #expect(UnitConverter.elapsedString(65.9) == "1:05")
        #expect(UnitConverter.elapsedString(3_725) == "1:02:05")
    }

    @Test func paceStringUsesDisplayUnits() {
        #expect(UnitConverter.paceString(secondsPerKm: 300, pref: .metric) == "5:00 /km")
        // 300 s/km × 1.60934 = 482.8 s/mi
        #expect(UnitConverter.paceString(secondsPerKm: 300, pref: .imperial) == "8:03 /mi")
        #expect(UnitConverter.paceString(secondsPerKm: nil, pref: .metric) == "--:-- /km")
        #expect(UnitConverter.paceString(secondsPerKm: 7_000, pref: .metric) == "--:-- /km")
    }

    @Test func tinyWorkoutsAreNotSavable() {
        let result = TrackedWorkoutResult(
            kind: .walk, startedAt: date(0), endedAt: date(60), distanceMeters: 4,
            movingSeconds: 60, points: [], pauseIntervals: []
        )
        #expect(!result.isSavable)
    }
}

// MARK: - Saving

@Suite("Tracked workout saving")
@MainActor
struct TrackedWorkoutSavingTests {
    // Kept as a property so the in-memory store outlives each test's context.
    let container: ModelContainer

    init() throws {
        let schema = Schema([UserProfile.self, ActivityLog.self, UnlockedAchievement.self, RouteSummary.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    private func sampleResult() -> TrackedWorkoutResult {
        let points = (0...100).map { point(northMeters: Double($0) * 25, at: Double($0) * 6) }
        return TrackedWorkoutResult(
            kind: .run, startedAt: date(0), endedAt: date(700), distanceMeters: 2_500,
            movingSeconds: 600, points: points, pauseIntervals: [DateInterval(start: date(300), end: date(400))]
        )
    }

    @Test func logsATrackedDistanceEntryWithItsRoute() throws {
        let context = container.mainContext
        let vm = AppViewModel()
        ActivityWriter.logTracked(sampleResult(), context: context, viewModel: vm, writeBackToHealth: false)

        let logs = try context.fetch(FetchDescriptor<ActivityLog>())
        let routes = try context.fetch(FetchDescriptor<RouteSummary>())
        #expect(logs.count == 1)
        #expect(routes.count == 1)
        let log = try #require(logs.first)
        let route = try #require(routes.first)
        #expect(log.activityType == .distance)
        #expect(log.source == .tracked)
        #expect(log.value == 2.5)
        #expect(log.loggedAt == date(700))
        #expect(route.activityID == log.id)
        #expect(route.kind == .run)
        #expect(route.movingSeconds == 600)
        // A straight line downsamples to its endpoints.
        #expect(route.coordinates.count == 2)
        #expect(vm.totalDistance == 2.5)
    }

    @Test func deletingATrackedEntryDeletesItsRoute() throws {
        let context = container.mainContext
        let vm = AppViewModel()
        ActivityWriter.logTracked(sampleResult(), context: context, viewModel: vm, writeBackToHealth: false)
        let log = try #require(try context.fetch(FetchDescriptor<ActivityLog>()).first)

        ActivityWriter.delete(log, context: context, viewModel: vm)

        #expect(try context.fetch(FetchDescriptor<ActivityLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<RouteSummary>()).isEmpty)
        #expect(vm.totalDistance == 0)
    }
}
