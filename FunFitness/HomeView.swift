//
//  HomeView.swift
//  FunFitness
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [ActivityLog]
    @Query private var achievements: [UnlockedAchievement]
    @Query private var profiles: [UserProfile]
    @Bindable var viewModel: AppViewModel

    @State private var showLogSheet = false
    @State private var showShieldConfirm = false
    @State private var logType: ActivityType = .distance

    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        StreakCard(viewModel: viewModel, onActivateShield: {
                            showShieldConfirm = true
                        })

                        SillyTitleBanner(viewModel: viewModel)

                        if let last = viewModel.lastActivity {
                            RepeatLastButton(label: repeatLabel(for: last)) {
                                repeatLast(last)
                            }
                        }

                        StatCard(
                            title: "Distance Tracking",
                            subtitle: "Running & Walking",
                            icon: "🏃",
                            displayValue: viewModel.displayDistance(viewModel.totalDistance),
                            progress: viewModel.progressToNextMilestone(type: .distance),
                            nextMilestone: viewModel.remainingToNextMilestone(type: .distance).milestone?.title ?? "Complete!",
                            remainingDisplay: remainingLabel(for: .distance),
                            gradientColors: [Color(hex: "#2563EB"), Color(hex: "#1E40AF")],
                            logHint: "Logs a distance activity",
                            onTap: {
                                logType = .distance
                                showLogSheet = true
                            }
                        )
                        .accessibilityIdentifier("distanceStatCard")

                        StatCard(
                            title: "Weight Tracking",
                            subtitle: "Strength Training",
                            icon: "💪",
                            displayValue: viewModel.displayWeight(viewModel.totalWeight),
                            progress: viewModel.progressToNextMilestone(type: .weight),
                            nextMilestone: viewModel.remainingToNextMilestone(type: .weight).milestone?.title ?? "Complete!",
                            remainingDisplay: remainingLabel(for: .weight),
                            gradientColors: [Color(hex: "#7C3AED"), Color(hex: "#4C1D95")],
                            logHint: "Logs a weight activity",
                            onTap: {
                                logType = .weight
                                showLogSheet = true
                            }
                        )
                        .accessibilityIdentifier("weightStatCard")

                        AbsurdityTicker(viewModel: viewModel)

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        logType = .distance
                        showLogSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(hex: "#A78BFA"))
                    }
                    .accessibilityLabel("Log activity")
                    .accessibilityIdentifier("homeLogActivityButton")
                }
            }
            .sheet(isPresented: $showLogSheet) {
                LogActivitySheet(viewModel: viewModel, initialType: logType)
            }
            .alert("Use Streak Shield?", isPresented: $showShieldConfirm) {
                Button("Use Shield", role: .none) {
                    // Activate shield via ContentView helper surfaced through EnvironmentObject
                    // pattern is: shield activation lives in ContentView, triggered here via a
                    // published flag on the viewModel.
                    viewModel.pendingShieldActivation = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A streak shield protects your streak for one missed week. You have \(viewModel.shieldsAvailable) shield\(viewModel.shieldsAvailable == 1 ? "" : "s") available. Shields regenerate monthly.")
            }
        }
    }

    // Short description of the activity the repeat button will re-log.
    private func repeatLabel(for activity: ActivityLog) -> String {
        switch activity.activityType {
        case .distance:
            return "🏃 \(viewModel.displayDistance(activity.value))"
        case .weight:
            return "💪 \(viewModel.displayWeight(activity.value, reps: activity.reps))"
        }
    }

    private func repeatLast(_ activity: ActivityLog) {
        let newMilestones = ActivityWriter.log(
            type: activity.activityType,
            value: activity.value,
            reps: activity.reps,
            date: Date(),
            context: modelContext,
            viewModel: viewModel,
            writeBackToHealth: profiles.first?.healthKitWriteBackEnabled ?? false
        )
        if !newMilestones.isEmpty {
            viewModel.pendingMilestones = newMilestones
            viewModel.showMilestoneModal = true
        }
    }

    private func remainingLabel(for type: ActivityType) -> String {
        let remaining = viewModel.remainingToNextMilestone(type: type).remaining
        guard remaining > 0 else { return "" }
        if type == .distance {
            return "\(UnitConverter.distanceString(remaining, pref: pref)) to go"
        } else {
            return "\(UnitConverter.weightString(remaining, pref: pref)) to go"
        }
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let viewModel: AppViewModel
    let onActivateShield: () -> Void

    private var streakEmoji: String {
        viewModel.currentStreak == 0 ? "💤" : viewModel.currentStreak >= 8 ? "🔥🔥" : "🔥"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(streakEmoji)
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Streak")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(viewModel.isActiveThisWeekStreak ? "Active this week ✓" : "No activity yet this week")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.currentStreak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("week\(viewModel.currentStreak == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            HStack {
                Label("Best: \(viewModel.longestStreak) wk\(viewModel.longestStreak == 1 ? "" : "s")", systemImage: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                if viewModel.shieldsAvailable > 0 && !viewModel.isActiveThisWeekStreak && viewModel.currentStreak > 0 {
                    Button(action: onActivateShield) {
                        Label("Use Shield (\(viewModel.shieldsAvailable))", systemImage: "shield.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.2))
                            .clipShape(.capsule)
                    }
                    .accessibilityLabel("Use streak shield")
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: viewModel.currentStreak == 0
                    ? [Color(hex: "374151"), Color(hex: "1F2937")]
                    : [Color(hex: "EA580C"), Color(hex: "DC2626")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly streak: \(viewModel.currentStreak) weeks. Best: \(viewModel.longestStreak).")
        .accessibilityIdentifier("streakCard")
        // Share button kept outside the combined element so VoiceOver can reach it.
        .overlay(alignment: .topTrailing) {
            if viewModel.currentStreak > 0 {
                ShareCardButton(
                    content: .streak(current: viewModel.currentStreak, longest: viewModel.longestStreak),
                    filename: "funfitness_streak.png"
                )
                .padding(12)
            }
        }
    }
}

// MARK: - Silly Title Banner

struct SillyTitleBanner: View {
    let viewModel: AppViewModel

    var body: some View {
        let title = viewModel.sillyTitle
        HStack(spacing: 12) {
            Text(title.rankEmoji)
                .font(.title2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text("\(title.rank) Rank · \(viewModel.unlockedAchievementIds.count) badge\(viewModel.unlockedAchievementIds.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Reserve trailing space so the combined label doesn't overlap the
            // share button placed in the overlay below.
            Color.clear.frame(width: 24, height: 1)
        }
        .padding()
        .background(Color.appCard)
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Title: \(title.title). \(title.rank) rank.")
        .accessibilityIdentifier("sillyTitleBanner")
        // Share button kept outside the combined element so VoiceOver can reach it.
        .overlay(alignment: .trailing) {
            ShareCardButton(
                content: .title(title, badgeCount: viewModel.unlockedAchievementIds.count),
                filename: "funfitness_title.png",
                tint: Color(hex: "#A78BFA")
            )
            .padding(.trailing, 16)
        }
    }
}

// MARK: - Repeat Last Button

struct RepeatLastButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Repeat Last Activity")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Text("Log it")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .clipShape(.capsule)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#059669"), Color(hex: "#047857")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Repeat last activity: \(label)")
        .accessibilityIdentifier("repeatLastButton")
    }
}

// MARK: - Absurdity Ticker

struct AbsurdityTicker: View {
    let viewModel: AppViewModel

    private var distanceText: String? { viewModel.absurdityTickerText(for: .distance) }
    private var weightText: String?   { viewModel.absurdityTickerText(for: .weight) }
    private var hasContent: Bool      { distanceText != nil || weightText != nil }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text("🎯").accessibilityHidden(true)
                    Text("Right Now...")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.75))
                }
                VStack(alignment: .leading, spacing: 8) {
                    if let text = distanceText {
                        Text(text).font(.headline).foregroundStyle(.white)
                    }
                    if let text = weightText {
                        Text(text).font(.headline).foregroundStyle(.white)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#7C3AED"), Color(hex: "#D946EF")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 20))
            .accessibilityElement(children: .combine)
            .accessibilityLabel([distanceText, weightText].compactMap { $0 }.joined(separator: ". "))
            .accessibilityIdentifier("absurdityTicker")
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let displayValue: String
    let progress: Double
    let nextMilestone: String
    let remainingDisplay: String
    let gradientColors: [Color]
    // VoiceOver hint + tap action for logging this activity type. Optional so
    // non-interactive uses of StatCard keep working.
    var logHint: String? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        let card = cardBody
        if let onTap {
            Button(action: onTap) { card }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(logHint ?? "")
        } else {
            card
        }
    }

    private var cardBody: some View {
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
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if onTap != nil {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityHidden(true)
                }
            }

            Text(displayValue)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            SwiftUI.ProgressView(value: progress)
                .progressViewStyle(FitnessProgressStyle(tint: .white))
                .accessibilityLabel("\(title) progress")
                .accessibilityValue(String(format: "%.0f percent", progress * 100))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Milestone")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(nextMilestone)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                if !remainingDisplay.isEmpty {
                    Text(remainingDisplay)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
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
        .accessibilityLabel("\(title): \(displayValue). \(Int(progress * 100))% to next milestone.")
    }
}

// MARK: - Theme Selector

struct ThemeSelector: View {
    @Binding var selectedTheme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievement Theme")
                .font(.headline)
                .foregroundStyle(.primary)

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
        .background(Color.appCard)
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
                        .foregroundStyle(.secondary)
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
                .background(Color.appCard)
                .clipShape(.rect(cornerRadius: 20))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Achievements")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(unlockedCount) of \(totalCount) unlocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.appCard)
                .clipShape(.rect(cornerRadius: 20))
            }
        }
    }
}

#Preview {
    HomeView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
