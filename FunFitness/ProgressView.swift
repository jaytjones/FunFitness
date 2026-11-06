//
//  ProgressView.swift
//  FunFitness
//
//  Renamed from ProgressView to avoid shadowing SwiftUI.ProgressView (which enables
//  accessible ProgressView(value:) usage and removes the GeometryReader workaround)
//

import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Query private var activities: [ActivityLog]
    @Bindable var viewModel: AppViewModel

    @State private var showLogSheet = false
    @State private var showHistory = false
    @State private var analyticsType: ActivityType = .distance

    private var pref: UnitPreference { viewModel.unitPreference }

    // Core types (distance, weight) always show; new types surface once they have data.
    private var visibleTypes: [ActivityType] {
        ActivityType.allCases.filter { $0.alwaysShowsCard || viewModel.total(for: $0) > 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ffBg
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        OverallProgressCard(
                            totalActivities: viewModel.totalActivities,
                            isActiveThisWeek: viewModel.isActiveThisWeek
                        )

                        // One card per visible type: core types always, duration/reps once
                        // they have data. (v2.2)
                        ForEach(visibleTypes, id: \.self) { type in
                            TrackingCard(
                                title: type.cardTitle,
                                subtitle: type.cardSubtitle,
                                icon: type.emoji,
                                displayValue: viewModel.displayTotal(for: type),
                                progress: viewModel.progressToNextMilestone(type: type),
                                nextMilestoneTitle: viewModel.remainingToNextMilestone(type: type).milestone?.title(pref: viewModel.unitPreference) ?? "All Complete!",
                                remainingDisplay: remainingLabel(for: type),
                                tint: type.ffFill
                            )
                        }

                        if !activities.isEmpty {
                            WeeklyVolumeCard(
                                type: analyticsType,
                                activities: activities,
                                pref: pref,
                                selectableTypes: visibleTypes,
                                selection: $analyticsType
                            )
                            PersonalRecordsCard(types: visibleTypes, activities: activities, pref: pref)
                            MusclesWorkedCard(activities: activities)
                            ExerciseRecordsCard(activities: activities, pref: pref)
                            ActivityHeatmapCard(activities: activities)
                        }

                        MotivationalCard()
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        // Labeled so the history list is discoverable, not just an icon. (2.4.4)
                        Label("History", systemImage: "clock.arrow.circlepath")
                            .labelStyle(.titleAndIcon)
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffLink)
                    }
                    .accessibilityLabel("Activity history")
                    .accessibilityIdentifier("progressHistoryButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLogSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.ffLink)
                    }
                    .accessibilityLabel("Log activity")
                }
            }
            .sheet(isPresented: $showLogSheet, onDismiss: viewModel.presentLiveSessionIfRequested) {
                LogActivitySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showHistory) {
                ActivityHistorySheet(viewModel: viewModel)
            }
        }
    }

    private func remainingLabel(for type: ActivityType) -> String {
        let remaining = viewModel.remainingToNextMilestone(type: type).remaining
        guard remaining > 0 else { return "" }
        return "\(UnitConverter.displayString(remaining, type: type, pref: pref)) to go"
    }
}

// MARK: - Overall Progress Card

struct OverallProgressCard: View {
    let totalActivities: Int
    let isActiveThisWeek: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Overall Progress")
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)
                Spacer()
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Activities")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                    Text("\(totalActivities)")
                        .ffFont(.numeral)
                        .foregroundStyle(Color.ffInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .ffWell(radius: FFRadius.sm)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total activities: \(totalActivities)")

                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isActiveThisWeek ? Color.ffSuccess : Color.ffInkMuted)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(isActiveThisWeek ? "Active" : "Inactive")
                            .ffFont(.bodyStrong)
                            .foregroundStyle(Color.ffInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .ffWell(radius: FFRadius.sm)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("This week: \(isActiveThisWeek ? "Active" : "Inactive")")
            }
        }
        .ffCard()
    }
}

// MARK: - Tracking Card

struct TrackingCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let displayValue: String
    let progress: Double
    let nextMilestoneTitle: String
    let remainingDisplay: String
    /// Meter fill: the activity type's colour (`ActivityType.ffFill`).
    var tint: Color = .ffAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(icon)
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffInk)
                    Text(subtitle)
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                Spacer()
            }

            Divider()
                .overlay(Color.ffLine)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("Total:")
                    .ffFont(.body)
                    .foregroundStyle(Color.ffInkMuted)
                Text(displayValue)
                    .ffFont(.numeral)
                    .foregroundStyle(Color.ffInk)
            }

            VStack(alignment: .leading, spacing: 6) {
                SwiftUI.ProgressView(value: progress)
                    .progressViewStyle(FitnessProgressStyle(tint: tint))
                    .accessibilityLabel("\(title) progress")
                    .accessibilityValue(String(format: "%.0f percent", progress * 100))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Milestone")
                            .ffFont(.label)
                            .foregroundStyle(Color.ffInkMuted)
                        Text(nextMilestoneTitle)
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffInk)
                            .lineLimit(2)
                    }
                    Spacer()
                    if !remainingDisplay.isEmpty {
                        Text(remainingDisplay)
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffInkMuted)
                    } else {
                        Text("Complete!")
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffSuccess)
                    }
                }
            }
        }
        .ffCard()
    }
}

// MARK: - Weekly Volume Chart (v2.2)

struct WeeklyVolumeCard: View {
    let type: ActivityType
    let activities: [ActivityLog]
    let pref: UnitPreference
    let selectableTypes: [ActivityType]
    @Binding var selection: ActivityType

    private var buckets: [AnalyticsEngine.WeeklyBucket] {
        AnalyticsEngine.weeklyVolume(type: type, activities: activities, now: Date(), weeks: 8)
    }

    private var unitLabel: String { UnitConverter.displayUnit(for: type, pref: pref) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Volume")
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            if selectableTypes.count > 1 {
                Picker("Volume type", selection: $selection) {
                    ForEach(selectableTypes, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }

            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                    y: .value(unitLabel, UnitConverter.fromSI(bucket.total, type: type, to: pref))
                )
                // Zero weeks read as track, not as the type colour.
                .foregroundStyle(bucket.total > 0 ? type.ffFill : Color.ffProgressTrack)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.ffProgressTrack)
                    AxisTick().foregroundStyle(Color.ffInkMuted)
                    AxisValueLabel().foregroundStyle(Color.ffInkMuted)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.ffProgressTrack)
                    AxisTick().foregroundStyle(Color.ffInkMuted)
                    AxisValueLabel().foregroundStyle(Color.ffInkMuted)
                }
            }
            .frame(height: 160)
            .accessibilityLabel("Weekly \(type.displayName.lowercased()) volume, last 8 weeks")

            Text("Last 8 weeks · \(unitLabel)")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
        }
        .ffCard()
    }
}

// MARK: - Personal Records (v2.2)

struct PersonalRecordsCard: View {
    let types: [ActivityType]
    let activities: [ActivityLog]
    let pref: UnitPreference

    private struct PR: Identifiable {
        let type: ActivityType
        let value: Double
        var id: String { type.rawValue }
    }

    private var records: [PR] {
        types.compactMap { t in
            AnalyticsEngine.personalRecord(type: t, activities: activities).map { PR(type: t, value: $0) }
        }
    }

    var body: some View {
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal Records")
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)

                ForEach(records) { pr in
                    let display = UnitConverter.displayString(pr.value, type: pr.type, pref: pref)
                    HStack {
                        Text(pr.type.emoji).accessibilityHidden(true)
                        Text(pr.type.displayName)
                            .ffFont(.body)
                            .foregroundStyle(Color.ffInk)
                        Spacer()
                        Text(display)
                            .ffFont(.headline)
                            .foregroundStyle(Color.ffInk)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(pr.type.displayName) personal record: \(display)")
                }
            }
            .ffCard()
        }
    }
}

// MARK: - Activity Heatmap (v2.2)

struct ActivityHeatmapCard: View {
    let activities: [ActivityLog]

    private var days: [AnalyticsEngine.DayCount] {
        AnalyticsEngine.dailyActivity(activities: activities, now: Date(), days: 84)
    }

    // 12 columns of 7 consecutive days (oldest → newest).
    private var weeks: [[AnalyticsEngine.DayCount]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    private func color(_ count: Int) -> Color {
        switch count {
        case 0:  return .ffProgressTrack
        case 1:  return .ffHeat1
        case 2:  return .ffHeat2
        default: return .ffHeat3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity — Last 12 Weeks")
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)

            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 4) {
                        ForEach(week) { day in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color(day.count))
                                // Outlined so steps differ by more than hue.
                                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.ffLine, lineWidth: 1))
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Text("Less").ffFont(.caption).foregroundStyle(Color.ffInkMuted)
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(i))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.ffLine, lineWidth: 1))
                        .frame(width: 12, height: 12)
                }
                Text("More").ffFont(.caption).foregroundStyle(Color.ffInkMuted)
            }
        }
        .ffCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity heatmap for the last 12 weeks")
    }
}

// MARK: - Motivational Card

struct MotivationalCard: View {
    private let messages = [
        "Keep Going! Every step and rep counts.",
        "You're doing amazing! Stay consistent.",
        "Progress, not perfection. Keep it up!",
        "Your future self will thank you.",
        "One workout at a time. You've got this!"
    ]
    @State private var message: String = ""

    var body: some View {
        HStack(spacing: 16) {
            Text("💪")
                .font(.title)
                .accessibilityHidden(true)

            Text(message)
                .ffFont(.bodyStrong)
                .foregroundStyle(Color.ffInk)

            Spacer()
        }
        .ffCard(fill: .ffSurfaceAlt)
        .onAppear {
            if message.isEmpty {
                message = messages.randomElement() ?? messages[0]
            }
        }
    }
}

#Preview {
    ProgressTabView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self], inMemory: true)
}
