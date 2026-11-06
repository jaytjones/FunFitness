//
//  WatchConnectorTests.swift
//  FunFitnessTests
//
//  The iPhone side of the Apple Watch link (3.1): message coding and how entries from the
//  Watch are saved. Serialized because the connector is a shared instance.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

@Suite("WatchConnector", .serialized)
@MainActor
struct WatchConnectorTests {

    private func makeStore() throws -> (ModelContainer, AppViewModel) {
        UserDefaults.standard.removeObject(forKey: "watchProcessedLogIDs")
        let container = try ModelContainer(
            for: ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self, CustomExercise.self, RouteSummary.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = AppViewModel()
        WatchConnector.shared.configure(context: container.mainContext, viewModel: viewModel)
        return (container, viewModel)
    }

    @Test func messagesRoundTrip() {
        let log = WatchQuickLog(id: UUID(), kind: .lift, value: 61.2, reps: 8, exerciseID: "bench-press", date: Date(timeIntervalSince1970: 1_000))
        #expect(WatchQuickLog.decode(log.encoded()) == log)

        let context = WatchContext(usesMetric: true, exercises: [WatchExercise(id: "push-up", name: "Push-Up", kind: .bodyweight)])
        #expect(WatchContext.decode(context.encoded()) == context)
        #expect(WatchQuickLog.decode(["nope": 1]) == nil)
    }

    @Test func liftFromWatchIsSavedWithItsExercise() throws {
        let (container, viewModel) = try makeStore()
        WatchConnector.shared.receive(WatchQuickLog(id: UUID(), kind: .lift, value: 60, reps: 10, exerciseID: "bench-press", date: Date()))

        let logs = try container.mainContext.fetch(FetchDescriptor<ActivityLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.activityType == .weight)
        #expect(logs.first?.reps == 10)
        #expect(logs.first?.exerciseID == "bench-press")
        #expect(viewModel.activities.count == 1)
    }

    @Test func redeliveredEntryIsSavedOnce() throws {
        let (container, viewModel) = try makeStore()
        defer { withExtendedLifetime(viewModel) {} }   // the connector holds it weakly
        let log = WatchQuickLog(id: UUID(), kind: .duration, value: 30, date: Date())
        WatchConnector.shared.receive(log)
        WatchConnector.shared.receive(log)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<ActivityLog>()) == 1)
    }

    @Test func watchRunIsTaggedAndSkippedIfHealthAlreadyImportedIt() throws {
        let (container, viewModel) = try makeStore()
        defer { withExtendedLifetime(viewModel) {} }   // the connector holds it weakly
        let uuid = UUID()
        WatchConnector.shared.receive(WatchQuickLog(id: UUID(), kind: .distance, value: 5, date: Date(), healthKitUUID: uuid, averageHeartRate: 140))
        let logs = try container.mainContext.fetch(FetchDescriptor<ActivityLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.healthKitUUID == uuid)
        #expect(logs.first?.source == .healthKit)
        #expect(logs.first?.avgHeartRate == 140)

        // The same workout again (e.g. Health import got it first) isn't counted twice.
        WatchConnector.shared.receive(WatchQuickLog(id: UUID(), kind: .distance, value: 5, date: Date(), healthKitUUID: uuid))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<ActivityLog>()) == 1)
    }

    @Test func trackedWatchRunGetsARoute() throws {
        let (container, viewModel) = try makeStore()
        defer { withExtendedLifetime(viewModel) {} }   // the connector holds it weakly
        let points = [
            RoutePoint(latitude: 30.0, longitude: -97.0, timestamp: Date(), horizontalAccuracy: 5),
            RoutePoint(latitude: 30.01, longitude: -97.0, timestamp: Date(), horizontalAccuracy: 5),
        ]
        WatchConnector.shared.receive(WatchQuickLog(
            id: UUID(), kind: .distance, value: 1.1, date: Date(), healthKitUUID: UUID(),
            routePolyline: RoutePolyline.encode(points), movingSeconds: 600, startDate: Date().addingTimeInterval(-660),
            trackedKind: .run
        ))
        let log = try #require(try container.mainContext.fetch(FetchDescriptor<ActivityLog>()).first)
        #expect(log.source == .tracked)
        let route = try #require(try container.mainContext.fetch(FetchDescriptor<RouteSummary>()).first)
        #expect(route.activityID == log.id)
        #expect(route.kind == .run)
        #expect(route.movingSeconds == 600)
        #expect(route.coordinates.count == 2)
    }

    @Test func watchEffortPointsResetInANewWeek() {
        let cal = Calendar.current
        let now = Date()
        var context = WatchContext(usesMetric: false, exercises: [])
        context.effortPoints = 90
        context.effortTarget = 150
        context.updatedAt = now
        #expect(context.effortPoints(asOf: now) == 90)
        #expect(abs(context.effortFraction(asOf: now) - 0.6) < 1e-9)
        let nextWeek = cal.date(byAdding: .weekOfYear, value: 1, to: now)!
        #expect(context.effortPoints(asOf: nextWeek) == 0)
    }
}
