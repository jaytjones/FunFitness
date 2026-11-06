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

    /// Secondary types with data get a StatTile; a zero total is hidden, not shown as 0 (StatTile.md).
    private var tileTypes: [ActivityType] {
        ActivityType.allCases.filter { $0 != .distance && viewModel.total(for: $0) > 0 }
    }

    private var greeting: String {
        let name = profiles.first?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "Hey, champ!" : "Hey, \(name)!"
    }

    private func openLog(_ type: ActivityType) {
        logType = type
        showLogSheet = true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ffBg
                    .ignoresSafeArea()

                ScrollView {
                    // Playful Bold Home order (README): greeting → HeroStat → StatTiles → streak
                    // and rank → challenge → the rest; Ticker, Recent Activity and "Compare with"
                    // lower down. (3.2)
                    VStack(spacing: FFSpace.s4) {
                        Text(greeting)
                            .ffFont(.display)
                            .foregroundStyle(Color.ffInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, FFSpace.s1)

                        HeroStat(viewModel: viewModel, type: .distance) {
                            openLog(.distance)
                        }

                        ForEach(tileTypes, id: \.self) { type in
                            StatTile(viewModel: viewModel, type: type) {
                                openLog(type)
                            }
                        }

                        StreakCard(viewModel: viewModel, onActivateShield: {
                            showShieldConfirm = true
                        })

                        SillyTitleBanner(viewModel: viewModel)

                        ChallengeCard(viewModel: viewModel)

                        EffortPointsCard()

                        JourneyCard(viewModel: viewModel)

                        SeasonalCard(viewModel: viewModel)

                        // While one is running, the pinned "now tracking" bar shows it instead. (FB-0003)
                        if WorkoutTracker.shared.phase == .idle {
                            TrackWorkoutCard(viewModel: viewModel)
                        }

                        if StrengthSessionManager.shared.phase == .idle {
                            StrengthSessionCard(viewModel: viewModel)
                        }

                        if let last = viewModel.lastActivity {
                            RepeatLastButton(label: repeatLabel(for: last)) {
                                repeatLast(last)
                            }
                        }

                        AbsurdityTicker(viewModel: viewModel)

                        RecentActivityCard(viewModel: viewModel) {
                            showHistory = true
                        }

                        ThemeSelector(selectedPack: $viewModel.activePack)

                        AchievementPreview(
                            unlockedCount: achievements.count,
                            totalCount: ComparisonEngine.allMilestones.count
                        )
                    }
                    .padding(.horizontal, FFSpace.s5)
                    .padding(.vertical, FFSpace.s4)
                }
            }
            .navigationTitle("FunFitness")
            .toolbar(.hidden, for: .navigationBar)
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
            surface: activity.surface,
            exerciseID: activity.exerciseID,
            context: modelContext,
            viewModel: viewModel,
            writeBackToHealth: profiles.first?.healthKitWriteBackEnabled ?? false
        )
        viewModel.celebrate(newMilestones)
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
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffInk)
                    Text(viewModel.isActiveThisWeekStreak ? "Active this week ✓" : "No activity yet this week")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.currentStreak)")
                        .ffFont(.numeral)
                        .foregroundStyle(Color.ffInk)
                    Text("week\(viewModel.currentStreak == 1 ? "" : "s")")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                // Reserve trailing space for the share button in the overlay below, so the
                // streak count doesn't sit under it. (2.4.4)
                if viewModel.currentStreak > 0 {
                    Color.clear.frame(width: shareButtonReserve, height: 1)
                }
            }

            HStack {
                Label("Best: \(viewModel.longestStreak) wk\(viewModel.longestStreak == 1 ? "" : "s")", systemImage: "trophy.fill")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
                Spacer()
                if viewModel.shieldsAvailable > 0 && !viewModel.isActiveThisWeekStreak && viewModel.currentStreak > 0 {
                    Button(action: onActivateShield) {
                        Label("Use Shield (\(viewModel.shieldsAvailable))", systemImage: "shield.fill")
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.ffSurfaceAlt, in: .capsule)
                            .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
                    }
                    .accessibilityLabel("Use streak shield")
                }
            }
        }
        .ffCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly streak: \(viewModel.currentStreak) weeks. Best: \(viewModel.longestStreak).")
        .accessibilityIdentifier("streakCard")
        // Share button kept outside the combined element so VoiceOver can reach it.
        .overlay(alignment: .topTrailing) {
            if viewModel.currentStreak > 0 {
                ShareCardButton(
                    content: .streak(current: viewModel.currentStreak, longest: viewModel.longestStreak),
                    filename: "funfitness_streak.png",
                    tint: Color.ffInk
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
                    .ffFont(.bodyStrong)
                    .foregroundStyle(Color.ffInk)
                Text("\(title.rank) Rank · \(viewModel.unlockedAchievementIds.count) badge\(viewModel.unlockedAchievementIds.count == 1 ? "" : "s")")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }
            Spacer()
            // Reserve trailing space so the combined label doesn't overlap the
            // share button placed in the overlay below.
            Color.clear.frame(width: 24, height: 1)
        }
        .ffCard(padding: FFSpace.s4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Title: \(title.title). \(title.rank) rank.")
        .accessibilityIdentifier("sillyTitleBanner")
        // Share button kept outside the combined element so VoiceOver can reach it.
        .overlay(alignment: .trailing) {
            ShareCardButton(
                content: .title(title, badgeCount: viewModel.unlockedAchievementIds.count),
                filename: "funfitness_title.png",
                tint: Color.ffLink
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
                            .ffFont(.label)
                            .foregroundStyle(Color.ffOnTypeReps)
                        Text(challenge.title)
                            .ffFont(.headline)
                            .foregroundStyle(Color.ffOnTypeReps)
                    }
                    Spacer()
                    // Reserve trailing space for the share button in the overlay below.
                    Color.clear.frame(width: 24, height: 1)
                }

                Text(challenge.blurb)
                    .ffFont(.body)
                    .foregroundStyle(Color.ffOnTypeReps)

                // Card fill is type-reps for every challenge; the meter uses the challenge's own
                // type color (ChallengeCard.md).
                SwiftUI.ProgressView(value: fraction)
                    .progressViewStyle(FFMeterStyle(fill: challenge.type.ffFill))
                    .accessibilityLabel("Challenge progress")
                    .accessibilityValue(String(format: "%.0f percent", fraction * 100))

                HStack {
                    Text(completed ? "Done — \(doneStr)" : "\(doneStr) / \(targetStr)")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffOnTypeReps)
                    Spacer()
                    Text("\(Int(fraction * 100))%")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffOnTypeReps)
                }
            }
            .ffCard(fill: .ffTypeReps)
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
                        filename: "funfitness_challenge.png",
                        tint: Color.ffOnTypeReps
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
                        .ffFont(.label)
                        .foregroundStyle(Color.ffInkMuted)
                    Text(comparison.text)
                        .ffFont(.body)
                        .foregroundStyle(Color.ffInk)
                }
                Spacer(minLength: 0)
            }
            .ffCard(padding: FFSpace.s4)
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
                    .foregroundStyle(Color.ffLink)
                    .symbolEffect(.pulse, isActive: tracker.phase == .active)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .ffFont(.bodyStrong)
                        .foregroundStyle(Color.ffInk)
                    Text(subtitle)
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                Spacer()
                Text(tracker.isRecording ? "Open" : "Start")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffOnAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.ffAccent, in: .capsule)
                    .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
            }
            .ffCard(padding: FFSpace.s4)
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
                    .foregroundStyle(Color.ffLink)
                    .symbolEffect(.pulse, isActive: manager.isActive)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .ffFont(.bodyStrong)
                        .foregroundStyle(Color.ffInk)
                    Text(subtitle)
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                Spacer()
                Text(manager.phase == .idle ? "Start" : "Open")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffOnAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.ffAccent, in: .capsule)
                    .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
            }
            .ffCard(padding: FFSpace.s4)
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
                    .foregroundStyle(Color.ffLink)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Repeat Last Activity")
                        .ffFont(.bodyStrong)
                        .foregroundStyle(Color.ffInk)
                    Text(label)
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                Spacer()
                Text("Log it")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffOnAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.ffAccent, in: .capsule)
                    .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
            }
            .ffCard(padding: FFSpace.s4)
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
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffInk)
                    Spacer()
                    Button("See all", action: onSeeAll)
                        .ffFont(.bodyStrong)
                        .foregroundStyle(Color.ffLink)
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
                        .tint(Color.ffLink)
                        .accessibilityLabel("Options for \(activity.activityType.displayName) entry")
                    }
                    if activity.id != recent.last?.id {
                        Divider()
                            .overlay(Color.ffLine.opacity(0.15))
                    }
                }
            }
            .ffCard()
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
                        .ffFont(.label)
                        .foregroundStyle(Color.ffSurface)
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lines, id: \.self) { line in
                        Text(line).ffFont(.headline).foregroundStyle(Color.ffSurface)
                    }
                }
            }
            // Inverted card (ink fill, surface text) so it reads differently from stat cards. (Ticker.md)
            .ffCard(fill: .ffInk)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(lines.joined(separator: ". "))
            .accessibilityIdentifier("absurdityTicker")
        }
    }
}

// MARK: - Theme Selector

/// PackPicker (3.2): "Compare with", so the comparison pack isn't confused with light/dark
/// appearance. One row that scrolls sideways on Home.
struct ThemeSelector: View {
    @Binding var selectedPack: ThemePack

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpace.s3) {
            Text("Compare with")
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal) {
                HStack(spacing: FFSpace.s3) {
                    ForEach(ThemePackCatalog.all) { pack in
                        SelectionChip(
                            title: pack.displayName,
                            isSelected: selectedPack == pack,
                            action: { selectedPack = pack }
                        )
                    }
                }
                .padding(.vertical, FFSpace.s1)
            }
            .scrollIndicators(.hidden)
        }
        .ffCard()
        .accessibilityIdentifier("packPicker")
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
                        .ffFont(.body)
                        .foregroundStyle(Color.ffInkMuted)
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
                .ffCard()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Achievements")
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffInk)
                    Text("\(unlockedCount) of \(totalCount) unlocked")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                .ffCard()
            }
        }
    }
}

#Preview {
    HomeView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self], inMemory: true)
}

