//
//  WorkoutLiveActivityActions.swift
//  FunFitnessWidgets
//
//  Extension-side stand-in for the app's `WorkoutLiveActivityActions`. The workout intents in
//  Shared/WorkoutLiveActivity.swift are `LiveActivityIntent`s, which the system always runs in the
//  app's process, so this is never called — it only lets the shared intents compile here.
//

import Foundation

enum WorkoutLiveActivityActions {
    @MainActor
    static func handle(_ command: WorkoutLiveActivityCommand) async {}
}
