//
//  PersistenceTests.swift
//  FunFitnessTests
//
//  Covers the v2.1 CloudKit-sync groundwork: the shared PersistenceController configuration
//  and the CloudKit-compatible schema (defaults + a round-trip through an in-memory store).
//  Live iCloud sync itself is verified on-device, not here.
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

// .serialized: several tests mutate the shared UserDefaults.standard sync flag, so they must
// not run in parallel with one another.
@Suite("Persistence & CloudKit compatibility", .serialized)
struct PersistenceTests {

    // MARK: - Sync opt-out flag

    @Test func syncEnabledDefaultsToOnWhenUnset() {
        let key = PersistenceController.syncEnabledDefaultsKey
        let original = UserDefaults.standard.object(forKey: key)
        defer {
            if let original { UserDefaults.standard.set(original, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }

        UserDefaults.standard.removeObject(forKey: key)
        #expect(PersistenceController.isSyncEnabled == true)
    }

    @Test func syncEnabledReflectsStoredFlag() {
        let key = PersistenceController.syncEnabledDefaultsKey
        let original = UserDefaults.standard.object(forKey: key)
        defer {
            if let original { UserDefaults.standard.set(original, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }

        UserDefaults.standard.set(false, forKey: key)
        #expect(PersistenceController.isSyncEnabled == false)

        UserDefaults.standard.set(true, forKey: key)
        #expect(PersistenceController.isSyncEnabled == true)
    }

    // MARK: - CloudKit-legal schema

    // Every non-optional stored attribute must have a default value for CloudKit. These
    // parameterless initializations only compile if those defaults exist.
    @Test func modelsExposeCloudKitLegalDefaults() {
        let profile = UserProfile()
        #expect(profile.unitPreference == UnitPreference.imperial.rawValue)
        #expect(profile.activeTheme == "animals")
        #expect(profile.notifyStreakAtRisk == false)

        let streak = StreakRecord()
        #expect(streak.shieldsAvailable == 1)
        #expect(streak.shieldedWeekKeysJSON == "[]")

        let achievement = UnlockedAchievement(milestoneId: "D1")
        #expect(achievement.milestoneId == "D1")
    }

    // The real schema must load into a container. Proves the model layer is internally valid.
    @Test @MainActor func schemaLoadsInMemory() throws {
        let config = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PersistenceController.schema, configurations: [config])
        #expect(container.configurations.isEmpty == false)
    }

    // Insert/fetch round-trip through the shared schema.
    @Test @MainActor func activityRoundTrips() throws {
        let config = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PersistenceController.schema, configurations: [config])
        let context = container.mainContext

        let log = ActivityLog(type: .distance, value: 5.0)
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ActivityLog>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.activityType == .distance)
        #expect(fetched.first?.value == 5.0)
    }
}
