//
//  HealthKitManager.swift
//  FunFitness
//
//  Thin async wrapper around HealthKit for reading distance workouts and
//  writing logged activities and workouts back to Health. Distance-only
//  by design: HealthKit has no "total weight lifted" metric, so strength
//  training stays a manual-entry feature.
//

import Foundation
import HealthKit
import CoreLocation
import os

/// A HealthKit workout reduced to just what FunFitness needs.
struct ImportedWorkout: Equatable {
    let uuid: UUID
    let distanceKm: Double
    let date: Date
}

/// How a save to Health went (FB-0020). Before this, every failure was silent.
enum HealthSaveResult: Equatable {
    case saved(UUID)
    /// The person declined write access for these types (Settings → Health → FunFitness).
    /// HealthKit never asks again, so the only fix is Settings.
    case accessOff
    /// Any other error (logged with its reason).
    case failed

    var uuid: UUID? {
        if case .saved(let uuid) = self { return uuid }
        return nil
    }
}

@MainActor
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private let logger = Logger(subsystem: "com.jaytjones.FunFitness", category: "HealthKit")

    /// True when write access for workouts or walking/running distance was declined. Refreshed by
    /// `refreshWriteAccess()` (on launch, on return from Settings, and after each save). (FB-0020)
    private(set) var writeAccessOff = false

    /// The last save that didn't make it to Health, for Home's banner. Cleared by a later
    /// successful save or when the banner is dismissed.
    private(set) var lastFailedSave: HealthSaveResult?

    /// Distance activity types we import. These carry a meaningful
    /// `totalDistance`; strength/other workouts do not and are ignored.
    private let importedActivityTypes: Set<HKWorkoutActivityType> = [
        .walking, .running, .hiking, .cycling
    ]

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let walkRun = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(walkRun) }
        if let cycling = HKObjectType.quantityType(forIdentifier: .distanceCycling) { types.insert(cycling) }
        // GPS routes for tracked walks/runs (3.1). Requesting again later only prompts for this.
        types.insert(HKSeriesType.workoutRoute())
        // Estimated calories on strength-session workouts (3.1 C5).
        types.insert(HKQuantityType(.activeEnergyBurned))
        return types
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let walkRun = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(walkRun) }
        if let cycling = HKObjectType.quantityType(forIdentifier: .distanceCycling) { types.insert(cycling) }
        // Heart rate during tracked walks/runs (3.1 B2). Requesting again later only prompts for this.
        types.insert(HKQuantityType(.heartRate))
        return types
    }

    // MARK: - Authorization

    /// Requests read (and share, for write-back) access. Returns false if
    /// HealthKit is unavailable or the request throws; a thrown/denied request
    /// simply leaves the app in manual mode.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            refreshWriteAccess()
            return true
        } catch {
            return false
        }
    }

    /// Re-reads write permission. Sharing status (unlike read status) is reported truthfully.
    func refreshWriteAccess() {
        guard isAvailable else { writeAccessOff = false; return }
        let types: [HKObjectType] = [HKObjectType.workoutType(), HKQuantityType(.distanceWalkingRunning)]
        writeAccessOff = types.contains { store.authorizationStatus(for: $0) == .sharingDenied }
    }

    func dismissFailedSave() { lastFailedSave = nil }

    /// Turns a finished (or failed) save into a result: declined permission is told apart from
    /// other errors, the error is logged, and the banner state is updated.
    private func outcome(_ uuid: UUID?, error: Error?, type: HKObjectType, what: String) -> HealthSaveResult {
        refreshWriteAccess()
        let result: HealthSaveResult
        if let uuid {
            result = .saved(uuid)
        } else if store.authorizationStatus(for: type) == .sharingDenied {
            result = .accessOff
        } else {
            result = .failed
        }
        switch result {
        case .saved:
            lastFailedSave = nil
        case .accessOff:
            logger.error("Couldn't save \(what, privacy: .public) to Health: write access is off")
            lastFailedSave = result
        case .failed:
            logger.error("Couldn't save \(what, privacy: .public) to Health: \(String(describing: error), privacy: .public)")
            lastFailedSave = result
        }
        return result
    }

    /// A save that can't be attempted (nothing to save). Logged and shown like any other failure,
    /// so it's never silent. (FB-0020)
    private func skipped(_ what: String, reason: String) -> HealthSaveResult {
        logger.error("Didn't save \(what, privacy: .public) to Health: \(reason, privacy: .public)")
        lastFailedSave = .failed
        return .failed
    }

    // MARK: - Reading

    /// Fetches distance workouts (walking/running/hiking/cycling) with a
    /// non-zero distance, optionally limited to those ending after `since`.
    func fetchDistanceWorkouts(since: Date?) async -> [ImportedWorkout] {
        guard isAvailable else { return [] }

        let typePredicates = importedActivityTypes.map {
            HKQuery.predicateForWorkouts(with: $0)
        }
        var predicate: NSPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates)
        if let since {
            let datePredicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])
        }

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                let imported: [ImportedWorkout] = workouts.compactMap { workout in
                    guard let meters = distanceMeters(for: workout), meters > 0 else { return nil }
                    return ImportedWorkout(
                        uuid: workout.uuid,
                        distanceKm: meters / 1000.0,
                        date: workout.endDate
                    )
                }
                continuation.resume(returning: imported)
            }
            store.execute(query)
        }
    }

    // MARK: - Writing

    /// Saves a manually logged distance to Health (FB-0020). With a duration it's a real Walking or
    /// Running workout from `start` to `start + durationSeconds`; without one there's no honest
    /// time window, so it's a plain distance sample at `start` instead of a made-up workout.
    /// The returned UUID tags the entry so our own write-back isn't re-imported (echo prevention;
    /// the import only reads workouts, so a sample can't echo either way).
    func saveManualDistance(distanceKm: Double, start: Date, durationSeconds: Double?, kind: TrackedWorkoutKind) async -> HealthSaveResult {
        guard isAvailable else { return .failed }
        guard distanceKm > 0 else { return skipped("distance", reason: "no distance") }
        await requestAuthorization()

        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let quantity = HKQuantity(unit: .meter(), doubleValue: distanceKm * 1000.0)

        guard let durationSeconds, durationSeconds > 0 else {
            let sample = HKQuantitySample(type: distanceType, quantity: quantity, start: start, end: start)
            do {
                try await store.save(sample)
                return outcome(sample.uuid, error: nil, type: distanceType, what: "distance")
            } catch {
                return outcome(nil, error: error, type: distanceType, what: "distance")
            }
        }

        let end = start.addingTimeInterval(durationSeconds)
        let config = HKWorkoutConfiguration()
        config.activityType = kind == .run ? .running : .walking
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.addSamples([
                HKCumulativeQuantitySample(type: distanceType, quantity: quantity, start: start, end: end)
            ])
            try await builder.endCollection(at: end)
            let workout = try await builder.finishWorkout()
            return outcome(workout?.uuid, error: nil, type: HKObjectType.workoutType(), what: "manual workout")
        } catch {
            return outcome(nil, error: error, type: HKObjectType.workoutType(), what: "manual workout")
        }
    }
}

extension HealthKitManager {

    /// Saves a GPS-tracked walk or run to Health as a real workout — actual start/end, pause
    /// events, distance, and the route. An indoor one (treadmill; distance from the step counter)
    /// is saved as an indoor workout with no route. A `.saved` result carries the workout's UUID (echo
    /// prevention, as for manual write-back). Built after the run with `HKWorkoutBuilder` so it works on iOS 18;
    /// iPhone `HKWorkoutSession` (iOS 26) is a possible future upgrade. On failure the
    /// in-app log and route are already saved; the result says why Health didn't get it. (3.1 B1a)
    /// `kcal` is the estimated active energy (FB-0020), so the workout counts toward the Move ring.
    func saveTrackedWorkout(_ result: TrackedWorkoutResult, kcal: Double? = nil) async -> HealthSaveResult {
        guard isAvailable else { return .failed }
        guard result.distanceMeters > 0, result.endedAt > result.startedAt else {
            return skipped("tracked workout", reason: "no distance or no time")
        }
        // Prompts only for types not yet decided (e.g. the route type added in 3.1).
        await requestAuthorization()

        let config = HKWorkoutConfiguration()
        config.activityType = result.kind == .run ? .running : .walking
        config.locationType = result.isIndoor ? .indoor : .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())

        let workout: HKWorkout
        do {
            try await builder.beginCollection(at: result.startedAt)
            let distance = HKCumulativeQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meter(), doubleValue: result.distanceMeters),
                start: result.startedAt,
                end: result.endedAt
            )
            var samples: [HKSample] = [distance]
            if let kcal, kcal > 0 {
                samples.append(HKCumulativeQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                    start: result.startedAt,
                    end: result.endedAt
                ))
            }
            try await builder.addSamples(samples)
            let events = result.pauseIntervals.flatMap { pause in [
                HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil),
                HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil),
            ] }
            if !events.isEmpty { try await builder.addWorkoutEvents(events) }
            try await builder.addMetadata([HKMetadataKeyIndoorWorkout: result.isIndoor])
            try await builder.endCollection(at: result.endedAt)
            guard let finished = try await builder.finishWorkout() else {
                return outcome(nil, error: nil, type: HKObjectType.workoutType(), what: "tracked workout")
            }
            workout = finished
        } catch {
            return outcome(nil, error: error, type: HKObjectType.workoutType(), what: "tracked workout")
        }

        // The route is best-effort: a declined route permission still leaves the workout saved.
        if !result.isIndoor, !result.points.isEmpty {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
            let locations = result.points.map { point in
                CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                    altitude: 0,
                    horizontalAccuracy: point.horizontalAccuracy,
                    verticalAccuracy: -1,
                    timestamp: point.timestamp
                )
            }
            do {
                try await routeBuilder.insertRouteData(locations)
                try await routeBuilder.finishRoute(with: workout, metadata: nil)
            } catch {
                // Keep the workout; Health just won't show a map for it.
                logger.error("Couldn't save route to Health: \(String(describing: error), privacy: .public)")
            }
        }
        return outcome(workout.uuid, error: nil, type: HKObjectType.workoutType(), what: "tracked workout")
    }
}

extension HealthKitManager {

    /// Heart-rate readings saved to Health between `start` and `end` — by an Apple Watch or another
    /// sensor; FunFitness records none itself. Empty when there are none, or when read access was
    /// declined (HealthKit doesn't say which). (3.1 B2)
    func fetchHeartRateSamples(from start: Date, to end: Date) async -> [HeartRateSample] {
        guard isAvailable, end > start else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: HKQuantityType(.heartRate),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let readings = ((samples as? [HKQuantitySample]) ?? []).map {
                    HeartRateSample(bpm: $0.quantity.doubleValue(for: bpm), date: $0.startDate)
                }
                continuation.resume(returning: readings)
            }
            store.execute(query)
        }
    }

    /// Asks for Health access if needed (prompts only for undecided types), then summarizes the
    /// heart rate recorded during a tracked walk/run. nil when nothing was recorded.
    func heartRateSummary(for result: TrackedWorkoutResult) async -> HeartRateSummary? {
        guard isAvailable else { return nil }
        await requestAuthorization()
        let samples = await fetchHeartRateSamples(from: result.startedAt, to: result.endedAt)
        return HeartRateMath.summary(
            samples: samples, start: result.startedAt, end: result.endedAt, pauses: result.pauseIntervals
        )
    }
}

extension HealthKitManager {

    /// The most recent body weight in Health, in kg (3.1 C4). With `requestingAccess`, first asks
    /// to read body weight only — nothing else — so a calorie estimate never prompts for the whole
    /// Health set. nil when there's none, or read access was declined (HealthKit doesn't say which).
    func latestBodyMassKg(requestingAccess: Bool) async -> Double? {
        guard isAvailable else { return nil }
        let bodyMass = HKQuantityType(.bodyMass)
        if requestingAccess {
            try? await store.requestAuthorization(toShare: [], read: [bodyMass])
        }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: bodyMass, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    /// Saves a strength session to Health as a Traditional Strength Training workout with its start,
    /// end, indoor/outdoor flag, and estimated active energy when there is one (3.1 C5). `.saved`
    /// carries the workout's UUID. Strength workouts aren't imported back (the import is
    /// distance-only), so there's no echo to guard against.
    func saveStrengthSession(start: Date, end: Date, kcal: Double?, isIndoor: Bool?) async -> HealthSaveResult {
        guard isAvailable else { return .failed }
        guard end > start else { return skipped("strength workout", reason: "end isn't after start") }
        await requestAuthorization()

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = isIndoor.map { $0 ? .indoor : .outdoor } ?? .unknown
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            if let kcal, kcal > 0 {
                let energy = HKCumulativeQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                    start: start,
                    end: end
                )
                try await builder.addSamples([energy])
            }
            if let isIndoor { try await builder.addMetadata([HKMetadataKeyIndoorWorkout: isIndoor]) }
            try await builder.endCollection(at: end)
            let workout = try await builder.finishWorkout()
            return outcome(workout?.uuid, error: nil, type: HKObjectType.workoutType(), what: "strength workout")
        } catch {
            return outcome(nil, error: error, type: HKObjectType.workoutType(), what: "strength workout")
        }
    }
}

// MARK: - Distance extraction

/// Pulls total distance in meters from a workout, preferring the modern
/// statistics API and falling back to the deprecated `totalDistance`.
nonisolated private func distanceMeters(for workout: HKWorkout) -> Double? {
    let walkRun = HKQuantityType(.distanceWalkingRunning)
    let cycling = HKQuantityType(.distanceCycling)
    if let stats = workout.statistics(for: walkRun)?.sumQuantity() {
        return stats.doubleValue(for: .meter())
    }
    if let stats = workout.statistics(for: cycling)?.sumQuantity() {
        return stats.doubleValue(for: .meter())
    }
    return workout.totalDistance?.doubleValue(for: .meter())
}
