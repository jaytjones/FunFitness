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
    private let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self,
            ActivityLog.self,
            UnlockedAchievement.self,
            StreakRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            sharedModelContainer = container
        } else {
            // Persistent store failed (e.g. migration error) — fall back to in-memory
            // so the app remains usable rather than crashing. Data will not persist this session.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            sharedModelContainer = try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
