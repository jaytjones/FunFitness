//
//  ContentView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var achievements: [UnlockedAchievement]
    @Query private var activities: [ActivityLog]

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
                .preferredColorScheme(.dark)
                .fullScreenCover(isPresented: $viewModel.showMilestoneModal) {
                    if currentMilestoneIndex < viewModel.pendingMilestones.count {
                        let milestone = viewModel.pendingMilestones[currentMilestoneIndex]
                        MilestoneView(
                            milestone: milestone,
                            theme: viewModel.activeTheme
                        ) {
                            currentMilestoneIndex += 1
                            if currentMilestoneIndex >= viewModel.pendingMilestones.count {
                                viewModel.showMilestoneModal = false
                                currentMilestoneIndex = 0
                                viewModel.pendingMilestones = []
                            }
                        }
                        // Force recreation on each new milestone so .onAppear re-fires
                        .id(milestone.id)
                    }
                }
                .onAppear {
                    if let profile = profiles.first {
                        viewModel.activeTheme = Theme(rawValue: profile.activeTheme) ?? .animals
                    }
                    viewModel.activities = activities
                    viewModel.unlockedAchievementIds = Set(achievements.map(\.milestoneId))
                    reconcileAchievements()
                }
                .onChange(of: viewModel.activeTheme) {
                    if let profile = profiles.first {
                        profile.activeTheme = viewModel.activeTheme.rawValue
                    }
                }
                .onChange(of: activities) {
                    viewModel.activities = activities
                    reconcileAchievements()
                }
                .onChange(of: achievements) {
                    viewModel.unlockedAchievementIds = Set(achievements.map(\.milestoneId))
                }
            }
        }
    }

    // Idempotent — inserts any earned achievements that aren't yet recorded.
    // Safe to call at launch and after every write; won't duplicate existing records.
    private func reconcileAchievements() {
        let earned = viewModel.earnedMilestoneIds()
        let missing = earned.subtracting(viewModel.unlockedAchievementIds)
        for id in missing {
            modelContext.insert(UnlockedAchievement(milestoneId: id))
            viewModel.unlockedAchievementIds.insert(id)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
