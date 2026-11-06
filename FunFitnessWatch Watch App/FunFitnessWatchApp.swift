//
//  FunFitnessWatchApp.swift
//  FunFitnessWatch Watch App
//
//  FunFitness on Apple Watch (3.1): track an outdoor walk/run (saved to Health) and quick-log
//  lifts, bodyweight sets and timed activities to the iPhone app.
//

import SwiftUI

@main
struct FunFitnessWatchApp: App {
    init() {
        PhoneLink.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
