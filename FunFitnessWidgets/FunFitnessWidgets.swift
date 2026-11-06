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

/// Playful Bold: ink text straight on the `bg` ground (yellow in light, grape in dark).
struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpace.s1) {
            HStack {
                StreakFlame(streak: snapshot.streak)
                    .font(.title3.weight(.semibold))
                Spacer()
                if snapshot.activeThisWeek {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ffInk)
                }
            }
            Spacer()
            Text("\(snapshot.streak)")
                .ffFont(.numeral)
                .foregroundStyle(Color.ffInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("week streak")
                .ffFont(.label)
                .foregroundStyle(Color.ffInkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(FFSpace.s4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.ffBg, for: .widget)
    }
}

/// The streak glyph: the flame (the `streak` token's one job) while a streak runs, a quiet
/// moon while it's at zero ("gentle on misses"). SF Symbols replace the old 🔥/💤 emoji.
private struct StreakFlame: View {
    let streak: Int

    var body: some View {
        if streak == 0 {
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(Color.ffInkMuted)
        } else {
            Image(systemName: "flame.fill")
                .foregroundStyle(Color.ffStreak)
        }
    }
}

// MARK: - Medium (4×2)

/// Playful Bold: the streak in an inset, outlined white tile on the left; the challenge and the
/// Distance/Lift meters as ink on the `bg` ground on the right. In tinted/clear Home Screen
/// modes the tile drops its fill and keeps its outline.
struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: FFSpace.s3) {
            // Left: streak
            VStack(alignment: .leading, spacing: FFSpace.s1) {
                StreakFlame(streak: snapshot.streak)
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 0)
                Text("\(snapshot.streak)")
                    .ffFont(.numeral)
                    .foregroundStyle(Color.ffInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("wk streak")
                    .ffFont(.label)
                    .foregroundStyle(Color.ffInkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(FFSpace.s3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                renderingMode == .fullColor ? Color.ffSurface : Color.clear,
                in: RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
                    .strokeBorder(Color.ffLine, lineWidth: FFStroke.card)
            )
            // Right: this month's challenge (or the silly title), then run/lift totals with
            // progress to the next milestone (3.1 B3).
            VStack(alignment: .leading, spacing: FFSpace.s1 + 2) {
                if let challenge = snapshot.challengeTitle {
                    HStack(alignment: .firstTextBaseline, spacing: FFSpace.s1) {
                        Text(challenge)
                            .foregroundStyle(Color.ffInk)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 2)
                        Text(snapshot.challengeFraction, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(Color.ffInkMuted)
                    }
                    .ffFont(.caption)
                    .accessibilityElement(children: .combine)
                } else {
                    Text(snapshot.sillyTitle)
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                MediumStatRow(
                    label: "Distance", systemImage: "figure.walk",
                    total: snapshot.distanceTotal, remaining: snapshot.distanceRemaining,
                    progress: snapshot.distanceProgress, tint: .ffTypeDistance
                )
                MediumStatRow(
                    label: "Lift", systemImage: "dumbbell.fill",
                    total: snapshot.weightTotal, remaining: snapshot.weightRemaining,
                    progress: snapshot.weightProgress, tint: .ffTypeWeight
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(FFSpace.s3)
        .containerBackground(Color.ffBg, for: .widget)
    }
}

/// "DISTANCE  12.4 mi" over a slim meter and "1.2 mi to next milestone".
private struct MediumStatRow: View {
    let label: LocalizedStringKey
    let systemImage: String
    let total: String
    let remaining: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: FFSpace.s1) {
                Label(label, systemImage: systemImage)
                    .ffFont(.label)
                    .foregroundStyle(Color.ffInkMuted)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(total)
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            ProgressView(value: progress)
                .progressViewStyle(FFMeterStyle(fill: tint, height: 8))
            // The smallest text allowed in the widget (11pt, Widget.md).
            Text(remaining)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Color.ffInkMuted)
                .lineLimit(1)
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
        // The views pad themselves (Playful Bold spacing tokens).
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
