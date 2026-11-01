//
//  FunFitnessWidgets.swift
//  FunFitnessWidgets
//
//  Streak + milestone-progress home screen widget.
//  Bundle entry point is in FunFitnessWidgetsBundle.swift.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct FunFitnessProvider: TimelineProvider {
    func placeholder(in context: Context) -> FunFitnessEntry {
        FunFitnessEntry(snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (FunFitnessEntry) -> Void) {
        completion(FunFitnessEntry(snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FunFitnessEntry>) -> Void) {
        let entry = FunFitnessEntry(snapshot: .load())
        // Refresh every 30 minutes; the main app also triggers a reload via
        // WidgetCenter.shared.reloadAllTimelines() after each activity log.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Entry

struct FunFitnessEntry: TimelineEntry {
    let date: Date = .now
    let snapshot: WidgetSnapshot
}

// MARK: - Entry View

struct FunFitnessWidgetEntryView: View {
    var entry: FunFitnessEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(snapshot: entry.snapshot)
        default:            MediumWidgetView(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Small (2×2)

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    private var streakColor: [Color] {
        snapshot.streak == 0
            ? [Color(red: 0.22, green: 0.25, blue: 0.32), Color(red: 0.12, green: 0.16, blue: 0.24)]
            : [Color(red: 0.92, green: 0.35, blue: 0.07), Color(red: 0.86, green: 0.15, blue: 0.15)]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: streakColor, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(snapshot.streak == 0 ? "💤" : "🔥")
                        .font(.title3)
                    Spacer()
                    if snapshot.activeThisWeek {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                Spacer()
                Text("\(snapshot.streak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("week streak")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(12)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Medium (4×2)

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    private var streakColor: [Color] {
        snapshot.streak == 0
            ? [Color(red: 0.22, green: 0.25, blue: 0.32), Color(red: 0.12, green: 0.16, blue: 0.24)]
            : [Color(red: 0.92, green: 0.35, blue: 0.07), Color(red: 0.86, green: 0.15, blue: 0.15)]
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: streak
            ZStack {
                LinearGradient(colors: streakColor, startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.streak == 0 ? "💤" : "🔥")
                        .font(.title2)
                    Spacer()
                    Text("\(snapshot.streak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("wk streak")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Right: this month's challenge (or the silly title), then run/lift totals with
            // progress to the next milestone (3.1 B3).
            VStack(alignment: .leading, spacing: 6) {
                if let challenge = snapshot.challengeTitle {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(challenge)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 2)
                        Text(snapshot.challengeFraction, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityElement(children: .combine)
                } else {
                    Text(snapshot.sillyTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                MediumStatRow(
                    label: "Distance", systemImage: "figure.walk",
                    total: snapshot.distanceTotal, remaining: snapshot.distanceRemaining,
                    progress: snapshot.distanceProgress, tint: Color(red: 0.15, green: 0.39, blue: 0.92)
                )
                MediumStatRow(
                    label: "Lift", systemImage: "dumbbell.fill",
                    total: snapshot.weightTotal, remaining: snapshot.weightRemaining,
                    progress: snapshot.weightProgress, tint: Color(red: 0.49, green: 0.23, blue: 0.93)
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemGroupedBackground))
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

/// "Distance  12.4 mi" over a progress bar and "1.2 mi to next milestone".
private struct MediumStatRow: View {
    let label: LocalizedStringKey
    let systemImage: String
    let total: String
    let remaining: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Label(label, systemImage: systemImage)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(total)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption2)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(tint)
            Text(remaining)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Widget Declaration

struct FunFitnessWidget: Widget {
    let kind = "FunFitnessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FunFitnessProvider()) { entry in
            FunFitnessWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FunFitness")
        .description("Your streak and progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // The views pad themselves, so let the gradients reach the widget's edges.
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    FunFitnessWidget()
} timeline: {
    FunFitnessEntry(snapshot: .empty)
    FunFitnessEntry(snapshot: WidgetSnapshot(
        streak: 4,
        longestStreak: 7,
        activeThisWeek: true,
        distanceProgress: 0.65,
        weightProgress: 0.4,
        nextDistanceMilestone: "Half Marathon!",
        nextWeightMilestone: "You've lifted 10,000 lbs!",
        sillyTitle: "Certified Hippo Hoister"
    ))
}

#Preview(as: .systemMedium) {
    FunFitnessWidget()
} timeline: {
    FunFitnessEntry(snapshot: WidgetSnapshot(
        streak: 4,
        longestStreak: 7,
        activeThisWeek: true,
        distanceProgress: 0.65,
        weightProgress: 0.4,
        nextDistanceMilestone: "Half Marathon!",
        nextWeightMilestone: "You've lifted 10,000 lbs!",
        sillyTitle: "Certified Hippo Hoister",
        distanceTotal: "9.4 mi",
        weightTotal: "8,200 lbs",
        distanceRemaining: "3.7 mi to next milestone",
        weightRemaining: "1,800 lbs to next milestone",
        challengeTitle: "🎃 Spooky Distance October",
        challengeFraction: 0.42
    ))
    FunFitnessEntry(snapshot: .empty)
}
