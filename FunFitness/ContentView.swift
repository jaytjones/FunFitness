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
    @Query private var customExercises: [CustomExercise]

    @State private var viewModel = AppViewModel()
    @State private var selectedTab: AppTab = .home
    @State private var currentMilestoneIndex = 0
    // The LogButton's sheet (3.2). nil type = open on the last-used type.
    @State private var showLogSheet = false
    @State private var logType: ActivityType?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Playful Bold's floating word tabs; at accessibility text sizes the system tab bar is used
    /// instead so labels never shrink (TabBar.md).
    private var usesFloatingTabBar: Bool { !dynamicTypeSize.isAccessibilitySize }

    private var hasProfile: Bool { !profiles.isEmpty }

    /// The tabs and what they present (log sheet, milestone and checkpoint covers). Split out of
    /// `body` so the compiler can type-check it.
    private var tabs: some View {
        TabView(selection: $selectedTab) {
            tabContent(HomeView(viewModel: viewModel), tab: .home)
            tabContent(ProgressTabView(viewModel: viewModel), tab: .progress)
            tabContent(AchievementsView(viewModel: viewModel), tab: .badges)
            tabContent(ProfileView(viewModel: viewModel), tab: .you)
        }
        .tint(.ffInk)
        // Pinned "now tracking" bar on every tab while a walk/run or strength session runs
        // (FB-0003). With the floating tab bar it sits in the bottom bar instead.
        .nowTrackingAccessory(viewModel: viewModel, isShowing: showsNowTracking && !usesFloatingTabBar)
        .sheet(isPresented: $showLogSheet, onDismiss: viewModel.presentLiveSessionIfRequested) {
            LogActivitySheet(viewModel: viewModel, initialType: logType)
        }
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
        // A journey checkpoint, once no other celebration or live session is on screen. (3.2)
        .fullScreenCover(item: checkpointBinding) { moment in
            JourneyCheckpointView(moment: moment) { showNextCheckpoint() }
        }
    }

    // MARK: - Tabs and bottom bar (3.2)

    /// One tab: its content with the system tab bar hidden (floating bar shown) or shown (large
    /// text), and the bottom bar inset so content scrolls under it.
    private func tabContent(_ content: some View, tab: AppTab) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .toolbar(usesFloatingTabBar ? .hidden : .automatic, for: .tabBar)
            .tabItem { Label(tab.label, systemImage: tab.symbol) }
            .tag(tab)
    }

    /// Now-tracking row (when a session runs), then the word tabs and the LogButton.
    private var bottomBar: some View {
        VStack(spacing: FFSpace.s3) {
            if usesFloatingTabBar && showsNowTracking {
                NowTrackingBar(viewModel: viewModel, style: .inset)
            }
            HStack(spacing: FFSpace.s3) {
                if usesFloatingTabBar {
                    FFTabBar(selection: $selectedTab)
                } else {
                    Spacer()
                }
                LogButton(
                    onLog: { type in
                        logType = type
                        showLogSheet = true
                    },
                    repeatLastLabel: viewModel.lastActivity.map(repeatLabel),
                    onRepeatLast: repeatLast
                )
            }
        }
        .padding(.horizontal, FFSpace.s5)
        .padding(.top, FFSpace.s2)
        .padding(.bottom, FFSpace.s3)
    }

    // MARK: - Journey checkpoints (3.2)

    /// Checkpoints waiting after the one on screen.
    @State private var queuedCheckpoints: [CheckpointMoment] = []

    /// Only shows the cover when nothing else is presenting (milestones, live sessions).
    private var checkpointBinding: Binding<CheckpointMoment?> {
        Binding(
            get: {
                let busy = viewModel.showMilestoneModal || viewModel.showTracker || viewModel.showStrengthSession
                return busy ? nil : viewModel.checkpointMoment
            },
            set: { if $0 == nil { viewModel.checkpointMoment = nil } }
        )
    }

    private func showNextCheckpoint() {
        viewModel.checkpointMoment = queuedCheckpoints.isEmpty ? nil : queuedCheckpoints.removeFirst()
    }

    /// Celebrates checkpoints reached since last time, once each per journey run. The count is
    /// kept per device (a celebration is a local moment); `silently` just records progress, e.g.
    /// at launch, so history doesn't replay.
    private func checkJourneyCheckpoints(silently: Bool) {
        guard let profile = profiles.first,
              let journey = JourneyCatalog.journey(id: profile.activeJourneyID),
              let start = profile.journeyStartedAt else { return }
        let key = "journeyCelebrated.\(journey.id).\(Int(start.timeIntervalSince1970))"
        let entries = viewModel.activities
            .filter { $0.activityType == .distance }
            .map { (date: $0.loggedAt, km: $0.value) }
        let distance = JourneyEngine.distanceSince(start, entries: entries)
        let reachedCount = JourneyEngine.progress(journey: journey, distanceKm: distance).reached.count
        let celebrated = UserDefaults.standard.object(forKey: key) as? Int

        defer { UserDefaults.standard.set(reachedCount, forKey: key) }
        // First look at this journey run, or a quiet check: record without celebrating.
        guard !silently, let celebrated else { return }

        let fresh = JourneyEngine.checkpointsToCelebrate(journey: journey, distanceKm: distance, alreadyCelebrated: celebrated)
        guard !fresh.isEmpty else { return }
        let moments = fresh.enumerated().map { index, checkpoint in
            CheckpointMoment(
                journeyName: journey.name,
                checkpoint: checkpoint,
                isFinish: checkpoint == journey.checkpoints.last,
                position: index + 1,
                count: fresh.count
            )
        }
        queuedCheckpoints += moments.dropFirst()
        if viewModel.checkpointMoment == nil {
            viewModel.checkpointMoment = moments.first
        } else {
            queuedCheckpoints.insert(moments[0], at: 0)
        }
    }

    private func repeatLabel(for activity: ActivityLog) -> String {
        UnitConverter.displayString(activity.value, type: activity.activityType, reps: activity.reps, pref: viewModel.unitPreference)
    }

    private func repeatLast() {
        guard let last = viewModel.lastActivity else { return }
        let milestones = ActivityWriter.log(
            type: last.activityType,
            value: last.value,
            reps: last.reps,
            date: Date(),
            surface: last.surface,
            exerciseID: last.exerciseID,
            context: modelContext,
            viewModel: viewModel,
            writeBackToHealth: profiles.first?.healthKitWriteBackEnabled ?? false
        )
        viewModel.celebrate(milestones)
    }
    private var showsNowTracking: Bool { NowTrackingContent.isShowing }

    var body: some View {
        Group {
            if !hasProfile {
                OnboardingView { }
            } else {
                tabs
                .onAppear {
                    if let profile = profiles.first {
                        viewModel.activePack     = ThemePackCatalog.pack(id: profile.activeTheme)
                        viewModel.unitPreference = profile.unitPref
                    }
                    viewModel.activities = activities
                    ExerciseLibrary.shared.setCustom(customExercises)
                    WatchConnector.shared.configure(context: modelContext, viewModel: viewModel)
                    WatchConnector.shared.sendContext(pref: viewModel.unitPreference, viewModel: viewModel)
                    viewModel.unlockedAchievementIds = Set(achievements.map(\.milestoneId))
                    reconcileAchievements()
                    reconcileChallenges()
                    updateStreak()
                    writeWidgetData()
                    checkJourneyCheckpoints(silently: true)
                }
                .task(id: hasProfile) {
                    await syncHealthKitIfEnabled()
                }
                .task {
                    // A Live Activity left from a previous launch has no workout behind it now.
                    WorkoutLiveActivityController.shared.endOrphanedActivities(
                        tracker: WorkoutTracker.shared, strength: StrengthSessionManager.shared)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        // A session ended from the Live Activity's End button waits for review here.
                        if WorkoutTracker.shared.phase == .finished { viewModel.showTracker = true }
                        if StrengthSessionManager.shared.phase == .finished { viewModel.showStrengthSession = true }
                        // Catch in-place edits that synced from another device while away.
                        viewModel.refreshTotals()
                        Task { await syncHealthKitIfEnabled() }
                    }
                }
                .onChange(of: viewModel.activePack) {
                    profiles.first?.activeTheme = viewModel.activePack.id
                }
                .onChange(of: customExercises) {
                    ExerciseLibrary.shared.setCustom(customExercises)
                    WatchConnector.shared.sendContext(pref: viewModel.unitPreference, viewModel: viewModel)
                }
                .onChange(of: activities) {
                    viewModel.activities = activities
                    reconcileAchievements()
                    reconcileChallenges()
                    updateStreak()
                    scheduleNotificationsIfNeeded()
                    writeWidgetData()
                    checkJourneyCheckpoints(silently: false)
                    // After the streak update, so the Watch gets the new streak too.
                    WatchConnector.shared.sendContext(pref: viewModel.unitPreference, viewModel: viewModel)
                }
                .onChange(of: profiles.first?.journeyStartedAt) {
                    // A journey just started (here or on another device): record its starting
                    // point so the first checkpoint reached after this is celebrated.
                    checkJourneyCheckpoints(silently: true)
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
        // Live session screens (3.1). Attached here, not on the TabView, so they don't compete
        // with the milestone cover; celebrations earned meanwhile show once they close.
        .fullScreenCover(isPresented: $viewModel.showTracker, onDismiss: viewModel.celebrateDeferred) {
            TrackWorkoutView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.showStrengthSession, onDismiss: viewModel.celebrateDeferred) {
            StrengthSessionView(viewModel: viewModel)
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
        // Medium widget context (3.1 B3): totals, what's left to the next milestone, and this
        // month's challenge.
        defaults?.set(viewModel.displayTotal(for: .distance), forKey: "distanceTotal")
        defaults?.set(viewModel.displayTotal(for: .weight),   forKey: "weightTotal")
        defaults?.set(widgetRemainingText(type: .distance),   forKey: "distanceRemaining")
        defaults?.set(widgetRemainingText(type: .weight),     forKey: "weightRemaining")
        let now = Date()
        if let challenge = viewModel.currentChallenge(on: now) {
            let month = Calendar.current.dateComponents([.year, .month], from: now)
            defaults?.set("\(challenge.emoji) \(challenge.title)",                 forKey: "challengeTitle")
            defaults?.set(viewModel.challengeFraction(challenge, on: now),         forKey: "challengeFraction")
            defaults?.set((month.year ?? 0) * 100 + (month.month ?? 0),            forKey: "challengeMonth")
        } else {
            defaults?.removeObject(forKey: "challengeTitle")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// "1.2 mi to next milestone", or "All milestones done!" past the last one.
    private func widgetRemainingText(type: ActivityType) -> String {
        let next = viewModel.remainingToNextMilestone(type: type)
        guard next.milestone != nil else { return "All milestones done!" }
        let remaining = UnitConverter.displayString(next.remaining, type: type, pref: viewModel.unitPreference)
        return "\(remaining) to next milestone"
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
