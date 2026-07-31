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

    @State private var viewModel = AppViewModel()
    @State private var selectedTab = 0
    @State private var currentMilestoneIndex = 0

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
                        MilestoneView(milestone: milestone, theme: viewModel.activeTheme) {
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
                        viewModel.activeTheme    = Theme(rawValue: profile.activeTheme) ?? .animals
                        viewModel.unitPreference = profile.unitPref
                    }
                    viewModel.activities = activities
                    viewModel.unlockedAchievementIds = Set(achievements.map(\.milestoneId))
                    runMigrationsIfNeeded()
                    reconcileAchievements()
                    updateStreak()
                    writeWidgetData()
                }
                .onChange(of: viewModel.activeTheme) {
                    profiles.first?.activeTheme = viewModel.activeTheme.rawValue
                }
                .onChange(of: activities) {
                    viewModel.activities = activities
                    reconcileAchievements()
                    updateStreak()
                    scheduleNotificationsIfNeeded()
                    writeWidgetData()
                }
                .onChange(of: achievements) {
                    viewModel.unlockedAchievementIds = Set(achievements.map(\.milestoneId))
                }
                .onChange(of: viewModel.pendingShieldActivation) {
                    if viewModel.pendingShieldActivation {
                        viewModel.pendingShieldActivation = false
                        activateStreakShield()
                    }
                }
                .onChange(of: profiles) {
                    if let profile = profiles.first {
                        viewModel.activeTheme    = Theme(rawValue: profile.activeTheme) ?? .animals
                        viewModel.unitPreference = profile.unitPref
                    }
                }
            }
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
            for type in [ActivityType.distance, ActivityType.weight] {
                let progress = viewModel.progressToNextMilestone(type: type)
                if progress >= 0.9, let milestone = viewModel.remainingToNextMilestone(type: type).milestone {
                    let remaining = viewModel.remainingToNextMilestone(type: type).remaining
                    let remainingDisplay = type == .distance
                        ? UnitConverter.distanceString(remaining, pref: viewModel.unitPreference)
                        : UnitConverter.weightString(remaining, pref: viewModel.unitPreference)
                    nm.scheduleMilestoneNudge(
                        type: type,
                        milestoneTitle: milestone.title,
                        remaining: remainingDisplay
                    )
                }
            }
        } else {
            // Cancel per-type identifiers used by scheduleMilestoneNudge
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
                "\(NotificationCategory.milestoneNudge.rawValue)_\(ActivityType.distance.rawValue)",
                "\(NotificationCategory.milestoneNudge.rawValue)_\(ActivityType.weight.rawValue)",
            ])
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
        let nextDist = viewModel.remainingToNextMilestone(type: .distance).milestone?.title ?? "All done!"
        let nextWt   = viewModel.remainingToNextMilestone(type: .weight).milestone?.title   ?? "All done!"
        defaults?.set(nextDist,                   forKey: "nextDistanceMilestone")
        defaults?.set(nextWt,                     forKey: "nextWeightMilestone")
        defaults?.set(viewModel.sillyTitle.title, forKey: "sillyTitle")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - v1.2 Migration

    // Runs once per install: converts stored miles → km and lbs → kg.
    // Also migrates profile height (inches string → cm) and body weight (lbs → kg).
    private func runMigrationsIfNeeded() {
        let migrationKey = "v1_2_unitMigration"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        for activity in activities {
            switch activity.activityType {
            case .distance: activity.value *= UnitConverter.kmPerMile
            case .weight:   activity.value *= UnitConverter.kgPerLb
            }
        }

        if let profile = profiles.first {
            // weightKg column previously stored lbs — convert to kg
            if let oldLbs = profile.weightKg, oldLbs > 0 {
                profile.weightKg = oldLbs * UnitConverter.kgPerLb
            }
            // heightInches string → heightCm double
            if let heightStr = profile.heightInches,
               let heightIn = Double(heightStr), heightIn > 0 {
                profile.heightCm = heightIn * 2.54
            }
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: migrationKey)

        // Refresh vm with converted values
        viewModel.activities = activities
    }

    // MARK: - Achievement Reconciliation

    // Bidirectional: inserts earned achievements not yet recorded,
    // removes recorded achievements no longer supported by current totals.
    private func reconcileAchievements() {
        let earned   = viewModel.earnedMilestoneIds()
        let recorded = Set(achievements.map(\.milestoneId))

        for id in earned.subtracting(recorded) {
            modelContext.insert(UnlockedAchievement(milestoneId: id))
            viewModel.unlockedAchievementIds.insert(id)
        }

        let stale = recorded.subtracting(earned)
        if !stale.isEmpty {
            for record in achievements where stale.contains(record.milestoneId) {
                modelContext.delete(record)
                viewModel.unlockedAchievementIds.remove(record.milestoneId)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
