//
//  ExerciseProgressCards.swift
//  FunFitness
//
//  Progress-tab cards for named exercises (3.1, C3/C6): "Muscles Worked This Week" chips and a
//  personal record per exercise, which opens that exercise's history (FB-0022). The math lives in
//  ExerciseStats. A body heat map is a documented future enhancement (Jay, 2026-11-06).
//

import SwiftUI
import Charts

struct MusclesWorkedCard: View {
    let activities: [ActivityLog]

    private var counts: [ExerciseStats.MuscleCount] {
        let library = ExerciseLibrary.shared
        return ExerciseStats.musclesWorked(
            sets: activities.filter { $0.exerciseID != nil }.map(ExerciseStats.SetFacts.init),
            lookup: { library.exercise(id: $0) },
            now: Date()
        )
    }

    var body: some View {
        let counts = counts
        if !counts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Muscles Worked This Week")
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)

                FlowLayout(spacing: 8) {
                    ForEach(counts) { count in
                        HStack(spacing: 6) {
                            Text(count.muscle.displayName)
                                .ffFont(.bodyStrong)
                                .foregroundStyle(Color.ffInk)
                            Text("\(count.sets)")
                                .ffFont(.caption)
                                .foregroundStyle(Color.ffOnAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.ffAccent, in: .capsule)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(chipFill(count, max: counts.first?.sets ?? 1), in: .capsule)
                        .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(count.muscle.displayName), \(count.sets) set\(count.sets == 1 ? "" : "s")")
                    }
                }

                Text("Sets per muscle group from named exercises, since the start of the week.")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }
            .ffCard()
            .accessibilityIdentifier("musclesWorkedCard")
        }
    }

    /// The most-worked muscles get the brighter chip (surface vs surface-alt keeps ink legible
    /// in both appearances, unlike fading a colour fill).
    private func chipFill(_ count: ExerciseStats.MuscleCount, max: Int) -> Color {
        guard max > 0 else { return .ffSurface }
        return Double(count.sets) / Double(max) >= 0.5 ? .ffSurface : .ffSurfaceAlt
    }
}

struct ExerciseRecordsCard: View {
    let activities: [ActivityLog]
    let pref: UnitPreference

    /// How many exercises to show before "Show All".
    private static let collapsedCount = 5
    @State private var showAll = false

    private var records: [(record: ExerciseStats.Record, exercise: Exercise)] {
        let library = ExerciseLibrary.shared
        return ExerciseStats.personalRecords(
            sets: activities.filter { $0.exerciseID != nil }.map(ExerciseStats.SetFacts.init)
        ).compactMap { record in
            library.exercise(id: record.exerciseID).map { (record, $0) }
        }
    }

    var body: some View {
        let records = records
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Exercise Records")
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)

                ForEach(showAll ? records : Array(records.prefix(Self.collapsedCount)), id: \.record.id) { item in
                    let display = UnitConverter.displayString(item.record.value, type: item.record.type, reps: item.record.reps, pref: pref)
                    NavigationLink {
                        ExerciseDetailView(exercise: item.exercise, type: item.record.type, activities: activities, pref: pref)
                    } label: {
                    HStack {
                        Text(item.record.type.emoji).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.exercise.name)
                                .ffFont(.body)
                                .foregroundStyle(Color.ffInk)
                            Text(item.record.date.formatted(date: .abbreviated, time: .omitted))
                                .ffFont(.caption)
                                .foregroundStyle(Color.ffInkMuted)
                        }
                        Spacer()
                        Text(display)
                            .ffFont(.headline)
                            .foregroundStyle(Color.ffInk)
                        Image(systemName: "chevron.right")
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffInkMuted)
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.exercise.name) record: \(display), set \(item.record.date.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityHint("Shows this exercise's history")
                }

                if records.count > Self.collapsedCount {
                    Button(showAll ? "Show Fewer" : "Show All \(records.count)") {
                        withAnimation { showAll.toggle() }
                    }
                    .ffFont(.bodyStrong)
                    .foregroundStyle(Color.ffLink)
                }
            }
            .ffCard()
            .accessibilityIdentifier("exerciseRecordsCard")
        }
    }
}

// MARK: - Set text (FB-0022)

extension ExerciseStats.SetGroup {
    /// "3 × 10 @ 50 lb" for a lift, "3 × 12" for bodyweight reps.
    func text(type: ActivityType, pref: UnitPreference) -> String {
        type == .weight
            ? "\(count) × \(reps ?? 1) @ \(UnitConverter.weightString(value, pref: pref))"
            : "\(count) × \(UnitConverter.wholeInputString(value))"
    }
}

extension ExerciseStats {
    /// One occasion's sets in a line: "3 × 10 @ 50 lb and 1 × 8 @ 55 lb".
    static func summaryText(_ sets: [SetFacts], type: ActivityType, pref: UnitPreference) -> String {
        grouped(sets).map { $0.text(type: type, pref: pref) }.formatted(.list(type: .and, width: .narrow))
    }
}

// MARK: - Exercise history (FB-0022)

/// One exercise's progress: its best set each time over time, and every session's sets.
struct ExerciseDetailView: View {
    let exercise: Exercise
    let type: ActivityType
    let activities: [ActivityLog]
    let pref: UnitPreference

    /// How many sessions to list before "Show All".
    private static let collapsedCount = 10
    @State private var showAll = false

    private var occasions: [ExerciseStats.Occasion] {
        ExerciseStats.history(
            exerciseID: exercise.id, type: type,
            sets: activities.filter { $0.exerciseID == exercise.id }.map(ExerciseStats.SetFacts.init)
        )
    }

    private var unitLabel: String {
        type == .weight ? pref.weightUnit : String(localized: "reps")
    }

    var body: some View {
        let occasions = occasions
        ZStack {
            Color.ffBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard(occasions)
                    if occasions.count >= 2 { chartCard(occasions) }
                    sessionsCard(occasions)
                }
                .padding()
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("exerciseDetail")
    }

    private func summaryCard(_ occasions: [ExerciseStats.Occasion]) -> some View {
        let record = ExerciseStats.personalRecords(sets: occasions.flatMap(\.sets)).first
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(type.emoji).accessibilityHidden(true)
                Text("Personal Record")
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)
            }
            if let record {
                Text(UnitConverter.displayString(record.value, type: type, reps: record.reps, pref: pref))
                    .ffFont(.numeral)
                    .foregroundStyle(Color.ffInk)
                Text("Set \(record.date.formatted(date: .abbreviated, time: .omitted)) · \(occasions.count) session\(occasions.count == 1 ? "" : "s") logged")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }
            if !exercise.muscles.isEmpty {
                Text(exercise.muscles.map(\.displayName).formatted(.list(type: .and)))
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ffCard()
        .accessibilityElement(children: .combine)
    }

    private func chartCard(_ occasions: [ExerciseStats.Occasion]) -> some View {
        let points = occasions.compactMap { occasion in
            occasion.bestSet.map { (date: occasion.date, value: UnitConverter.fromSI($0.value, type: type, to: pref)) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Best Set Over Time")
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)
            Chart(points, id: \.date) { point in
                LineMark(x: .value("Date", point.date, unit: .day), y: .value(unitLabel, point.value))
                    .foregroundStyle(type.ffFill)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", point.date, unit: .day), y: .value(unitLabel, point.value))
                    .foregroundStyle(type.ffFill)
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
            // Start near the lowest set, not at zero, so small gains are visible.
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)
            .accessibilityLabel("\(exercise.name), best set each session")
            Text(type == .weight ? "Heaviest set each session · \(unitLabel)" : "Most reps in a set each session")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
        }
        .ffCard()
    }

    private func sessionsCard(_ occasions: [ExerciseStats.Occasion]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)
            ForEach(showAll ? occasions : Array(occasions.prefix(Self.collapsedCount)), id: \.date) { occasion in
                VStack(alignment: .leading, spacing: 2) {
                    Text(occasion.date.formatted(date: .abbreviated, time: .omitted))
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                    Text(ExerciseStats.summaryText(occasion.sets, type: type, pref: pref))
                        .ffFont(.body)
                        .foregroundStyle(Color.ffInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
            if occasions.count > Self.collapsedCount {
                Button(showAll ? "Show Fewer" : "Show All \(occasions.count)") {
                    withAnimation { showAll.toggle() }
                }
                .ffFont(.bodyStrong)
                .foregroundStyle(Color.ffLink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ffCard()
    }
}

#Preview("Exercise history") {
    // Six weekly bench sessions, getting a little heavier each time.
    let now = Date()
    let logs: [ActivityLog] = (0..<6).flatMap { week -> [ActivityLog] in
        let day = Calendar.current.date(byAdding: .day, value: -7 * (5 - week), to: now) ?? now
        let session = UUID()
        return (0..<3).map { set in
            let log = ActivityLog(
                type: .weight, value: 20 + Double(week) * 1.25 + (set == 2 ? 2.5 : 0),
                reps: set == 2 ? 6 : 10, loggedAt: day.addingTimeInterval(Double(set) * 120)
            )
            log.exerciseID = "bench-press"
            log.sessionID = session
            return log
        }
    }
    return NavigationStack {
        if let bench = ExerciseLibrary.shared.exercise(id: "bench-press") {
            ExerciseDetailView(exercise: bench, type: .weight, activities: logs, pref: .imperial)
        }
    }
}
