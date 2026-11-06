//
//  ContentView.swift
//  FunFitnessWatch Watch App
//
//  Home: start a walk or run, or quick-log a lift, bodyweight set, or timed activity (3.1).
//

import SwiftUI

struct ContentView: View {
    private let workout = WorkoutManager.shared
    private let link = PhoneLink.shared

    var body: some View {
        NavigationStack {
            if workout.phase == .idle {
                home
            } else {
                WorkoutView()
            }
        }
    }

    private var home: some View {
        List {
            if let context = link.context {
                Section("This Week") {
                    TimelineView(.everyMinute) { timeline in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("⚡️ \(Int(context.effortPoints(asOf: timeline.date).rounded())) / \(Int(context.target)) pts")
                                .font(.headline)
                            Gauge(value: context.effortFraction(asOf: timeline.date)) { EmptyView() }
                                .gaugeStyle(.linearCapacity)
                                .tint(Color.brandYellow)
                                .accessibilityLabel("Effort Points progress")
                            if let streak = context.currentStreakWeeks {
                                Text("🔥 \(streak)-week streak")
                            }
                            if let km = context.totalDistanceKm, km > 0 {
                                Text("\(distanceText(km)) all-time")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Track") {
                ForEach(WorkoutManager.Kind.allCases) { kind in
                    Button {
                        Task { await workout.start(kind) }
                    } label: {
                        Label("Outdoor \(kind.name)", systemImage: kind.symbol)
                    }
                }
                if let error = workout.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }

            Section("Quick Log") {
                NavigationLink {
                    QuickLogView(kind: .lift)
                } label: {
                    Label("Lift", systemImage: "dumbbell.fill")
                }
                NavigationLink {
                    QuickLogView(kind: .bodyweight)
                } label: {
                    Label("Bodyweight", systemImage: "figure.strengthtraining.functional")
                }
                NavigationLink {
                    QuickLogView(kind: .duration)
                } label: {
                    Label("Duration", systemImage: "timer")
                }
            }

            if link.queuedCount > 0 {
                Text("\(link.queuedCount) waiting for your iPhone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("FunFitness")
    }

    private func distanceText(_ km: Double) -> String {
        link.usesMetric
            ? "\(km.formatted(.number.precision(.fractionLength(0...1)))) km"
            : "\((km / 1.60934).formatted(.number.precision(.fractionLength(0...1)))) mi"
    }
}

// MARK: - Live workout

struct WorkoutView: View {
    private let workout = WorkoutManager.shared

    private var usesMetric: Bool { PhoneLink.shared.usesMetric }

    var body: some View {
        if workout.phase == .finished {
            summary
        } else {
            live
        }
    }

    private var live: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VStack(alignment: .leading, spacing: 4) {
                Text(elapsedText(workout.elapsed(at: timeline.date)))
                    .font(.system(.title, design: .rounded).monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.brandYellow)
                Text(distanceText(workout.distanceMeters))
                    .font(.system(.title2, design: .rounded).monospacedDigit())
                if let bpm = workout.heartRate {
                    Label("\(Int(bpm.rounded())) bpm", systemImage: "heart.fill")
                        .foregroundStyle(.red)
                }
                Spacer(minLength: 4)
                HStack {
                    Button {
                        workout.phase == .paused ? workout.resume() : workout.pause()
                    } label: {
                        Image(systemName: workout.phase == .paused ? "play.fill" : "pause.fill")
                    }
                    .accessibilityLabel(workout.phase == .paused ? "Resume" : "Pause")
                    Button(role: .destructive) {
                        Task { await workout.end() }
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .accessibilityLabel("End workout")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(workout.phase == .paused ? "Paused" : workout.kind.name)
        .navigationBarBackButtonHidden()
    }

    private var summary: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("🎉").font(.largeTitle).accessibilityHidden(true)
                Text(distanceText(workout.distanceMeters)).font(.title3.weight(.semibold))
                Text(elapsedText(workout.finalElapsed)).foregroundStyle(.secondary)
                if let average = workout.averageHeartRate {
                    Text("♥ \(Int(average.rounded())) avg").foregroundStyle(.secondary)
                }
                Text(workout.errorMessage ?? "Saved to Apple Health and sent to FunFitness on your iPhone.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(workout.errorMessage == nil ? Color.secondary : Color.red)
                Button("Done") { workout.reset() }
                    .padding(.top, 4)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func distanceText(_ meters: Double) -> String {
        let value = usesMetric ? meters / 1000 : meters / 1609.34
        return String(format: "%.2f %@", value, usesMetric ? "km" : "mi")
    }

    private func elapsedText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

extension Color {
    /// Playful Bold `brand-yellow` (#FFD43B). The Watch keeps its black ground; the pink accent
    /// (`accent`) is the app's AccentColor. (3.2)
    static let brandYellow = Color(red: 1, green: 0xD4 / 255, blue: 0x3B / 255)
}

#Preview {
    ContentView()
}
