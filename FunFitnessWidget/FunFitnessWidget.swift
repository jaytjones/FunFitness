//
//  FunFitnessWidget.swift
//  FunFitnessWidget
//
//  Streak + milestone-progress home screen widget.
//  Bundle entry point is in FunFitnessWidgetBundle.swift.
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
            // Right: title + progress bars
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.sillyTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer()
                VStack(alignment: .leading, spacing: 3) {
                    Label("Run", systemImage: "figure.run")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ProgressView(value: snapshot.distanceProgress)
                        .progressViewStyle(.linear)
                        .tint(Color(red: 0.15, green: 0.39, blue: 0.92))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Label("Lift", systemImage: "dumbbell.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ProgressView(value: snapshot.weightProgress)
                        .progressViewStyle(.linear)
                        .tint(Color(red: 0.49, green: 0.23, blue: 0.93))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemGroupedBackground))
        }
        .containerBackground(for: .widget) { Color.clear }
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
        sillyTitle: "Certified Hippo Hoister"
    ))
}
