//
//  StyleAccessTests.swift
//  FunFitnessTests
//
//  3.3 unlock rules (Jay, 2026-11-15): a streak ladder on the longest-ever streak (Arcade 4 weeks,
//  Field Guide 8, +4 per later Style) or one "Unlock all styles" purchase; Playful Bold is free;
//  unreleased Styles are the owner's alone.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Style access")
struct StyleAccessTests {

    private func access(streak: Int = 0, purchased: Bool = false, owner: Bool = false) -> StyleAccess {
        StyleAccess(longestStreakWeeks: streak, ownsAllStyles: purchased, isOwner: owner)
    }

    @Test func playfulBoldIsAlwaysFreeAndAvailable() {
        let none = access()
        #expect(none.status(of: .playfulBold) == .free)
        #expect(none.isAvailable(.playfulBold))
        #expect(none.visibleStyles.contains(.playfulBold))
    }

    @Test func streakLadder() {
        // Arcade's goal is 4 weeks, Field Guide's 8.
        #expect(access(streak: 3).status(streakGoal: 4) == .locked(weeksToGo: 1))
        #expect(access(streak: 4).status(streakGoal: 4) == .earned)
        #expect(access(streak: 4).status(streakGoal: 8) == .locked(weeksToGo: 4))
        #expect(access(streak: 8).status(streakGoal: 8) == .earned)
        #expect(access(streak: 12).status(streakGoal: 8) == .earned)
    }

    @Test func noStreakShowsTheFullGoal() {
        #expect(access(streak: 0).status(streakGoal: 4) == .locked(weeksToGo: 4))
    }

    @Test func purchaseUnlocksEveryStyleNow() {
        let bought = access(streak: 0, purchased: true)
        #expect(bought.status(streakGoal: 4) == .purchased)
        #expect(bought.status(streakGoal: 8) == .purchased)
        #expect(bought.status(streakGoal: 40) == .purchased)
    }

    @Test func anEarnedUnlockReadsAsEarnedEvenAfterBuying() {
        #expect(access(streak: 5, purchased: true).status(streakGoal: 4) == .earned)
    }

    @Test func ownerHasEverything() {
        let owner = access(owner: true)
        #expect(owner.status(streakGoal: 4) == .owner)
        #expect(owner.status(streakGoal: 8) == .owner)
        #expect(owner.status(streakGoal: nil) == .free)
    }

    @Test func lockedIsNotUnlocked() {
        #expect(!StyleAccess.Status.locked(weeksToGo: 2).isUnlocked)
        #expect(StyleAccess.Status.earned.isUnlocked)
        #expect(StyleAccess.Status.purchased.isUnlocked)
        #expect(StyleAccess.Status.owner.isUnlocked)
        #expect(StyleAccess.Status.free.isUnlocked)
    }

    @Test func everyStreakStyleSitsOnTheLadder() {
        // Goals are 4, 8, 12, … in catalog order, so a new Style can't skip a rung.
        let goals = StyleID.allCases.compactMap(\.streakWeeksToUnlock)
        #expect(goals == goals.indices.map { ($0 + 1) * 4 })
    }

    @Test func everyReleasedStyleIsVisibleToEveryone() {
        let none = access()
        for style in StyleID.allCases where style.isReleased {
            #expect(none.isVisible(style))
        }
    }

    @Test func unavailableSyncedStyleShowsAsDefault() {
        let none = access()
        #expect(StyleID.resolve(StyleID.playfulBold.rawValue, isAvailable: none.isAvailable) == .playfulBold)
    }

    // MARK: Owner check

    @Test func ownerHashMatchesOnlyTheOwnersRecord() {
        let ownerHash = OwnerCheck.hash(recordName: "_owner-record")
        #expect(OwnerCheck.isOwner(recordName: "_owner-record", ownerHashes: [ownerHash]))
        #expect(!OwnerCheck.isOwner(recordName: "_someone-else", ownerHashes: [ownerHash]))
        #expect(!OwnerCheck.isOwner(recordName: "_owner-record", ownerHashes: []))
    }

    @Test func hashIsLowercaseSHA256Hex() {
        let hash = OwnerCheck.hash(recordName: "abc")
        #expect(hash == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func storedOwnerHashesAreWellFormed() {
        for hash in OwnerCheck.ownerRecordHashes {
            #expect(hash.count == 64)
            #expect(hash.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        }
    }
}
