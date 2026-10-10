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
    private let sharedModelContainer: ModelContainer

    init() {
        #if DEBUG
        // One-off: launch a Debug build on a signed-in device with `-initCloudKitSchema` to push
        // the model layer to the CloudKit Development environment, then deploy it to Production
        // from the CloudKit Console. Runs before the shared container so the two don't open the
        // same store at once. (pre-3.1, plan item B1)
        if ProcessInfo.processInfo.arguments.contains("-initCloudKitSchema") {
            do {
                try PersistenceController.initializeCloudKitSchemaForDevelopment()
                print("CloudKit schema initialized in the Development environment.")
            } catch {
                print("CloudKit schema initialization failed: \(error)")
            }
        }
        #endif
        sharedModelContainer = PersistenceController.makeSharedContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
