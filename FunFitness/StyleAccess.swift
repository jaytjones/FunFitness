//
//  StyleAccess.swift
//  FunFitness
//
//  Who can see and use each visual Style (3.3 "Your Style"; rules from Jay, 2026-11-15):
//  - Playful Bold is always free.
//  - A Style unlocks when the longest-ever streak reaches its goal (Arcade 4 weeks, Field Guide 8,
//    +4 per later Style), or sooner with the one "Unlock all styles" purchase.
//  - Unreleased Styles (compiled only into Debug/Internal builds) are shown only to the owner,
//    and the owner can use every Style without earning or buying it.
//  All of it is derived (streak record, App Store entitlement, iCloud identity), so nothing new is
//  stored or synced. The decision is a pure value so it's unit-tested.
//

import Foundation
import CryptoKit
import CloudKit
import os

nonisolated struct StyleAccess: Equatable, Sendable {
    /// Longest streak ever, in weeks (`StreakRecord.longestStreak`, a synced high-water mark, so
    /// deleting old workouts doesn't take an unlock away).
    var longestStreakWeeks: Int
    /// Owns the "Unlock all styles" purchase.
    var ownsAllStyles: Bool
    /// This iCloud account is the owner's (see `OwnerCheck`).
    var isOwner: Bool

    enum Status: Equatable, Sendable {
        case free
        case earned
        case purchased
        case owner
        /// Not yet: this many more weeks of streak, or the purchase.
        case locked(weeksToGo: Int)

        var isUnlocked: Bool {
            if case .locked = self { return false }
            return true
        }
    }

    /// Unreleased Styles exist for the owner only.
    func isVisible(_ style: StyleID) -> Bool {
        style.isReleased || isOwner
    }

    func status(of style: StyleID) -> Status {
        status(streakGoal: style.streakWeeksToUnlock)
    }

    /// The rule itself, for a Style with this streak goal (nil = free).
    func status(streakGoal: Int?) -> Status {
        guard let goal = streakGoal else { return .free }
        if isOwner { return .owner }
        if longestStreakWeeks >= goal { return .earned }
        if ownsAllStyles { return .purchased }
        return .locked(weeksToGo: goal - longestStreakWeeks)
    }

    /// Can be shown and applied. Pass to `StyleID.resolve(_:isAvailable:)` so a synced Style this
    /// person can't use shows as the default (and the synced choice is left alone).
    func isAvailable(_ style: StyleID) -> Bool {
        isVisible(style) && status(of: style).isUnlocked
    }

    /// The Styles to list in the picker, in catalog order.
    var visibleStyles: [StyleID] {
        StyleID.allCases.filter(isVisible)
    }
}

// MARK: - Owner check

/// Recognizes the owner's iCloud account without any account system: the app's CloudKit user
/// record ID is stable across the owner's devices and visible only to this app, and only its
/// SHA-256 is kept here. No iCloud, offline, or no hash set → not the owner; normal rules apply.
/// Only the owner's account is ever listed: a developer override is fine, hidden unlocks of paid
/// content for customers are not (App Review).
nonisolated enum OwnerCheck {
    /// SHA-256 (hex, lowercase) of the owner's CloudKit user record name, copied from the Debug log
    /// (see `currentAccountIsOwner`). Jay's iCloud account, added 2026-11-15.
    static let ownerRecordHashes: Set<String> = [
        "025412e9f6f319294d6876ae765768c513e06cca95a8e35571eb6df85532400d",
    ]

    static func hash(recordName: String) -> String {
        SHA256.hash(data: Data(recordName.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func isOwner(recordName: String, ownerHashes: Set<String> = ownerRecordHashes) -> Bool {
        ownerHashes.contains(hash(recordName: recordName))
    }

    /// Asks iCloud for this account's record ID in the app's container. In Debug builds it logs the
    /// hash so the owner can copy it into `ownerRecordHashes` (a hash, never the ID itself).
    static func currentAccountIsOwner(containerIdentifier: String) async -> Bool {
        do {
            let id = try await CKContainer(identifier: containerIdentifier).userRecordID()
            #if DEBUG
            Logger(subsystem: "com.jaytjones.FunFitness", category: "Styles")
                .notice("Owner hash for this iCloud account: \(hash(recordName: id.recordName), privacy: .public)")
            #endif
            return isOwner(recordName: id.recordName)
        } catch {
            return false
        }
    }
}
