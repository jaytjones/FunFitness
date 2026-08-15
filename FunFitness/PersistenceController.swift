//
//  PersistenceController.swift
//  FunFitness
//
//  Single source of truth for the app's SwiftData ModelContainer (v2.1).
//
//  Both the app (FunFitnessApp) and the Siri intent (LogLastActivityIntent) build their
//  container here so they share an identical CloudKit configuration — otherwise entries
//  logged via Siri would not sync. SwiftData mirrors the store to the user's private
//  CloudKit database via NSPersistentCloudKitContainer; no Sign in with Apple is required.
//

import Foundation
import SwiftData
import CoreData

enum PersistenceController {

    /// The CloudKit container that backs iCloud sync. Must match the identifier listed in
    /// the app's iCloud entitlement.
    static let cloudKitContainerID = "iCloud.com.discoverhealthquest.funfitness"

    /// The set of models persisted (and synced) by the app.
    static var schema: Schema {
        Schema([
            UserProfile.self,
            ActivityLog.self,
            UnlockedAchievement.self,
            StreakRecord.self,
        ])
    }

    // MARK: - Sync opt-out

    /// User-facing opt-out flag. Sync is ON by default. SwiftData can't retarget
    /// `cloudKitDatabase` at runtime, so this is read once at container construction; a change
    /// takes effect the next time the app launches (surfaced to the user in Profile).
    static let syncEnabledDefaultsKey = "iCloudSyncEnabled"

    static var isSyncEnabled: Bool {
        // Absent key ⇒ treat as enabled (opt-out, not opt-in).
        if UserDefaults.standard.object(forKey: syncEnabledDefaultsKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: syncEnabledDefaultsKey)
    }

    // MARK: - Container

    /// Builds the shared ModelContainer. Falls back to an in-memory store if the persistent
    /// store can't be opened (e.g. a migration failure) so the app stays usable rather than
    /// crashing — data won't persist for that session.
    static func makeSharedContainer() -> ModelContainer {
        let cloudDatabase: ModelConfiguration.CloudKitDatabase =
            isSyncEnabled ? .private(cloudKitContainerID) : .none

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudDatabase
        )

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [fallback])
    }

    // MARK: - CloudKit development schema (manual)

    /// Pushes the current model layer to the CloudKit **Development** environment without
    /// creating any records, so the schema can be reviewed and promoted to Production before
    /// an App Store release. This is intentionally NOT called at launch — it requires an iCloud
    /// account + network and would crash on the simulator. Invoke it manually (e.g. from a
    /// temporary debug affordance or a one-off run on a signed-in device) when preparing to
    /// promote the schema. See docs: "Initialize the CloudKit development schema".
    #if DEBUG
    static func initializeCloudKitSchemaForDevelopment() throws {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        try autoreleasepool {
            let description = NSPersistentStoreDescription(url: config.url)
            description.cloudKitContainerOptions =
                NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerID)
            description.shouldAddStoreAsynchronously = false

            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: [
                UserProfile.self,
                ActivityLog.self,
                UnlockedAchievement.self,
                StreakRecord.self,
            ]) else { return }

            let container = NSPersistentCloudKitContainer(name: "FunFitness", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            container.loadPersistentStores { _, error in
                if let error { fatalError("Schema init store load failed: \(error)") }
            }
            try container.initializeCloudKitSchema()
            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    }
    #endif
}
