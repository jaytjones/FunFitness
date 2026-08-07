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

// MARK: - Distance extraction

/// Pulls total distance in meters from a workout, preferring the modern
/// statistics API and falling back to the deprecated `totalDistance`.
private func distanceMeters(for workout: HKWorkout) -> Double? {
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
