//
//  RouteSummary.swift
//  FunFitness
//
//  The display copy of a tracked walk/run route (3.1 B1a). The full-detail route lives in
//  Apple Health when the person saves workouts there; this downsampled copy is always kept so
//  the map works without Health and syncs through iCloud like everything else.
//  See docs/20261010_3.1_design_decisions.md §1 (option C).
//

import Foundation
import SwiftData

@Model
final class RouteSummary {
    // CloudKit-legal: every attribute has a default, no relationships, no unique constraints.
    /// The `ActivityLog.id` this route belongs to (a plain UUID, not a relationship).
    var activityID: UUID = UUID()
    /// `RoutePolyline`-encoded, downsampled coordinates. Stored outside the record (CKAsset).
    @Attribute(.externalStorage) var polyline: Data? = nil
    var distanceKm: Double = 0
    var startedAt: Date = Date()
    var endedAt: Date = Date()
    /// Time spent moving (pauses excluded).
    var movingSeconds: Double = 0
    var workoutKindRaw: String = TrackedWorkoutKind.walk.rawValue
    /// The Health workout saved alongside this route, if the person saves workouts to Health.
    var healthKitWorkoutUUID: UUID? = nil

    init(
        activityID: UUID,
        polyline: Data?,
        distanceKm: Double,
        startedAt: Date,
        endedAt: Date,
        movingSeconds: Double,
        kind: TrackedWorkoutKind,
        healthKitWorkoutUUID: UUID? = nil
    ) {
        self.activityID = activityID
        self.polyline = polyline
        self.distanceKm = distanceKm
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.movingSeconds = movingSeconds
        self.workoutKindRaw = kind.rawValue
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
    }

    var kind: TrackedWorkoutKind {
        TrackedWorkoutKind(rawValue: workoutKindRaw) ?? .walk
    }

    /// Decoded route coordinates for drawing.
    var coordinates: [(latitude: Double, longitude: Double)] {
        polyline.map(RoutePolyline.decode) ?? []
    }
}
