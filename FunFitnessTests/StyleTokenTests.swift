//
//  StyleTokenTests.swift
//  FunFitnessTests
//
//  Tokens follow the active Style (3.3). These check the tables directly, not through the global
//  `StyleRuntime`, so they don't disturb other suites that resolve colors in parallel.
//

import Testing
import Foundation
import SwiftUI
@testable import FunFitness

@Suite("Style tokens")
struct StyleTokenTests {

    @Test func playfulBoldIsUnchanged() {
        // The 3.2 values (Sunny / After Dark); AdaptiveColorTests covers bg and surface end to end.
        #expect(FFColorToken.bg.pair(in: .playfulBold) == (0xFFD43B, 0x17122E))
        #expect(FFColorToken.ink.pair(in: .playfulBold) == (0x1E1640, 0xFFF8E1))
        #expect(FFColorToken.accent.pair(in: .playfulBold) == (0xFF5C8A, 0xFF6E98))
        #expect(FFColorToken.link.pair(in: .playfulBold) == (0x6C3CE9, 0xFFD43B))
    }

    @Test func defaultStyleIsPlayfulBold() {
        #expect(StyleID.default == .playfulBold)
    }

    #if INTERNAL_STYLES
    @Test func arcadeUsesItsOwnPalette() {
        // Light = Daylight, dark = Arcade (docs/design/arcade/tokens.json).
        #expect(FFColorToken.bg.pair(in: .arcade) == (0xF1EEFF, 0x0B0A1F))
        #expect(FFColorToken.accent.pair(in: .arcade) == (0x087068, 0x3CF0E0))
        #expect(FFColorToken.typeWeight.pair(in: .arcade) == (0x7A5800, 0xFFD23F))
    }

    @Test func everyTokenHasAnArcadeValueExceptTheShadow() {
        // A new token must get an Arcade value (or a deliberate nil, documented in ArcadeStyle).
        let missing = FFColorToken.allCases.filter { $0.arcade == nil }
        #expect(missing == [.shadowInk])
        #expect(FFColorToken.shadowInk.pair(in: .arcade) == FFColorToken.shadowInk.playfulBold)
    }

    @Test func arcadeTypeScale() {
        #expect(FFTextStyle.displayHero.arcadeSize == 34)
        #expect(FFTextStyle.body.arcadeSize == 16)
        #expect(FFTextStyle.label.arcadeDesign == .monospaced)
        #expect(FFTextStyle.display.arcadeIsUppercase)
        #expect(FFTextStyle.label.arcadeIsUppercase)
        #expect(!FFTextStyle.body.arcadeIsUppercase)
    }

    @Test func arcadeIsUnreleasedAndOnTheLadder() {
        #expect(!StyleID.arcade.isReleased)
        #expect(StyleID.arcade.streakWeeksToUnlock == 4)
    }

    @Test func onlyTheOwnerSeesArcadeBeforeLaunch() {
        let owner = StyleAccess(longestStreakWeeks: 0, ownsAllStyles: false, isOwner: true)
        let earned = StyleAccess(longestStreakWeeks: 10, ownsAllStyles: true, isOwner: false)
        #expect(StyleID.resolve("arcade", isAvailable: owner.isAvailable) == .arcade)
        // Unreleased: even a long streak plus the purchase doesn't show it to anyone else.
        #expect(StyleID.resolve("arcade", isAvailable: earned.isAvailable) == .playfulBold)
        #expect(!earned.visibleStyles.contains(.arcade))
        #expect(owner.visibleStyles == [.playfulBold, .arcade])
    }
    #endif
}
