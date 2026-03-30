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
    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var currentMilestoneIndex = 0
    
    private var hasProfile: Bool {
        !profiles.isEmpty
    }
    
    var body: some View {
        Group {
            if !hasProfile {
                OnboardingView {
                    showOnboarding = false
                }
            } else {
                TabView(selection: $selectedTab) {
                    HomeView(viewModel: viewModel)
                        .tabItem {
                            Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                        }
                        .tag(0)
                    
                    ProgressView(viewModel: viewModel)
                        .tabItem {
                            Label("Progress", systemImage: selectedTab == 1 ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis")
                        }
                        .tag(1)
                    
                    AchievementsView(viewModel: viewModel)
                        .tabItem {
                            Label("Achievements", systemImage: selectedTab == 2 ? "trophy.fill" : "trophy")
                        }
                        .tag(2)
                    
                    ProfileView(viewModel: viewModel)
                        .tabItem {
                            Label("Profile", systemImage: selectedTab == 3 ? "person.circle.fill" : "person.circle")
                        }
                        .tag(3)
                }
                .tint(Color(hex: "#5B21B6"))
                .fullScreenCover(isPresented: $viewModel.showMilestoneModal) {
                    if currentMilestoneIndex < viewModel.pendingMilestones.count {
                        MilestoneView(
                            milestone: viewModel.pendingMilestones[currentMilestoneIndex],
                            theme: viewModel.activeTheme
                        ) {
                            currentMilestoneIndex += 1
                            if currentMilestoneIndex >= viewModel.pendingMilestones.count {
                                viewModel.showMilestoneModal = false
                                currentMilestoneIndex = 0
                                viewModel.pendingMilestones = []
                            }
                        }
                    }
                }
                .onAppear {
                    // Initial load
                    if let profile = profiles.first {
                        viewModel.activeTheme = Theme(rawValue: profile.activeTheme) ?? .animals
                    }
                    viewModel.loadUnlockedAchievements(achievements)
                    viewModel.calculateTotals(activities: activities)
                }
                .onChange(of: viewModel.activeTheme) {
                    // Save theme preference
                    if let profile = profiles.first {
                        profile.activeTheme = viewModel.activeTheme.rawValue
                    }
                }
                .onChange(of: activities.count) {
                    // Recalculate whenever activities change
                    viewModel.calculateTotals(activities: activities)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
