//
//  QuickLogView.swift
//  FunFitnessWatch Watch App
//
//  Quick-log a lift, a bodyweight set, or a timed activity from the wrist (3.1). Lifts and
//  bodyweight sets need an exercise, like on the phone (C3). The entry goes to the phone, which
//  saves it like any other log.
//

import SwiftUI

struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: WatchQuickLog.Kind

    private let link = PhoneLink.shared

    @State private var exerciseID: String?
    /// Weight in the person's unit (lbs or kg), a rep count, or minutes, depending on `kind`.
    @State private var amount: Double = 0
    @State private var reps: Int = 10
    @State private var sent = false

    private var usesMetric: Bool { link.usesMetric }
    private var needsExercise: Bool { kind == .lift || kind == .bodyweight }
    private var exercises: [WatchExercise] { link.exercises(for: kind) }
    private var selectedName: String? { exercises.first { $0.id == exerciseID }?.name }

    private var title: String {
        switch kind {
        case .lift:       return "Lift"
        case .bodyweight: return "Bodyweight"
        case .duration:   return "Duration"
        case .distance:   return "Distance"
        }
    }

    private var amountLabel: String {
        switch kind {
        case .lift:       return usesMetric ? "kg" : "lbs"
        case .bodyweight: return "reps"
        default:          return "min"
        }
    }

    private var step: Double { kind == .lift ? (usesMetric ? 2.5 : 5) : 1 }

    var body: some View {
        Group {
            if sent {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green)
                    Text("Sent to your iPhone").multilineTextAlignment(.center)
                }
                .task {
                    try? await Task.sleep(for: .seconds(1.2))
                    dismiss()
                }
            } else if needsExercise && exercises.isEmpty {
                Text("Open FunFitness on your iPhone once to load your exercises.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                form
            }
        }
        .navigationTitle(title)
        .onAppear(perform: prefill)
    }

    private var form: some View {
        List {
            if needsExercise {
                NavigationLink {
                    List(exercises) { exercise in
                        Button(exercise.name) { exerciseID = exercise.id }
                            .foregroundStyle(exercise.id == exerciseID ? .green : .primary)
                    }
                    .navigationTitle("Exercise")
                } label: {
                    VStack(alignment: .leading) {
                        Text("Exercise").font(.footnote).foregroundStyle(.secondary)
                        Text(selectedName ?? "Choose").foregroundStyle(selectedName == nil ? .orange : .primary)
                    }
                }
            }

            Stepper(value: $amount, in: 0...2_000, step: step) {
                Text("\(amount.formatted(.number.precision(.fractionLength(0...1)))) \(amountLabel)")
                    .font(.title3.monospacedDigit())
            }

            if kind == .lift {
                Stepper(value: $reps, in: 1...999) {
                    Text("× \(reps) reps").font(.title3.monospacedDigit())
                }
            }

            Button("Log \(title)", action: log)
                .tint(.green)
                .disabled(amount <= 0 || (needsExercise && selectedName == nil))
        }
    }

    private func prefill() {
        guard amount == 0 else { return }
        exerciseID = link.context?.lastExerciseIDs[kind.rawValue]
        switch kind {
        case .lift:
            let kg = link.context?.lastLiftKg ?? (usesMetric ? 20 : 45 * WatchContext.kgPerPound)
            amount = usesMetric ? kg : (kg / WatchContext.kgPerPound).rounded()
            reps = link.context?.lastLiftReps ?? 10
        case .bodyweight: amount = 10
        default:          amount = 30
        }
    }

    private func log() {
        let value: Double
        switch kind {
        case .lift: value = usesMetric ? amount : amount * WatchContext.kgPerPound
        default:    value = amount
        }
        link.send(WatchQuickLog(
            id: UUID(),
            kind: kind,
            value: value,
            reps: kind == .lift ? reps : nil,
            exerciseID: needsExercise ? exerciseID : nil,
            date: Date()
        ))
        sent = true
    }
}
