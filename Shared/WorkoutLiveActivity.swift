//
//  WorkoutLiveActivity.swift
//  Shared (compiled into both FunFitness and FunFitnessWidgetsExtension)
//
//  The Live Activity for a workout in progress (3.1 B1b): its ActivityKit attributes and the
//  Lock Screen / Dynamic Island button intents. Both targets need these types — the app starts
//  and updates the activity and runs the intents; the widget extension draws it and builds the
//  buttons. Types are explicitly nonisolated because the two targets use different default actor
//  isolation.
//
//  Strings arrive pre-formatted in the user's units, so the extension needs no app logic.
//

import Foundation
import ActivityKit
import AppIntents

nonisolated struct WorkoutActivityAttributes: ActivityAttributes {

    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var isPaused: Bool
        /// Finished but not yet saved; the activity asks the person to open the app.
        var isFinished: Bool
        /// While running, moving time is `now - timerStart`, so the clock ticks on its own
        /// between updates. Shifted forward on each resume so pauses aren't counted.
        var timerStart: Date
        /// Frozen elapsed time shown while paused or finished, e.g. "12:05".
        var elapsedText: String
        var primaryValue: String      // "1.2 mi"
        var primaryLabel: String      // "Distance"
        var secondaryValue: String    // "9:41 /mi"
        var secondaryLabel: String    // "Pace"
        /// "1.2 mi is 3 blue whales 🐋", when there's enough distance for one.
        var comparison: String?
    }

    /// "Walk" or "Run".
    var title: String
    var emoji: String
}

// MARK: - Button intents

/// What a Live Activity button asks the app to do.
nonisolated enum WorkoutLiveActivityCommand: String, Sendable {
    case pause
    case resume
    case end
}

// `LiveActivityIntent`s run in the app's process, so `WorkoutLiveActivityActions` is the app's real
// implementation there; the extension has a no-op stand-in that exists only so this compiles.

nonisolated struct PauseWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause Workout"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await WorkoutLiveActivityActions.handle(.pause)
        return .result()
    }
}

nonisolated struct ResumeWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume Workout"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await WorkoutLiveActivityActions.handle(.resume)
        return .result()
    }
}

nonisolated struct EndWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Workout"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await WorkoutLiveActivityActions.handle(.end)
        return .result()
    }
}
