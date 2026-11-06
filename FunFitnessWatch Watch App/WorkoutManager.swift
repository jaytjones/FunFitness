//
//  WorkoutManager.swift
//  FunFitnessWatch Watch App
//
//  Records an outdoor walk or run on the Watch with HKWorkoutSession + HKLiveWorkoutBuilder
//  (3.1). The workout lands in Apple Health with distance, heart rate and energy; when it's
//  saved, the Watch also sends the distance to the phone tagged with the workout's UUID, so it
//  counts in FunFitness right away and the phone's Health import skips it.
//
//  Build 12: the route is recorded too. Location fixes go to an HKWorkoutRouteBuilder (the full
//  route, saved with the workout in Health) and, filtered and downsampled with the shared
//  RouteMath, to the phone as a polyline for its map and Effort Points.
//

import Foundation
import CoreLocation
import HealthKit
import Observation

@MainActor
@Observable
final class WorkoutManager: NSObject {
    static let shared = WorkoutManager()

    enum Kind: String, CaseIterable, Identifiable {
        case walk, run
        var id: String { rawValue }
        var name: String { self == .walk ? "Walk" : "Run" }
        var symbol: String { self == .walk ? "figure.walk" : "figure.run" }
        var activityType: HKWorkoutActivityType { self == .walk ? .walking : .running }
        var trackedKind: TrackedWorkoutKind { self == .walk ? .walk : .run }
    }

    enum Phase: Equatable {
        case idle
        case running
        case paused
        /// Ended; showing the summary.
        case finished
    }

    private(set) var phase: Phase = .idle
    private(set) var kind: Kind = .walk
    private(set) var distanceMeters: Double = 0
    private(set) var heartRate: Double?
    private(set) var averageHeartRate: Double?
    private(set) var maximumHeartRate: Double?
    private(set) var errorMessage: String?
    /// Moving time at the end (for the summary).
    private(set) var finalElapsed: TimeInterval = 0

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?
    private let locationManager = CLLocationManager()
    /// Accepted fixes for the phone's copy of the route.
    private var routePoints: [RoutePoint] = []
    private var startDate: Date?

    private override init() {}

    /// Moving time so far (pauses excluded), for a TimelineView clock.
    func elapsed(at date: Date) -> TimeInterval {
        guard let builder else { return finalElapsed }
        return builder.elapsedTime(at: date)
    }

    // MARK: - Controls

    func start(_ kind: Kind) async {
        guard phase == .idle, HKHealthStore.isHealthDataAvailable() else { return }
        errorMessage = nil
        do {
            try await requestAuthorization()
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = kind.activityType
            configuration.locationType = .outdoor

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder
            self.routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
            routePoints = []
            self.kind = kind
            distanceMeters = 0
            heartRate = nil
            averageHeartRate = nil
            maximumHeartRate = nil
            finalElapsed = 0

            let start = Date()
            startDate = start
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            phase = .running
            startLocation()
        } catch {
            errorMessage = "Couldn't start the workout. Check Health access in Settings."
            reset()
        }
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    /// Ends and saves the workout to Health, then sends it to the phone.
    func end() async {
        guard let session, let builder, phase == .running || phase == .paused else { return }
        let endDate = Date()
        finalElapsed = builder.elapsedTime(at: endDate)
        locationManager.stopUpdatingLocation()
        session.end()
        do {
            try await builder.endCollection(at: endDate)
            let workout = try await builder.finishWorkout()
            if let workout, let routeBuilder, !routePoints.isEmpty {
                // The full route goes into Health with the workout; a failure here keeps the workout.
                _ = try? await routeBuilder.finishRoute(with: workout, metadata: nil)
            }
            phase = .finished
            if distanceMeters > 0 {
                let downsampled = RouteMath.downsample(routePoints)
                PhoneLink.shared.send(WatchQuickLog(
                    id: UUID(),
                    kind: .distance,
                    value: distanceMeters / 1000,
                    date: endDate,
                    healthKitUUID: workout?.uuid,
                    averageHeartRate: averageHeartRate,
                    maximumHeartRate: maximumHeartRate,
                    routePolyline: downsampled.count >= 2 ? RoutePolyline.encode(downsampled) : nil,
                    movingSeconds: finalElapsed,
                    startDate: startDate,
                    trackedKind: kind.trackedKind
                ))
            }
        } catch {
            errorMessage = "The workout couldn't be saved to Health."
            phase = .finished
        }
    }

    /// Back to the start screen after the summary.
    func reset() {
        locationManager.stopUpdatingLocation()
        session = nil
        builder = nil
        routeBuilder = nil
        routePoints = []
        startDate = nil
        phase = .idle
    }

    // MARK: - Location

    /// Route recording is best effort: without location permission the workout still records
    /// time, distance (from the Watch's motion sensors) and heart rate.
    private func startLocation() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = RouteMath.minSegmentDistance
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    /// Permission granted mid-workout (the first-run prompt): start recording the route.
    fileprivate func authorizationChanged() {
        let status = locationManager.authorizationStatus
        if (status == .authorizedWhenInUse || status == .authorizedAlways), phase == .running {
            locationManager.startUpdatingLocation()
        }
    }

    fileprivate func received(_ locations: [CLLocation]) {
        guard phase == .running, let routeBuilder else { return }
        let good = locations.filter {
            $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= RouteMath.maxHorizontalAccuracy
        }
        guard !good.isEmpty else { return }
        routeBuilder.insertRouteData(good) { _, _ in }
        routePoints += good.map {
            RoutePoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude,
                       timestamp: $0.timestamp, horizontalAccuracy: $0.horizontalAccuracy)
        }
    }

    // MARK: - Health

    private func requestAuthorization() async throws {
        let share: Set<HKSampleType> = [HKQuantityType.workoutType(), HKSeriesType.workoutRoute()]
        let read: Set<HKObjectType> = [
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKObjectType.workoutType(),
        ]
        try await healthStore.requestAuthorization(toShare: share, read: read)
    }

    fileprivate func update(distance: Double?, heartRate: Double?, average: Double?, maximum: Double?) {
        if let distance { distanceMeters = distance }
        if let heartRate { self.heartRate = heartRate }
        if let average { averageHeartRate = average }
        if let maximum { maximumHeartRate = maximum }
    }

    fileprivate func sessionChanged(to state: HKWorkoutSessionState) {
        switch state {
        case .running: if phase == .paused { phase = .running }
        case .paused:  if phase == .running { phase = .paused }
        default: break
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in WorkoutManager.shared.sessionChanged(to: toState) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let meters = HKUnit.meter()
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let distance = workoutBuilder.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: meters)
        let heart = workoutBuilder.statistics(for: HKQuantityType(.heartRate))
        let current = heart?.mostRecentQuantity()?.doubleValue(for: bpm)
        let average = heart?.averageQuantity()?.doubleValue(for: bpm)
        let maximum = heart?.maximumQuantity()?.doubleValue(for: bpm)
        Task { @MainActor in
            WorkoutManager.shared.update(distance: distance, heartRate: current, average: average, maximum: maximum)
        }
    }
}

extension WorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in WorkoutManager.shared.received(locations) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in WorkoutManager.shared.authorizationChanged() }
    }
}
