//
//  FunFitnessWatchWidgets.swift
//  FunFitnessWatchWidgets
//
//  Watch complications (3.1 build 12): weekly Effort Points toward the target, plus the
//  current streak. Reads the stats the Watch app saved from the phone (WatchStatsStore).
//

import WidgetKit
import SwiftUI

struct StatsEntry: TimelineEntry {
    let date: Date
    let streakWeeks: Int
    let effortPoints: Double
    let effortTarget: Double
    /// The phone hasn't sent anything yet.
    let isEmpty: Bool

    var fraction: Double { effortTarget > 0 ? min(1, effortPoints / effortTarget) : 0 }
    var pointsText: String { "\(Int(effortPoints.rounded()))" }

    static func load(at date: Date) -> StatsEntry {
        guard let context = WatchStatsStore.load() else {
            return StatsEntry(date: date, streakWeeks: 0, effortPoints: 0, effortTarget: 150, isEmpty: true)
        }
        return StatsEntry(
            date: date,
            streakWeeks: context.currentStreakWeeks ?? 0,
            effortPoints: context.effortPoints(asOf: date),
            effortTarget: context.target,
            isEmpty: false
        )
    }

    static let sample = StatsEntry(date: .now, streakWeeks: 6, effortPoints: 96, effortTarget: 150, isEmpty: false)
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(context.isPreview ? .sample : .load(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        // Now, and again when the week rolls over so Effort Points reset to 0. The Watch app
        // reloads timelines whenever new stats arrive from the phone.
        let now = Date()
        var entries = [StatsEntry.load(at: now)]
        if let nextWeek = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.end {
            entries.append(.load(at: nextWeek))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct StatsComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatsEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.fraction) {
                Image(systemName: "bolt.fill")
            } currentValueLabel: {
                Text(entry.pointsText)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel("Effort Points: \(entry.pointsText) of \(Int(entry.effortTarget))")

        case .accessoryCorner:
            Text("⚡️")
                .font(.title3)
                .widgetLabel {
                    Gauge(value: entry.fraction) {
                        Text("Effort")
                    } currentValueLabel: {
                        Text(entry.pointsText)
                    }
                }
                .accessibilityLabel("Effort Points: \(entry.pointsText) of \(Int(entry.effortTarget))")

        case .accessoryInline:
            Text("⚡️ \(entry.pointsText)/\(Int(entry.effortTarget)) · 🔥 \(entry.streakWeeks) wk")

        default:   // accessoryRectangular
            VStack(alignment: .leading, spacing: 2) {
                Text("FunFitness")
                    .font(.headline)
                    .widgetAccentable()
                if entry.isEmpty {
                    Text("Open on iPhone to sync")
                        .font(.caption)
                } else {
                    Text("⚡️ \(entry.pointsText) / \(Int(entry.effortTarget)) pts")
                    Gauge(value: entry.fraction) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                    Text("🔥 \(entry.streakWeeks)-week streak")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct FunFitnessWatchWidgets: Widget {
    let kind = "FunFitnessWatchStats"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            StatsComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Effort & Streak")
        .description("This week's Effort Points and your streak.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

#Preview(as: .accessoryRectangular) {
    FunFitnessWatchWidgets()
} timeline: {
    StatsEntry.sample
}

#Preview(as: .accessoryCircular) {
    FunFitnessWatchWidgets()
} timeline: {
    StatsEntry.sample
}
