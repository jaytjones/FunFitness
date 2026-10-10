//
//  AchievementReconciler.swift
//  FunFitness
//
//  Pure planning step for keeping UnlockedAchievement rows in line with the milestones the
//  current totals have earned. Callers apply the plan to their ModelContext. (v2.3)
//

import Foundation
import SwiftData

enum AchievementReconciler {

    struct Plan {
        /// Earned milestone ids with no stored row yet.
        var idsToInsert: Set<String> = []
        /// Duplicate rows plus (when revocation is allowed) rows for milestones no longer earned.
        var recordsToDelete: [UnlockedAchievement] = []
        /// Milestone ids that are no longer unlocked once the plan is applied.
        var revokedIds: Set<String> = []
    }

    /// Builds the changes needed to reconcile `records` with `earned`.
    ///
    /// - Duplicates: CloudKit has no unique constraints, so two devices can each insert a row for
    ///   the same milestone. Only the earliest-unlocked row per id is kept.
    /// - Revocation is opt-in. Remote CloudKit changes arrive in arbitrary order, so on a device
    ///   that has synced only some activities the totals look low; revoking then would delete real
    ///   badges everywhere. Callers allow it only after a local edit or delete.
    /// - Ids missing from `knownIds` are never revoked. They come from a newer build on another
    ///   device, and deleting them would make the two builds fight over the same rows.
    static func plan(
        earned: Set<String>,
        records: [UnlockedAchievement],
        knownIds: Set<String> = Set(ComparisonEngine.byId.keys),
        allowRevocation: Bool
    ) -> Plan {
        var plan = Plan()
        var kept: [String: UnlockedAchievement] = [:]

        for record in records.sorted(by: { $0.unlockedAt < $1.unlockedAt }) {
            if kept[record.milestoneId] == nil {
                kept[record.milestoneId] = record
            } else {
                plan.recordsToDelete.append(record)
            }
        }

        plan.idsToInsert = earned.subtracting(kept.keys)

        if allowRevocation {
            for (id, record) in kept where knownIds.contains(id) && !earned.contains(id) {
                plan.recordsToDelete.append(record)
                plan.revokedIds.insert(id)
            }
        }

        return plan
    }

    /// Plans and applies a reconcile pass, returning the unlocked milestone ids afterwards.
    @MainActor
    static func reconcile(
        earned: Set<String>,
        records: [UnlockedAchievement],
        allowRevocation: Bool,
        context: ModelContext
    ) -> Set<String> {
        let plan = plan(earned: earned, records: records, allowRevocation: allowRevocation)

        for id in plan.idsToInsert {
            context.insert(UnlockedAchievement(milestoneId: id))
        }
        for record in plan.recordsToDelete {
            context.delete(record)
        }
        if !plan.idsToInsert.isEmpty || !plan.recordsToDelete.isEmpty {
            try? context.save()
        }

        return Set(records.map(\.milestoneId))
            .subtracting(plan.revokedIds)
            .union(plan.idsToInsert)
    }
}
