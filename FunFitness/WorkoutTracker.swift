//
//  WorkoutTracker.swift
//  FunFitness
//
//  Records a live GPS walk or run on iPhone (3.1 B1a). Core Location → `RouteAccumulator`;
//  all the math lives in RouteMath.swift so it's unit-tested. A single shared instance so the
//  tracking screen, Home, and (in B1b) Live Activity buttons all see the same workout.
//
//  Location: `CLLocationUpdate.liveUpdates(.fitness)` plus a `CLBackgroundActivitySession`, which
//  keeps updates flowing with the screen locked under When In Use authorization and shows the
//  system's blue location indicator. A `CLServiceSession` makes the When In Use request.
//

import Foundation
import CoreLocation
import Observation

/// A finished workout, ready to save. Value type so it can be handed to HealthKit off the view.
nonisolated struct TrackedWorkoutResult: Equatable, Sendable {
    let kind: TrackedWorkoutKind
    let startedAt: Date
    let endedAt: Date
    let distanceMeters: Double
    let movingSeconds: TimeInterval
    let points: [RoutePoint]
    let pauseIntervals: [DateInterval]

    /// Under this the save button is disabled — usually GPS never got a fix.
    static let minimumSavableMeters: Double = 10

    var isSavable: Bool { distanceMeters >= Self.minimumSavableMeters }
}

@MainActor
@Observable
final class WorkoutTracker {
    static let shared = WorkoutTracker()

    enum Phase: Equatable {
        case idle
        case active
        case paused
        case finished
    }

    private(set) var phase: Phase = .idle
    private(set) var accumulator = RouteAccumulator(kind: .walk)
    /// Set by `finish()`; cleared by `reset()` once saved or discarded.
    private(set) var result: TrackedWorkoutResult?
    /// A user-facing reason tracking can't work well right now (permission, precision), or nil.
    private(set) var locationIssue: String?
    /// True once Core Location has delivered any fix, so the UI can say "Finding GPS…" until then.
    private(set) var hasLocationFix = false

    private var updatesTask: Task<Void, Never>?
    private var serviceSession: CLServiceSession?
    private var backgroundSession: CLBackgroundActivitySession?

    private init() {}

    var isRecording: Bool { phase == .active || phase == .paused }
    var kind: TrackedWorkoutKind { accumulator.kind }
    var distanceMeters: Double { accumulator.distanceMeters }
    var points: [RoutePoint] { accumulator.points }
    var startedAt: Date? { accumulator.startedAt }

    func movingSeconds(at date: Date) -> TimeInterval {
        accumulator.movingSeconds(at: date)
    }

    // MARK: - Controls

    /// Starts recording. Call from the foreground (the location prompt and background session
    /// both require it).
    func start(kind: TrackedWorkoutKind, at date: Date = Date()) {
        guard phase == .idle else { return }
        accumulator = RouteAccumulator(kind: kind)
        accumulator.start(at: date)
        result = nil
        locationIssue = nil
        hasLocationFix = false
        phase = .active
        startLocationUpdates()
    }

    func pause(at date: Date = Date()) {
        guard phase == .active else { return }
        accumulator.pause(at: date)
        phase = .paused
    }

    func resume(at date: Date = Date()) {
        guard phase == .paused else { return }
        accumulator.resume(at: date)
        phase = .active
    }

    /// Stops recording and produces the result to review and save.
    @discardableResult
    func finish(at date: Date = Date()) -> TrackedWorkoutResult? {
        guard isRecording, let startedAt = accumulator.startedAt else { return nil }
        stopLocationUpdates()
        accumulator.finish(at: date)
        let finished = TrackedWorkoutResult(
            kind: accumulator.kind,
            startedAt: startedAt,
            endedAt: date,
            distanceMeters: accumulator.distanceMeters,
            movingSeconds: accumulator.movingSeconds(at: date),
            points: accumulator.points,
            pauseIntervals: accumulator.pauseIntervals
        )
        result = finished
        phase = .finished
        return finished
    }

    /// Returns to idle after the result is saved or discarded (or abandons a recording).
    func reset() {
        stopLocationUpdates()
        accumulator = RouteAccumulator(kind: .walk)
        result = nil
        locationIssue = nil
        hasLocationFix = false
        phase = .idle
    }

    // MARK: - Location

    private func startLocationUpdates() {
        serviceSession = CLServiceSession(authorization: .whenInUse)
        backgroundSession = CLBackgroundActivitySession()
        updatesTask = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    guard let self, !Task.isCancelled else { return }
                    self.handle(update)
                }
            } catch {
                self?.locationIssue = "Location updates stopped. Finish and save what you have, or try again."
            }
        }
    }

    private func stopLocationUpdates() {
        updatesTask?.cancel()
        updatesTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        serviceSession?.invalidate()
        serviceSession = nil
    }

    private func handle(_ update: CLLocationUpdate) {
        if update.authorizationDenied || update.authorizationDeniedGlobally {
            locationIssue = "Location access is off. Turn it on in Settings › Privacy › Location Services › FunFitness to track your route."
        } else if update.accuracyLimited {
            locationIssue = "Precise Location is off, so distance won't be accurate. Turn it on in Settings › FunFitness › Location."
        } else if update.location != nil {
            locationIssue = nil
        }

        guard let location = update.location else { return }
        hasLocationFix = true
        accumulator.add(RoutePoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy
        ))
    }
}
