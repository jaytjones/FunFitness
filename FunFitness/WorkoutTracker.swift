//
//  WorkoutTracker.swift
//  FunFitness
//
//  Records a live GPS walk or run on iPhone (3.1 B1a). Core Location → `RouteAccumulator`;
//  all the math lives in RouteMath.swift so it's unit-tested. A single shared instance so the
//  tracking screen, Home, and the Live Activity buttons all see the same workout. Every state
//  change is mirrored to the Live Activity via `WorkoutLiveActivityController` (3.1 B1b).
//
//  Location: `CLLocationUpdate.liveUpdates(.fitness)` plus a `CLBackgroundActivitySession`, which
//  keeps updates flowing with the screen locked under When In Use authorization and shows the
//  system's blue location indicator. A `CLServiceSession` makes the When In Use request.
//
//  Indoor (treadmill) workouts, picked on the start screen, skip GPS: distance comes from the
//  step counter (`CMPedometer`) and there's no route (FB-0020).
//

import Foundation
import CoreLocation
import CoreMotion
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
    /// Treadmill/indoors: the distance came from the step counter and there's no route.
    var isIndoor = false

    /// Under this the save button is disabled — usually neither GPS nor the step counter got anything.
    static let minimumSavableMeters: Double = 10

    var isSavable: Bool { distanceMeters >= Self.minimumSavableMeters }
}

/// Step-counter distance with paused time left out. `CMPedometer` reports a running total since
/// the start; only the growth while not paused is counted. Pure so it's unit-tested. (FB-0020)
nonisolated struct StepDistance: Equatable, Sendable {
    private(set) var countedMeters: Double = 0
    private var lastTotal: Double = 0
    var isPaused = false

    mutating func update(total: Double) {
        let growth = max(0, total - lastTotal)
        lastTotal = max(lastTotal, total)
        if !isPaused { countedMeters += growth }
    }
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

    /// Indoor (treadmill): no GPS; distance from the step counter. Set at `start`.
    private(set) var isIndoor = false
    /// Step-counter distance for an indoor workout.
    private(set) var steps = StepDistance()

    private var updatesTask: Task<Void, Never>?
    private var serviceSession: CLServiceSession?
    private var backgroundSession: CLBackgroundActivitySession?
    private let pedometer = CMPedometer()
    private var liveActivity: WorkoutLiveActivityController { .shared }

    private init() {}

    var isRecording: Bool { phase == .active || phase == .paused }
    var kind: TrackedWorkoutKind { accumulator.kind }
    /// GPS distance outdoors; the step counter's indoors.
    var distanceMeters: Double { isIndoor ? steps.countedMeters : accumulator.distanceMeters }
    var points: [RoutePoint] { accumulator.points }
    var startedAt: Date? { accumulator.startedAt }

    func movingSeconds(at date: Date) -> TimeInterval {
        accumulator.movingSeconds(at: date)
    }

    // MARK: - Controls

    /// Starts recording. Call from the foreground (the location prompt and background session
    /// both require it).
    func start(kind: TrackedWorkoutKind, indoor: Bool = false, at date: Date = Date()) {
        guard phase == .idle else { return }
        accumulator = RouteAccumulator(kind: kind)
        accumulator.start(at: date)
        result = nil
        locationIssue = nil
        hasLocationFix = false
        isIndoor = indoor
        steps = StepDistance()
        phase = .active
        if indoor {
            startStepUpdates(from: date)
        } else {
            startLocationUpdates()
        }
        liveActivity.start(for: self, at: date)
    }

    func pause(at date: Date = Date()) {
        guard phase == .active else { return }
        accumulator.pause(at: date)
        steps.isPaused = true
        phase = .paused
        liveActivity.update(for: self, force: true, at: date)
    }

    func resume(at date: Date = Date()) {
        guard phase == .paused else { return }
        accumulator.resume(at: date)
        steps.isPaused = false
        phase = .active
        liveActivity.update(for: self, force: true, at: date)
    }

    /// Stops recording and produces the result to review and save.
    @discardableResult
    func finish(at date: Date = Date()) -> TrackedWorkoutResult? {
        guard isRecording, let startedAt = accumulator.startedAt else { return nil }
        stopLocationUpdates()
        stopStepUpdates()
        accumulator.finish(at: date)
        let finished = makeResult(startedAt: startedAt, endedAt: date)
        result = finished
        phase = .finished
        if isIndoor { refreshFinalSteps(startedAt: startedAt, endedAt: date) }
        // The Live Activity stays up showing the final numbers until the run is saved or discarded.
        liveActivity.update(for: self, force: true, at: date)
        return finished
    }

    /// Returns to idle after the result is saved or discarded (or abandons a recording).
    func reset() {
        stopLocationUpdates()
        stopStepUpdates()
        liveActivity.endAll()
        accumulator = RouteAccumulator(kind: .walk)
        isIndoor = false
        steps = StepDistance()
        result = nil
        locationIssue = nil
        hasLocationFix = false
        phase = .idle
    }

    // MARK: - Steps

    private func makeResult(startedAt: Date, endedAt: Date) -> TrackedWorkoutResult {
        TrackedWorkoutResult(
            kind: accumulator.kind,
            startedAt: startedAt,
            endedAt: endedAt,
            distanceMeters: distanceMeters,
            movingSeconds: accumulator.movingSeconds(at: endedAt),
            points: isIndoor ? [] : accumulator.points,
            pauseIntervals: accumulator.pauseIntervals,
            isIndoor: isIndoor
        )
    }

    /// Live step updates stop while the app is suspended (indoor workouts have no location session
    /// keeping it awake), so the summary asks the step counter for its final total once.
    private func refreshFinalSteps(startedAt: Date, endedAt: Date) {
        guard CMPedometer.isDistanceAvailable() else { return }
        pedometer.queryPedometerData(from: startedAt, to: endedAt) { [weak self] data, _ in
            guard let meters = data?.distance?.doubleValue else { return }
            Task { @MainActor in
                guard let self, self.phase == .finished, self.result?.startedAt == startedAt else { return }
                self.steps.update(total: meters)
                self.result = self.makeResult(startedAt: startedAt, endedAt: endedAt)
            }
        }
    }

    /// The first indoor start asks for Motion & Fitness access.
    private func startStepUpdates(from date: Date) {
        guard CMPedometer.isDistanceAvailable() else {
            locationIssue = "This iPhone can't measure distance from steps, so indoor distance won't be recorded."
            return
        }
        guard CMPedometer.authorizationStatus() != .denied, CMPedometer.authorizationStatus() != .restricted else {
            locationIssue = "Motion & Fitness access is off, so indoor distance can't be counted. Turn it on in Settings › Privacy & Security › Motion & Fitness."
            return
        }
        pedometer.startUpdates(from: date) { [weak self] data, _ in
            guard let meters = data?.distance?.doubleValue else { return }
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                self.steps.update(total: meters)
                self.liveActivity.update(for: self)   // throttled
            }
        }
    }

    private func stopStepUpdates() {
        pedometer.stopUpdates()
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
        let accepted = accumulator.add(RoutePoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy
        ))
        if accepted { liveActivity.update(for: self) }   // throttled
    }
}
