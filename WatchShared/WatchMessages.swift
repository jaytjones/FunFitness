//
//  WatchMessages.swift
//  FunFitness (compiled into the iPhone app and the Watch app)
//
//  What the Apple Watch app and the iPhone app send each other over WatchConnectivity (3.1).
//  See docs/20261010_3.1_design_decisions.md §3.
//
//  - Watch → phone: `WatchQuickLog` via `transferUserInfo` (queued, delivered even if the phone
//    app isn't running). The phone saves it through ActivityWriter like any other log.
//  - Phone → Watch: `WatchContext` via `updateApplicationContext` (latest wins): units, the
//    exercise list (bundled + the person's own), and last-used values for prefilling.
//
//  Both sides only exchange these Codable values, so the Watch app doesn't need SwiftData or
//  the phone's models. Field names are persisted in transit, so add fields as optionals only.
//

import Foundation

nonisolated enum WatchLink {
    /// userInfo / applicationContext key holding the JSON-encoded payload.
    static let payloadKey = "payload"
}

/// One entry logged on the Watch.
nonisolated struct WatchQuickLog: Codable, Equatable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable {
        /// Weight × reps: `value` is kg per rep.
        case lift
        /// Bodyweight reps: `value` is the rep count.
        case bodyweight
        /// `value` is minutes.
        case duration
        /// A walk/run recorded on the Watch: `value` is km. Also saved to Health as `healthKitUUID`.
        case distance
    }

    let id: UUID
    let kind: Kind
    let value: Double
    var reps: Int? = nil
    var exerciseID: String? = nil
    let date: Date
    var healthKitUUID: UUID? = nil
    var averageHeartRate: Double? = nil
    var maximumHeartRate: Double? = nil

    func encoded() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [WatchLink.payloadKey: data]
    }

    static func decode(_ dictionary: [String: Any]) -> WatchQuickLog? {
        guard let data = dictionary[WatchLink.payloadKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchQuickLog.self, from: data)
    }
}

nonisolated struct WatchExercise: Codable, Equatable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    /// `.lift` or `.bodyweight`.
    let kind: WatchQuickLog.Kind
}

/// What the Watch needs from the phone.
nonisolated struct WatchContext: Codable, Equatable, Sendable {
    var usesMetric: Bool
    var exercises: [WatchExercise]
    /// Last exercise id per kind (`WatchQuickLog.Kind.rawValue`).
    var lastExerciseIDs: [String: String] = [:]
    /// Last lift weight in kg and rep count, for prefilling.
    var lastLiftKg: Double? = nil
    var lastLiftReps: Int? = nil

    func encoded() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [WatchLink.payloadKey: data]
    }

    static func decode(_ dictionary: [String: Any]) -> WatchContext? {
        guard let data = dictionary[WatchLink.payloadKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchContext.self, from: data)
    }

    static let kgPerPound = 0.45359237
}
