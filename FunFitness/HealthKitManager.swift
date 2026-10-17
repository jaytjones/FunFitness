//
//  HealthKitManager.swift
//  FunFitness
//
//  Thin async wrapper around HealthKit for reading distance workouts and
//  writing manually logged distance activities back to Health. Distance-only
//  by design: HealthKit has no "total weight lifted" metric, so strength
//  training stays a manual-entry feature.
//

import Foundation
import HealthKit
import CoreLocation

/// A HealthKit workout reduced to just what FunFitness needs.
struct ImportedWorkout: Equatable {
    let uuid: UUID
    let distanceKm: Double
    let date: Date
}

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

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
        return types
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let walkRun = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(walkRun) }
        if let cycling = HKObjectType.quantityType(forIdentifier: .distanceCycling) { types.insert(cycling) }
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
            return true
        } catch {
            return false
        }
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

    /// Saves a walking workout carrying `distanceKm` to Health and returns the
    /// new workout's UUID (used to prevent re-importing our own write-back).
    func saveDistanceWorkout(distanceKm: Double, date: Date) async -> UUID? {
        guard isAvailable, distanceKm > 0 else { return nil }

        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let quantity = HKQuantity(unit: .meter(), doubleValue: distanceKm * 1000.0)
        // Treat the logged moment as a brief workout window ending at `date`.
        let start = date.addingTimeInterval(-60)

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: {
                let config = HKWorkoutConfiguration()
                config.activityType = .walking
                return config
            }(),
            device: .local()
        )

        do {
            try await builder.beginCollection(at: start)
            let distanceSample = HKCumulativeQuantitySample(
                type: distanceType,
                quantity: quantity,
                start: start,
                end: date
            )
            try await builder.addSamples([distanceSample])
            try await builder.endCollection(at: date)
            let workout = try await builder.finishWorkout()
            return workout?.uuid
        } catch {
            return nil
        }
    }
}

extension HealthKitManager {

    /// Saves a GPS-tracked walk or run to Health as a real workout — actual start/end, pause
    /// events, distance, and the route — and returns the workout's UUID (echo prevention, as for
    /// manual write-back). Built after the run with `HKWorkoutBuilder` so it works on iOS 18;
    /// iPhone `HKWorkoutSession` (iOS 26) is a possible future upgrade. Returns nil on any failure;
    /// the in-app log and route are already saved by then. (3.1 B1a)
    func saveTrackedWorkout(_ result: TrackedWorkoutResult) async -> UUID? {
        guard isAvailable, result.distanceMeters > 0, result.endedAt > result.startedAt else { return nil }
        // Prompts only for types not yet decided (e.g. the route type added in 3.1).
        await requestAuthorization()

        let config = HKWorkoutConfiguration()
        config.activityType = result.kind == .run ? .running : .walking
        config.locationType = .outdoor
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
            try await builder.addSamples([distance])
            let events = result.pauseIntervals.flatMap { pause in [
                HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil),
                HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil),
            ] }
            if !events.isEmpty { try await builder.addWorkoutEvents(events) }
            try await builder.addMetadata([HKMetadataKeyIndoorWorkout: false])
            try await builder.endCollection(at: result.endedAt)
            guard let finished = try await builder.finishWorkout() else { return nil }
            workout = finished
        } catch {
            return nil
        }

        // The route is best-effort: a declined route permission still leaves the workout saved.
        if !result.points.isEmpty {
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
            }
        }
        return workout.uuid
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
