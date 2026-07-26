//
//  AchievementsView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query private var achievements: [UnlockedAchievement]
    @Bindable var viewModel: AppViewModel

    @State private var showLogSheet = false

    // O(n log n): sort achievements by date first, then map to milestones
    private var unlockedMilestones: [(milestone: Milestone, unlockedAt: Date)] {
        achievements
            .sorted { $0.unlockedAt > $1.unlockedAt }
            .compactMap { achievement in
                ComparisonEngine.byId[achievement.milestoneId].map { ($0, achievement.unlockedAt) }
            }
    }

    private var lockedMilestones: [Milestone] {
        let unlockedIds = Set(achievements.map(\.milestoneId))
        return ComparisonEngine.allMilestones.filter { !unlockedIds.contains($0.id) }
    }

    private var completionPercentage: Int {
        let total = ComparisonEngine.allMilestones.count
        guard total > 0 else { return 0 }
        return Int((Double(achievements.count) / Double(total)) * 100)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D1A")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        ProgressBanner(
                            unlockedCount: achievements.count,
                            totalCount: ComparisonEngine.allMilestones.count,
                            percentage: completionPercentage
                        )

                        if achievements.isEmpty {
                            EmptyAchievementsState()
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Unlocked")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal)

                                ForEach(unlockedMilestones, id: \.milestone.id) { item in
                                    AchievementCard(
                                        milestone: item.milestone,
                                        theme: viewModel.activeTheme,
                                        unlockedAt: item.unlockedAt,
                                        isLocked: false
                                    )
                                }
                            }

                            if !lockedMilestones.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Locked")
                                        .font(.headline)
                                        .foregroundStyle(Color(hex: "#9CA3AF"))
                                        .padding(.horizontal)

                                    ForEach(lockedMilestones) { milestone in
                                        AchievementCard(
                                            milestone: milestone,
                                            theme: viewModel.activeTheme,
                                            unlockedAt: nil,
                                            isLocked: true
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Achievements")
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

// MARK: - Progress Banner

struct ProgressBanner: View {
    let unlockedCount: Int
    let totalCount: Int
    let percentage: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🏆")
                    .font(.title)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Progress")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(unlockedCount) of \(totalCount) unlocked")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                Spacer()
                Text("\(percentage)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            SwiftUI.ProgressView(value: Double(percentage), total: 100)
                .progressViewStyle(FitnessProgressStyle(tint: .white))
                .accessibilityLabel("Overall achievement progress")
                .accessibilityValue("\(percentage) percent")
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(hex: "#EA580C"), Color(hex: "#C2410C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement progress: \(unlockedCount) of \(totalCount) unlocked, \(percentage) percent")
    }
}

// MARK: - Empty State

struct EmptyAchievementsState: View {
    @ScaledMetric(relativeTo: .title) private var lockSize: CGFloat = 60

    var body: some View {
        VStack(spacing: 16) {
            Text("🔒")
                .font(.system(size: lockSize))
                .padding(.top, 40)
                .accessibilityHidden(true)

            Text("No Achievements Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Start logging your activities to unlock fun achievements and comparisons!")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "#9CA3AF"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 12) {
                ForEach(["🏃", "💪", "🎯", "⚡️", "🔥", "🏆"], id: \.self) { emoji in
                    Text(emoji)
                        .font(.title)
                        .opacity(0.3)
                        .accessibilityHidden(true)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(hex: "#1A1A2E"))
        .clipShape(.rect(cornerRadius: 20))
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let milestone: Milestone
    let theme: Theme
    let unlockedAt: Date?
    let isLocked: Bool

    @ScaledMetric(relativeTo: .title2) private var emojiSize: CGFloat = 40

    var body: some View {
        HStack(spacing: 16) {
            Text(milestone.getEmoji(for: theme))
                .font(.system(size: emojiSize))
                .opacity(isLocked ? 0.3 : 1.0)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.headline)
                    .foregroundStyle(isLocked ? Color(hex: "#9CA3AF") : .white)

                if !isLocked {
                    Text(milestone.getComparison(for: theme))
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                        .lineLimit(2)

                    if let date = unlockedAt {
                        Text("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            // #A78BFA passes 4.5:1 on #1A1A2E (was #5B21B6 = 1.90:1 — failed)
                            .foregroundStyle(Color(hex: "#A78BFA"))
                    }
                } else {
                    Text("Reach \(String(format: "%.0f", milestone.threshold)) \(milestone.unit == .miles ? "miles" : "lbs") to unlock")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
            }

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color(hex: "#9CA3AF"))
                    .opacity(0.5)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "#059669"))
                    .accessibilityHidden(true)
            }
        }
        .padding()
        .background(Color(hex: "#1A1A2E"))
        .clipShape(.rect(cornerRadius: 20))
        .opacity(isLocked ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLocked
            ? "\(milestone.title) — locked. Reach \(String(format: "%.0f", milestone.threshold)) \(milestone.unit == .miles ? "miles" : "pounds") to unlock."
            : "\(milestone.title) — unlocked. \(milestone.getComparison(for: theme))"
        )
    }
}

#Preview {
    AchievementsView(viewModel: AppViewModel())
        .modelContainer(for: [UnlockedAchievement.self], inMemory: true)
}
