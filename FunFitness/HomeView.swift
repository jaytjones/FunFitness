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
    // nil = general "+" (sheet opens on the last-logged type); set by per-card buttons.
    @State private var logType: ActivityType? = nil
    @State private var showHistory = false

    private var pref: UnitPreference { viewModel.unitPreference }

    // Core types (distance, weight) always show; new types surface once they have data.
    private var visibleTypes: [ActivityType] {
        ActivityType.allCases.filter { $0.alwaysShowsCard || viewModel.total(for: $0) > 0 }
    }

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

                        ChallengeCard(viewModel: viewModel)

                        SeasonalCard(viewModel: viewModel)

                        TrackWorkoutCard(viewModel: viewModel)

                        StrengthSessionCard(viewModel: viewModel)

                        if let last = viewModel.lastActivity {
                            RepeatLastButton(label: repeatLabel(for: last)) {
                                repeatLast(last)
                            }
                        }

                        // One card per visible type: the two core types always, duration/reps
                        // once they have data. (v2.2)
                        ForEach(visibleTypes, id: \.self) { type in
                            StatCard(
                                title: type.cardTitle,
                                subtitle: type.cardSubtitle,
                                icon: type.emoji,
                                displayValue: viewModel.displayTotal(for: type),
                                progress: viewModel.progressToNextMilestone(type: type),
                                nextMilestone: viewModel.remainingToNextMilestone(type: type).milestone?.title(pref: viewModel.unitPreference) ?? "Complete!",
                                remainingDisplay: remainingLabel(for: type),
                                gradientColors: type.cardGradient,
                                logHint: "Logs a \(type.displayName.lowercased()) activity",
                                onTap: {
                                    logType = type
                                    showLogSheet = true
                                }
                            )
                            .accessibilityIdentifier("\(type.rawValue)StatCard")
                        }

                        RecentActivityCard(viewModel: viewModel) {
                            showHistory = true
                        }

                        AbsurdityTicker(viewModel: viewModel)

                        ThemeSelector(selectedPack: $viewModel.activePack)

                        AchievementPreview(
                            unlockedCount: achievements.count,
                            totalCount: ComparisonEngine.allMilestones.count
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
                        logType = nil
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
            .sheet(isPresented: $showLogSheet, onDismiss: viewModel.presentLiveSessionIfRequested) {
                LogActivitySheet(viewModel: viewModel, initialType: logType)
            }
            .sheet(isPresented: $showHistory) {
                ActivityHistorySheet(viewModel: viewModel)
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
        let kind = activity.activityType
        return "\(kind.emoji) \(UnitConverter.displayString(activity.value, type: kind, reps: activity.reps, pref: pref))"
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
        viewModel.celebrate(newMilestones)
    }

    private func remainingLabel(for type: ActivityType) -> String {
        let remaining = viewModel.remainingToNextMilestone(type: type).remaining
        guard remaining > 0 else { return "" }
        return "\(UnitConverter.displayString(remaining, type: type, pref: pref)) to go"
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let viewModel: AppViewModel
    let onActivateShield: () -> Void

    // Width of the share glyph, scaled with Dynamic Type so it stays clear at large sizes.
    @ScaledMetric(relativeTo: .subheadline) private var shareButtonReserve: CGFloat = 20

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
                // Reserve trailing space for the share button in the overlay below, so the
                // streak count doesn't sit under it. (2.4.4)
                if viewModel.currentStreak > 0 {
                    Color.clear.frame(width: shareButtonReserve, height: 1)
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

// MARK: - Monthly Challenge Card (v2.2)

struct ChallengeCard: View {
    let viewModel: AppViewModel

    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        if let challenge = viewModel.currentChallenge() {
            let fraction  = viewModel.challengeFraction(challenge)
            let done      = viewModel.challengeProgressValue(challenge)
            let completed = viewModel.isChallengeComplete(challenge)
            let doneStr   = UnitConverter.displayString(done, type: challenge.type, pref: pref)
            let targetStr = UnitConverter.displayString(challenge.targetSI, type: challenge.type, pref: pref)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(challenge.emoji)
                        .font(.title)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(completed ? "Challenge Complete! 🎉" : "\(monthName(challenge.month)) Challenge")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    // Reserve trailing space for the share button in the overlay below.
                    Color.clear.frame(width: 24, height: 1)
                }

                Text(challenge.blurb)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))

                SwiftUI.ProgressView(value: fraction)
                    .progressViewStyle(FitnessProgressStyle(tint: .white))
                    .accessibilityLabel("Challenge progress")
                    .accessibilityValue(String(format: "%.0f percent", fraction * 100))

                HStack {
                    Text(completed ? "Done — \(doneStr)" : "\(doneStr) / \(targetStr)")
                        .font(.caption)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(fraction * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#DB2777"), Color(hex: "#7C3AED")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 20))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(monthName(challenge.month)) challenge: \(challenge.title). "
                + (completed ? "Complete." : "\(Int(fraction * 100)) percent done, \(doneStr) of \(targetStr).")
            )
            .accessibilityIdentifier("challengeCard")
            // Share button kept outside the combined element so VoiceOver can reach it.
            .overlay(alignment: .topTrailing) {
                if completed {
                    ShareCardButton(
                        content: .challenge(challenge),
                        filename: "funfitness_challenge.png"
                    )
                    .padding(12)
                }
            }
        }
    }

    private func monthName(_ month: Int) -> String {
        let symbols = DateFormatter().monthSymbols ?? []
        guard month >= 1, month <= symbols.count else { return "Monthly" }
        return symbols[month - 1]
    }
}

// MARK: - Seasonal Card (v2.2)

struct SeasonalCard: View {
    let viewModel: AppViewModel

    var body: some View {
        if let (season, comparison) = SeasonalEngine.currentComparison(
            on: Date(),
            totalWeightKg: viewModel.totalWeight,
            totalDistanceKm: viewModel.totalDistance
        ) {
            HStack(spacing: 12) {
                Text(comparison.emoji)
                    .font(.title)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(season.name) Special \(season.emoji)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(comparison.text)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#B45309"), Color(hex: "#7C2D12")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 20))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(season.name) special. \(comparison.text)")
            .accessibilityIdentifier("seasonalCard")
        }
    }
}

// MARK: - Track Workout Card (3.1)

/// Starts a live GPS walk/run, or — while one is recording — shows it and reopens the tracker.
struct TrackWorkoutCard: View {
    let viewModel: AppViewModel
    private let tracker = WorkoutTracker.shared

    var body: some View {
        Button {
            viewModel.showTracker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tracker.isRecording ? "location.fill" : "figure.walk.motion")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: tracker.phase == .active)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Text(tracker.isRecording ? "Open" : "Start")
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
                    colors: [Color(hex: "#2563EB"), Color(hex: "#1D4ED8")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityIdentifier("trackWorkoutCard")
    }

    private var title: String {
        switch tracker.phase {
        case .idle:     return "Track a Walk or Run"
        case .active:   return "Tracking your \(tracker.kind.displayName.lowercased())"
        case .paused:   return "\(tracker.kind.displayName) paused"
        case .finished: return "\(tracker.kind.displayName) finished"
        }
    }

    private var subtitle: String {
        switch tracker.phase {
        case .idle:
            return "Live GPS distance, pace, and a map of your route"
        case .active, .paused:
            return UnitConverter.distanceString(tracker.distanceMeters / 1000, pref: viewModel.unitPreference) + " so far"
        case .finished:
            return "Review and save it"
        }
    }
}

// MARK: - Strength Session Card (3.1)

/// Starts a live strength session, or — while one is running — shows it and reopens it.
struct StrengthSessionCard: View {
    let viewModel: AppViewModel
    private let manager = StrengthSessionManager.shared

    var body: some View {
        Button {
            viewModel.showStrengthSession = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: manager.isActive ? "timer" : "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: manager.isActive)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Text(manager.phase == .idle ? "Start" : "Open")
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
                    colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityIdentifier("strengthSessionCard")
    }

    private var title: String {
        switch manager.phase {
        case .idle:     return "Start a Strength Session"
        case .active:   return "Strength session running"
        case .finished: return "Strength session done"
        }
    }

    private var subtitle: String {
        let sets = manager.session?.setCount ?? 0
        switch manager.phase {
        case .idle:     return "Log sets as you go, with a rest timer between them"
        case .active:   return "\(sets) set\(sets == 1 ? "" : "s") so far"
        case .finished: return "See your summary"
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

// MARK: - Recent Activity Card (2.4.4)

/// The last few log entries on Home, so the activity list (and fixing a mistaken entry) is
/// visible without hunting for Progress's history button. Each row's menu deletes it;
/// "See all" opens the full Activity History for editing.
struct RecentActivityCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(RecentActivityCard.descriptor) private var recent: [ActivityLog]
    let viewModel: AppViewModel
    let onSeeAll: () -> Void

    // Fetch-limited so Home doesn't sort the whole log on every render.
    private static var descriptor: FetchDescriptor<ActivityLog> {
        var descriptor = FetchDescriptor<ActivityLog>(sortBy: [SortDescriptor(\.loggedAt, order: .reverse)])
        descriptor.fetchLimit = 5
        return descriptor
    }

    var body: some View {
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent Activity")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button("See all", action: onSeeAll)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "#A78BFA"))
                        .accessibilityHint("Opens your full activity history")
                        .accessibilityIdentifier("recentActivitySeeAll")
                }

                ForEach(recent) { activity in
                    HStack(spacing: 8) {
                        ActivityRow(activity: activity, pref: viewModel.unitPreference)
                        Menu {
                            Button(role: .destructive) {
                                withAnimation {
                                    ActivityWriter.delete(activity, context: modelContext, viewModel: viewModel)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .tint(Color(hex: "#A78BFA"))
                        .accessibilityLabel("Options for \(activity.activityType.displayName) entry")
                    }
                    if activity.id != recent.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color.appCard)
            .clipShape(.rect(cornerRadius: 20))
            .accessibilityIdentifier("recentActivityCard")
        }
    }
}

// MARK: - Absurdity Ticker

struct AbsurdityTicker: View {
    let viewModel: AppViewModel

    // One line per type that has a live comparison; new types join automatically. (v2.2)
    private var lines: [String] {
        ActivityType.allCases.compactMap { viewModel.absurdityTickerText(for: $0) }
    }

    var body: some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text("🎯").accessibilityHidden(true)
                    Text("Right Now...")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.75))
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lines, id: \.self) { line in
                        Text(line).font(.headline).foregroundStyle(.white)
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
            .accessibilityLabel(lines.joined(separator: ". "))
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
    @Binding var selectedPack: ThemePack

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievement Theme")
                .font(.headline)
                .foregroundStyle(.primary)

            // FlowLayout wraps the chips onto multiple rows as the pack list grows (5 packs
            // as of v2.2 Segment 4).
            FlowLayout(spacing: 12) {
                ForEach(ThemePackCatalog.all) { pack in
                    SelectionChip(
                        title: pack.displayName,
                        isSelected: selectedPack == pack,
                        selectedBackground: Color(hex: "#D946EF"),
                        action: { selectedPack = pack }
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

