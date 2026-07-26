//
//  HomeView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [ActivityLog]
    @Query private var achievements: [UnlockedAchievement]
    @Bindable var viewModel: AppViewModel

    @State private var showLogSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D1A")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        StatCard(
                            title: "Distance Tracking",
                            subtitle: "Running & Walking",
                            icon: "🏃",
                            value: viewModel.totalDistance,
                            unit: "mi",
                            progress: viewModel.progressToNextMilestone(type: .distance),
                            nextMilestone: viewModel.remainingToNextMilestone(type: .distance).milestone?.title ?? "Complete!",
                            remaining: viewModel.remainingToNextMilestone(type: .distance).remaining,
                            remainingUnit: "mi",
                            gradientColors: [Color(hex: "#2563EB"), Color(hex: "#1E40AF")]
                        )

                        StatCard(
                            title: "Weight Tracking",
                            subtitle: "Strength Training",
                            icon: "💪",
                            value: viewModel.totalWeight,
                            unit: "lbs",
                            progress: viewModel.progressToNextMilestone(type: .weight),
                            nextMilestone: viewModel.remainingToNextMilestone(type: .weight).milestone?.title ?? "Complete!",
                            remaining: viewModel.remainingToNextMilestone(type: .weight).remaining,
                            remainingUnit: "lbs",
                            gradientColors: [Color(hex: "#7C3AED"), Color(hex: "#4C1D95")]
                        )

                        ThemeSelector(selectedTheme: $viewModel.activeTheme)

                        AchievementPreview(
                            unlockedCount: achievements.count,
                            totalCount: ComparisonEngine.allMilestones.count,
                            theme: viewModel.activeTheme
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("FunFitness")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLogSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(hex: "#A78BFA"))
                    }
                    .accessibilityLabel("Log activity")
                }
            }
            .sheet(isPresented: $showLogSheet) {
                LogActivitySheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let value: Double
    let unit: String
    let progress: Double
    let nextMilestone: String
    let remaining: Double
    let remainingUnit: String
    let gradientColors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(icon)
                    .font(.title)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.title3)
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }

            SwiftUI.ProgressView(value: progress)
                .progressViewStyle(FitnessProgressStyle(tint: .white))
                .accessibilityLabel("\(title) progress")
                .accessibilityValue(String(format: "%.0f percent", progress * 100))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Milestone")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    Text(nextMilestone)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                if remaining > 0 {
                    Text(String(format: "%.1f %@ to go", remaining, remainingUnit))
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                } else {
                    Text("All milestones complete!")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(String(format: "%.1f", value)) \(unit). \(Int(progress * 100))% to next milestone.")
    }
}

// MARK: - Theme Selector

struct ThemeSelector: View {
    @Binding var selectedTheme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievement Theme")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    SelectionChip(
                        title: theme.displayName,
                        isSelected: selectedTheme == theme,
                        selectedBackground: Color(hex: "#D946EF"),
                        action: { selectedTheme = theme }
                    )
                }
            }
        }
        .padding()
        .background(Color(hex: "#1A1A2E"))
        .clipShape(.rect(cornerRadius: 20))
    }
}

// MARK: - Achievement Preview

struct AchievementPreview: View {
    let unlockedCount: Int
    let totalCount: Int
    let theme: Theme

    var body: some View {
        VStack(spacing: 16) {
            if unlockedCount == 0 {
                VStack(spacing: 12) {
                    Text("🎯")
                        .font(.system(size: 48))
                        .accessibilityHidden(true)
                    Text("Log your first activity to unlock achievements!")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        ForEach(["🏃", "💪", "🎯", "⚡️", "🔥", "🏆"], id: \.self) { emoji in
                            Text(emoji)
                                .font(.title2)
                                .opacity(0.3)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "#1A1A2E"))
                .clipShape(.rect(cornerRadius: 20))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Achievements")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(unlockedCount) of \(totalCount) unlocked")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(hex: "#1A1A2E"))
                .clipShape(.rect(cornerRadius: 20))
            }
        }
    }
}

#Preview {
    HomeView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
