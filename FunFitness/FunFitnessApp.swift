//
//  FunFitnessApp.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

@main
struct FunFitnessApp: App {
    // Shared CloudKit-backed container (v2.1). Built by PersistenceController so the app and
    // the Siri intent use an identical sync configuration.
    private let sharedModelContainer = PersistenceController.makeSharedContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
