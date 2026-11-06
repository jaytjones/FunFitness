//
//  ExerciseProgressCards.swift
//  FunFitness
//
//  Progress-tab cards for named exercises (3.1, C3/C6): "Muscles Worked This Week" chips and a
//  personal record per exercise. The math lives in ExerciseStats. A body heat map is a
//  documented future enhancement (Jay, 2026-11-06).
//

import SwiftUI

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
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.exercise.name) record: \(display), set \(item.record.date.formatted(date: .abbreviated, time: .omitted))")
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
