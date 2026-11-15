//
//  StyleFallbackTests.swift
//  FunFitnessTests
//
//  `activeStyleID` syncs. A Style picked in Jay's Internal build reaches devices on Release builds
//  that don't have it: they must show Playful Bold and leave the synced value alone. (3.3 plan)
//

import Testing
import Foundation
import SwiftData
@testable import FunFitness

@Suite("Style fallback")
@MainActor
struct StyleFallbackTests {
    // Kept as a property so the in-memory store outlives each test's context.
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: UserProfile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func knownStyleResolves() {
        #expect(StyleID.resolve(StyleID.playfulBold.rawValue) == .playfulBold)
    }

    @Test func unknownStyleFallsBackToDefault() {
        #expect(StyleID.resolve("arcade") == .default)
        #expect(StyleID.resolve("") == .default)
        #expect(StyleID.resolve("some-future-style") == .default)
    }

    @Test func unavailableStyleFallsBackToDefault() {
        // e.g. an unreleased Style on someone else's account.
        let resolved = StyleID.resolve(StyleID.playfulBold.rawValue, isAvailable: { _ in false })
        #expect(resolved == .default)
    }

    @Test func readingTheStyleNeverOverwritesTheSyncedChoice() throws {
        let context = container.mainContext
        let profile = UserProfile()
        profile.activeStyleID = "arcade"   // synced from an Internal build
        context.insert(profile)
        try context.save()

        #expect(profile.style == .default)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(stored.activeStyleID == "arcade")
    }

    @Test func styleRawValuesAreStable() {
        // Persisted and synced: renaming one strands everyone who picked it.
        #expect(StyleID.playfulBold.rawValue == "playful-bold")
    }
}
