//
//  AppViewModel.swift
//  FunFitness
//

import Foundation
import SwiftData

@MainActor
@Observable
final class AppViewModel {
    // Source of truth — synced from ContentView's @Query result
    var activities: [ActivityLog] = [] {
        didSet { refreshTotals() }
    }

    // MARK: - Totals (cached per type)

    // Rebuilt in one pass whenever `activities` is reassigned. Scanning every activity on each
    // read cost ~120 ms per Home render at 9,000 entries. Editing an entry in place doesn't
    // reassign the array, so in-place edits must call refreshTotals(). (v2.4)
    private var cachedTotals: [ActivityType: Double] = [:]

    /// Recomputes per-type totals. Call after changing an activity's value in place.
    func refreshTotals() {
        var totals: [ActivityType: Double] = [:]
        for activity in activities {
            totals[activity.activityType, default: 0] += activity.effectiveValue
        }
        cachedTotals = totals
    }

    /// Total accumulated (effective) value for a given activity type. Weight multiplies by
    /// reps via `effectiveValue`; other types accumulate their value. One place, all types. (v2.2)
    func total(for type: ActivityType) -> Double {
        cachedTotals[type] ?? 0
    }

    var totalDistance: Double { total(for: .distance) }

    // Accumulates value × (reps ?? 1) for each weight entry.
    var totalWeight: Double { total(for: .weight) }

    var totalActivities: Int { activities.count }

    // Most recently logged activity, for one-tap repeat.
    var lastActivity: ActivityLog? {
        activities.max { $0.loggedAt < $1.loggedAt }
    }

    var isActiveThisWeek: Bool {
        let calendar = Calendar.current
        let thisWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return activities.contains { activity in
            let activityWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: activity.loggedAt)
            return activityWeek == thisWeek
        }
    }

    // MARK: - Stored state

    var unlockedAchievementIds: Set<String> = []
    // Set by a local activity delete so the next reconcile may revoke badges that are no longer
    // earned. Changes arriving from CloudKit never revoke. (v2.3)
    var revokeAchievementsOnNextReconcile: Bool = false
    // Set after a HealthKit import adds workouts, so the next reconcile celebrates the badges it
    // unlocks instead of backfilling them silently. (v2.4)
    var celebrateNewlyEarnedOnNextReconcile: Bool = false
    // Completed monthly-challenge badge keys ("<id>#<year>"), synced from the store. (v2.2)
    var unlockedChallengeKeys: Set<String> = []
    var activePack: ThemePack = ThemePackCatalog.default
    var unitPreference: UnitPreference = .imperial
    var pendingMilestones: [Milestone] = []
    var showMilestoneModal: Bool = false

    // MARK: - Streak state (updated by ContentView after each activity change)
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var isActiveThisWeekStreak: Bool = false
    var shieldsAvailable: Int = 0
    var pendingShieldActivation: Bool = false

    // MARK: - Achievement reconcile & celebration (v2.4)

    /// Reconciles stored badges with current totals. Revocation is allowed when `forceRevocation`
    /// is set (local edit) or a local delete flagged it; both flags are consumed here. Badges
    /// newly unlocked by a flagged HealthKit import are celebrated.
    @discardableResult
    func reconcileAchievements(
        records: [UnlockedAchievement],
        context: ModelContext,
        forceRevocation: Bool = false
    ) -> Set<String> {
        let allowRevocation = forceRevocation || revokeAchievementsOnNextReconcile
        let shouldCelebrate = celebrateNewlyEarnedOnNextReconcile
        revokeAchievementsOnNextReconcile = false
        celebrateNewlyEarnedOnNextReconcile = false

        let result = AchievementReconciler.reconcile(
            earned: earnedMilestoneIds(),
            records: records,
            allowRevocation: allowRevocation,
            context: context
        )
        unlockedAchievementIds = result.unlocked
        if shouldCelebrate {
            celebrate(result.inserted.compactMap(ComparisonEngine.milestone(withId:)))
        }
        return result.inserted
    }

    /// Shows the celebration screen for newly crossed milestones, at most one per activity type:
    /// the highest one crossed. A big backdated entry or a history import shows one screen, not
    /// a screen per milestone. Adds to a celebration that's already showing.
    func celebrate(_ crossed: [Milestone]) {
        var highest: [ActivityUnit: Milestone] = [:]
        for milestone in crossed where milestone.threshold > (highest[milestone.unit]?.threshold ?? -1) {
            highest[milestone.unit] = milestone
        }
        let shown = Set(pendingMilestones.map(\.id))
        let top = crossed.filter { highest[$0.unit]?.id == $0.id && !shown.contains($0.id) }
        guard !top.isEmpty else { return }
        if showMilestoneModal {
            pendingMilestones += top
        } else {
            pendingMilestones = top
            showMilestoneModal = true
        }
    }

    // MARK: - Milestone helpers

    func checkForMilestones(type: ActivityType, previousTotal: Double, newTotal: Double) -> [Milestone] {
        ComparisonEngine.checkForNewMilestones(
            type: type,
            previousTotal: previousTotal,
            newTotal: newTotal,
            unlockedIds: unlockedAchievementIds
        )
    }

    func remainingToNextMilestone(type: ActivityType) -> (milestone: Milestone?, remaining: Double) {
        let currentTotal = total(for: type)
        guard let next = ComparisonEngine.nextMilestone(for: type, currentTotal: currentTotal) else {
            return (nil, 0)
        }
        return (next, next.threshold - currentTotal)
    }

    func progressToNextMilestone(type: ActivityType) -> Double {
        let currentTotal = total(for: type)
        guard let next = ComparisonEngine.nextMilestone(for: type, currentTotal: currentTotal) else {
            return 1.0
        }
        let milestones = ComparisonEngine.milestones(for: type)
        let previousThreshold = milestones
            .filter { $0.threshold < next.threshold }
            .last?.threshold ?? 0.0
        let range = next.threshold - previousThreshold
        let progress = currentTotal - previousThreshold
        return range > 0 ? min(max(progress / range, 0), 1.0) : 0.0
    }

    func earnedMilestoneIds() -> Set<String> {
        // Every activity type contributes its earned milestones; iterating allCases means new
        // types participate automatically once they have a milestone array. (v2.2)
        var earned: Set<String> = []
        for type in ActivityType.allCases {
            let total = total(for: type)
            for milestone in ComparisonEngine.milestones(for: type) where milestone.isReached(by: total) {
                earned.insert(milestone.id)
            }
        }
        return earned
    }

    // MARK: - Absurdity Ticker

    /// "1,200 lbs is 2.9 grizzly bears 🐻". Restates the total as the active pack's best-fitting
    /// reference unit, so it keeps working past the last milestone. Nil with no activities. (v2.3)
    func absurdityTickerText(for type: ActivityType) -> String? {
        let currentTotal = total(for: type)
        guard let fit = ReferenceUnitEngine.bestFit(total: currentTotal, type: type, packId: activePack.id) else {
            return nil
        }
        return "\(displayTotal(for: type)) is \(fit.phrase) \(fit.unit.emoji)"
    }

    // MARK: - Unit-aware display helpers

    func displayDistance(_ km: Double) -> String {
        UnitConverter.distanceString(km, pref: unitPreference)
    }

    func displayWeight(_ kg: Double, reps: Int? = nil) -> String {
        UnitConverter.weightString(kg, reps: reps, pref: unitPreference)
    }

    /// Formatted running total for any activity type, in the user's units. Drives the
    /// data-driven Home/Progress cards so every type (incl. duration/reps) displays uniformly. (v2.2)
    func displayTotal(for type: ActivityType) -> String {
        UnitConverter.displayString(total(for: type), type: type, pref: unitPreference)
    }

    // MARK: - Monthly Challenge (v2.2)

    /// The challenge active for the given date's month, if any.
    func currentChallenge(on date: Date = Date()) -> Challenge? {
        ChallengeEngine.activeChallenge(on: date)
    }

    /// Fractional progress [0,1] toward the given challenge this month.
    func challengeFraction(_ challenge: Challenge, on date: Date = Date()) -> Double {
        ChallengeEngine.fractionComplete(challenge, in: activities, on: date)
    }

    /// Raw accumulated value toward the challenge this month, in SI units.
    func challengeProgressValue(_ challenge: Challenge, on date: Date = Date()) -> Double {
        ChallengeEngine.progress(for: challenge, in: activities, on: date)
    }

    /// Whether this year's occurrence of the challenge has been awarded.
    func isChallengeComplete(_ challenge: Challenge, on date: Date = Date()) -> Bool {
        let year = Calendar.current.component(.year, from: date)
        return unlockedChallengeKeys.contains(ChallengeEngine.unlockKey(id: challenge.id, year: year))
    }

    // MARK: - Silly Title

    var sillyTitle: SillyTitle {
        SillyTitleEngine.sillyTitle(unlockedIds: unlockedAchievementIds)
    }
}
