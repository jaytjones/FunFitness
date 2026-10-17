//
//  ContentView.swift
//  FunFitness
//

import SwiftUI
import SwiftData
import WidgetKit
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var achievements: [UnlockedAchievement]
    @Query private var activities: [ActivityLog]
    @Query private var streakRecords: [StreakRecord]
    @Query private var unlockedChallenges: [UnlockedChallenge]

    @State private var viewModel = AppViewModel()
    @State private var selectedTab = 0
    @State private var currentMilestoneIndex = 0

    @Environment(\.scenePhase) private var scenePhase

    private var hasProfile: Bool { !profiles.isEmpty }

    var body: some View {
        Group {
            if !hasProfile {
                OnboardingView { }
            } else {
                TabView(selection: $selectedTab) {
                    HomeView(viewModel: viewModel)
                        .tabItem { Label("Home", systemImage: "house") }
                        .tag(0)

                    ProgressTabView(viewModel: viewModel)
                        .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                        .tag(1)

                    AchievementsView(viewModel: viewModel)
                        .tabItem { Label("Achievements", systemImage: "trophy") }
                        .tag(2)

                    ProfileView(viewModel: viewModel)
                        .tabItem { Label("Profile", systemImage: "person.circle") }
                        .tag(3)
                }
                .tint(Color(hex: "#A78BFA"))
                .fullScreenCover(isPresented: $viewModel.showMilestoneModal) {
                    if currentMilestoneIndex < viewModel.pendingMilestones.count {
                        let milestone = viewModel.pendingMilestones[currentMilestoneIndex]
                        MilestoneView(milestone: milestone, pack: viewModel.activePack, pref: viewModel.unitPreference) {
                            currentMilestoneIndex += 1
                            if currentMilestoneIndex >= viewModel.pendingMilestones.count {
                                viewModel.showMilestoneModal = false
                                currentMilestoneIndex = 0
                                viewModel.pendingMilestones = []
                            }
                        }
                        .id(milestone.id)
                    }
                }
                .onAppear {
                    if let profile = profiles.first {
                        viewModel.activePack     = ThemePackCatalog.pack(id: profile.activeTheme)
                        viewModel.unitPreference = profile.unitPref
                    }
                    viewModel.activities = activities
                    viewModel.unlockedAchievementIds = Set(achievements.map(\.milestoneId))
                    reconcileAchievements()
                    reconcileChallenges()
                    updateStreak()
                    writeWidgetData()
                }
                .task(id: hasProfile) {
                    await syncHealthKitIfEnabled()
                }
                .task {
                    // A Live Activity left from a previous launch has no workout behind it now.
                    WorkoutLiveActivityController.shared.endOrphanedActivities(tracker: WorkoutTracker.shared)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        // A run ended from the Live Activity's End button waits for review here.
                        if WorkoutTracker.shared.phase == .finished { viewModel.showTracker = true }
                        // Catch in-place edits that synced from another device while away.
                        viewModel.refreshTotals()
                        Task { await syncHealthKitIfEnabled() }
                    }
                }
                .onChange(of: viewModel.activePack) {
                    profiles.first?.activeTheme = viewModel.activePack.id
                }
                .onChange(of: activities) {
                    viewModel.activities = activities
                    reconcileAchievements()
                    reconcileChallenges()
                    updateStreak()
                    scheduleNotificationsIfNeeded()
                    writeWidgetData()
                }
                .onChange(of: achievements) {
                    viewModel.unlockedAchievementIds = Set(achievements.map(\.milestoneId))
                }
                .onChange(of: unlockedChallenges) {
                    // Resync when a completed challenge arrives from another device via CloudKit.
                    viewModel.unlockedChallengeKeys = Set(unlockedChallenges.map(\.challengeKey))
                }
                .onChange(of: viewModel.pendingShieldActivation) {
                    if viewModel.pendingShieldActivation {
                        viewModel.pendingShieldActivation = false
                        activateStreakShield()
                    }
                }
                .onChange(of: profiles) {
                    if let profile = profiles.first {
                        viewModel.activePack     = ThemePackCatalog.pack(id: profile.activeTheme)
                        viewModel.unitPreference = profile.unitPref
                    }
                }
            }
        }
        // Live walk/run tracking (3.1). Attached here, not on the TabView, so it doesn't compete
        // with the milestone cover; a saved run's celebrations show once this one has closed.
        .fullScreenCover(isPresented: $viewModel.showTracker, onDismiss: {
            let crossed = viewModel.milestonesAfterTracker
            viewModel.milestonesAfterTracker = []
            viewModel.celebrate(crossed)
        }) {
            TrackWorkoutView(viewModel: viewModel)
        }
    }

    // MARK: - Streak

    private var streakRecord: StreakRecord {
        if let existing = streakRecords.first { return existing }
        let record = StreakRecord()
        modelContext.insert(record)
        return record
    }

    private func updateStreak() {
        let record = streakRecord
        record.regenerateShieldIfNeeded()
        let result = StreakEngine.compute(
            activities: activities,
            shieldedWeekKeysJSON: record.shieldedWeekKeysJSON
        )
        record.currentStreak = result.currentStreak
        record.longestStreak = max(record.longestStreak, result.longestStreak)
        record.lastUpdated   = Date()
        viewModel.currentStreak          = result.currentStreak
        viewModel.longestStreak          = result.longestStreak
        viewModel.isActiveThisWeekStreak = result.isActiveThisWeek
        viewModel.shieldsAvailable       = record.shieldsAvailable
        try? modelContext.save()
    }

    func activateStreakShield() {
        let record = streakRecord
        if StreakEngine.activateShield(record: record) {
            viewModel.shieldsAvailable = record.shieldsAvailable
            updateStreak()
        }
    }

    // MARK: - HealthKit

    // Imports new distance workouts when the user has opted in. Inserting the
    // new logs triggers onChange(of: activities), which runs the existing
    // reconcile/streak/notification/widget pipeline. The flag makes that reconcile
    // celebrate badges the import unlocked (one screen per type) instead of adding
    // them silently. It's set after the import so badges arriving from iCloud
    // during the import aren't celebrated. (v2.4)
    private func syncHealthKitIfEnabled() async {
        guard let profile = profiles.first, profile.healthKitImportEnabled else { return }
        let imported = await HealthKitSync.run(existing: activities, context: modelContext)
        if imported > 0 {
            viewModel.celebrateNewlyEarnedOnNextReconcile = true
        }
    }

    // MARK: - Notifications

    private func scheduleNotificationsIfNeeded() {
        guard let profile = profiles.first else { return }
        let nm = NotificationManager.shared
        if profile.notifyStreakAtRisk && !viewModel.isActiveThisWeekStreak {
            nm.scheduleStreakAtRisk(streakCount: viewModel.currentStreak)
        } else {
            nm.cancel(.streakAtRisk)
        }
        if profile.notifyWeeklyRecap {
            let weekCount = activities.filter {
                Calendar.current.isDate($0.loggedAt, equalTo: Date(), toGranularity: .weekOfYear)
            }.count
            nm.scheduleWeeklyRecap(streakCount: viewModel.currentStreak, weeklyActivityCount: weekCount)
        } else {
            nm.cancel(.weeklyRecap)
        }
        if profile.notifyMilestoneNudge {
            for type in ActivityType.allCases {
                let progress = viewModel.progressToNextMilestone(type: type)
                if progress >= 0.9, let milestone = viewModel.remainingToNextMilestone(type: type).milestone {
                    let remaining = viewModel.remainingToNextMilestone(type: type).remaining
                    let remainingDisplay = UnitConverter.displayString(remaining, type: type, pref: viewModel.unitPreference)
                    nm.scheduleMilestoneNudge(
                        type: type,
                        milestoneId: milestone.id,
                        milestoneTitle: milestone.title(pref: viewModel.unitPreference),
                        remaining: remainingDisplay
                    )
                }
            }
        } else {
            // Cancel per-type identifiers used by scheduleMilestoneNudge
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ActivityType.allCases.map {
                    "\(NotificationCategory.milestoneNudge.rawValue)_\($0.rawValue)"
                }
            )
        }
        if profile.notifyComparisonOfDay {
            nm.scheduleComparisonOfDay(facts: NotificationManager.dailyComparisonFacts)
        } else {
            nm.cancel(.comparisonDay)
        }
    }

    // MARK: - Widget data

    private func writeWidgetData() {
        let defaults = UserDefaults(suiteName: "group.com.discoverhealthquest.funfitness")
        defaults?.set(viewModel.currentStreak,                            forKey: "streak")
        defaults?.set(viewModel.longestStreak,                            forKey: "longestStreak")
        defaults?.set(viewModel.isActiveThisWeekStreak,                   forKey: "activeThisWeek")
        defaults?.set(viewModel.progressToNextMilestone(type: .distance), forKey: "distanceProgress")
        defaults?.set(viewModel.progressToNextMilestone(type: .weight),   forKey: "weightProgress")
        let nextDist = viewModel.remainingToNextMilestone(type: .distance).milestone?.title(pref: viewModel.unitPreference) ?? "All done!"
        let nextWt   = viewModel.remainingToNextMilestone(type: .weight).milestone?.title(pref: viewModel.unitPreference) ?? "All done!"
        defaults?.set(nextDist,                   forKey: "nextDistanceMilestone")
        defaults?.set(nextWt,                     forKey: "nextWeightMilestone")
        defaults?.set(viewModel.sillyTitle.title, forKey: "sillyTitle")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Achievement Reconciliation

    // Inserts earned achievements not yet recorded and removes duplicate rows. Badges are only
    // revoked after a local delete flags it; see AchievementReconciler for why. (v2.3)
    private func reconcileAchievements() {
        viewModel.reconcileAchievements(records: achievements, context: modelContext)
    }

    // MARK: - Challenge Reconciliation (v2.2)

    // Evaluates only the CURRENT month's challenge occurrence: awards its badge when the month's
    // logged total reaches the target, and revokes it if a same-month edit/delete drops the total
    // back below target. Past occurrences are permanent badges and are never re-evaluated.
    private func reconcileChallenges() {
        let now = Date()
        var keys = Set(unlockedChallenges.map(\.challengeKey))

        if let challenge = ChallengeEngine.activeChallenge(on: now) {
            let year = Calendar.current.component(.year, from: now)
            let key  = ChallengeEngine.unlockKey(id: challenge.id, year: year)
            let complete = ChallengeEngine.isComplete(challenge, in: activities, on: now)
            let recorded = unlockedChallenges.first { $0.challengeKey == key }

            if complete && recorded == nil {
                modelContext.insert(UnlockedChallenge(challengeId: challenge.id, year: year))
                keys.insert(key)
                try? modelContext.save()
            } else if !complete, let recorded {
                modelContext.delete(recorded)
                keys.remove(key)
                try? modelContext.save()
            }
        }

        viewModel.unlockedChallengeKeys = keys
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, ActivityLog.self, UnlockedAchievement.self, UnlockedChallenge.self], inMemory: true)
}
