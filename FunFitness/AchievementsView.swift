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
                Color.ffBg
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        ProgressBanner(
                            unlockedCount: achievements.count,
                            totalCount: ComparisonEngine.allMilestones.count,
                            percentage: completionPercentage
                        )
                        .accessibilityIdentifier("achievementsProgressBanner")

                        if achievements.isEmpty {
                            EmptyAchievementsState()
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Unlocked")
                                    .ffFont(.headline)
                                    .foregroundStyle(Color.ffInk)
                                    .padding(.horizontal)

                                ForEach(unlockedMilestones, id: \.milestone.id) { item in
                                    AchievementCard(
                                        milestone: item.milestone,
                                        pack: viewModel.activePack,
                                        pref: viewModel.unitPreference,
                                        unlockedAt: item.unlockedAt,
                                        isLocked: false
                                    )
                                }
                            }

                            if !lockedMilestones.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Locked")
                                        .ffFont(.headline)
                                        .foregroundStyle(Color.ffInkMuted)
                                        .padding(.horizontal)

                                    ForEach(lockedMilestones) { milestone in
                                        AchievementCard(
                                            milestone: milestone,
                                            pack: viewModel.activePack,
                                            pref: viewModel.unitPreference,
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
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffInk)
                    Text("\(unlockedCount) of \(totalCount) unlocked")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                Spacer()
                Text("\(percentage)%")
                    .ffFont(.numeral)
                    .foregroundStyle(Color.ffInk)
            }

            SwiftUI.ProgressView(value: Double(percentage), total: 100)
                .progressViewStyle(FitnessProgressStyle(tint: .ffStreak))
                .accessibilityLabel("Overall achievement progress")
                .accessibilityValue("\(percentage) percent")
        }
        .ffCard()
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
                .ffFont(.title)
                .foregroundStyle(Color.ffInk)

            Text("Start logging your activities to unlock fun achievements and comparisons!")
                .ffFont(.body)
                .foregroundStyle(Color.ffInkMuted)
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
        .ffCard(padding: 0)
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let milestone: Milestone
    let pack: ThemePack
    let pref: UnitPreference
    let unlockedAt: Date?
    let isLocked: Bool

    @ScaledMetric(relativeTo: .title2) private var emojiSize: CGFloat = 40

    private var thresholdDisplay: String {
        switch milestone.unit {
        case .kilometers: return UnitConverter.distanceString(milestone.threshold, pref: pref)
        case .kilograms:  return UnitConverter.weightString(milestone.threshold, pref: pref)
        case .minutes:    return UnitConverter.durationString(milestone.threshold)
        case .reps:       return UnitConverter.repsString(milestone.threshold)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(milestone.getEmoji(for: pack))
                .font(.system(size: emojiSize))
                .opacity(isLocked ? 0.3 : 1.0)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title(pref: pref))
                    .ffFont(.headline)
                    .foregroundStyle(isLocked ? Color.ffInkMuted : Color.ffInk)

                if !isLocked {
                    Text(milestone.getComparison(for: pack))
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                        .lineLimit(2)

                    if let date = unlockedAt {
                        Text("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))")
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffLink)
                    }
                } else {
                    Text("Reach \(thresholdDisplay) to unlock")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
            }

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.ffInkMuted)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.ffSuccess)
                    .accessibilityHidden(true)
            }
        }
        .badgeFace(isLocked: isLocked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLocked
            ? "\(milestone.title(pref: pref)) — locked. Reach \(thresholdDisplay) to unlock."
            : "\(milestone.title(pref: pref)) — unlocked. \(milestone.getComparison(for: pack))"
        )
    }
}

// MARK: - Badge face

private extension View {
    /// BadgeTile faces: unlocked is a surface card with outline and hard shadow; locked is a
    /// dashed outline only (no fill, no shadow) so the ground shows through.
    @ViewBuilder
    func badgeFace(isLocked: Bool) -> some View {
        if isLocked {
            self
                .padding(FFSpace.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
                        .strokeBorder(Color.ffLine, style: StrokeStyle(lineWidth: FFStroke.control, dash: [6, 4]))
                )
        } else {
            self.ffCard(padding: FFSpace.s4, radius: FFRadius.md)
        }
    }
}

#Preview {
    AchievementsView(viewModel: AppViewModel())
        .modelContainer(for: [UnlockedAchievement.self], inMemory: true)
}
