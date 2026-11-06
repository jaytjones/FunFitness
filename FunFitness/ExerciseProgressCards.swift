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
                    .font(.headline)
                    .foregroundStyle(.primary)

                FlowLayout(spacing: 8) {
                    ForEach(counts) { count in
                        HStack(spacing: 6) {
                            Text(count.muscle.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text("\(count.sets)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.25))
                                .clipShape(.capsule)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#7C3AED").opacity(chipOpacity(count, max: counts.first?.sets ?? 1)))
                        .clipShape(.capsule)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(count.muscle.displayName), \(count.sets) set\(count.sets == 1 ? "" : "s")")
                    }
                }

                Text("Sets per muscle group from named exercises, since the start of the week.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.appCard)
            .clipShape(.rect(cornerRadius: 20))
            .accessibilityIdentifier("musclesWorkedCard")
        }
    }

    /// The most-worked muscles get the strongest color.
    private func chipOpacity(_ count: ExerciseStats.MuscleCount, max: Int) -> Double {
        guard max > 0 else { return 1 }
        return 0.55 + 0.45 * Double(count.sets) / Double(max)
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
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(showAll ? records : Array(records.prefix(Self.collapsedCount)), id: \.record.id) { item in
                    let display = UnitConverter.displayString(item.record.value, type: item.record.type, reps: item.record.reps, pref: pref)
                    HStack {
                        Text(item.record.type.emoji).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.exercise.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(item.record.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(display)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.exercise.name) record: \(display), set \(item.record.date.formatted(date: .abbreviated, time: .omitted))")
                }

                if records.count > Self.collapsedCount {
                    Button(showAll ? "Show Fewer" : "Show All \(records.count)") {
                        withAnimation { showAll.toggle() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.appCard)
            .clipShape(.rect(cornerRadius: 20))
            .accessibilityIdentifier("exerciseRecordsCard")
        }
    }
}
