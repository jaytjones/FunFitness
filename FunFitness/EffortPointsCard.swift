//
//  EffortPointsCard.swift
//  FunFitness
//
//  Home card for this week's Effort Points (3.1, C7) and the "How your score works" sheet.
//  The math lives in EffortEngine.
//

import SwiftUI
import SwiftData

struct EffortPointsCard: View {
    @Query private var logs: [ActivityLog]
    @Query private var routes: [RouteSummary]
    @Query private var sessions: [WorkoutSession]
    @Query private var profiles: [UserProfile]

    @State private var showExplainer = false

    init() {
        // Only the last two weeks can land in this week (a session counts on the day it started),
        // so Home doesn't scan the whole log.
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        _logs = Query(filter: #Predicate<ActivityLog> { $0.loggedAt >= cutoff })
        _routes = Query(filter: #Predicate<RouteSummary> { $0.startedAt >= cutoff })
        _sessions = Query(filter: #Predicate<WorkoutSession> { $0.startedAt >= cutoff })
    }

    private var summary: EffortEngine.WeeklySummary {
        let entries = EffortEngine.entries(
            logs: logs.map(EffortEngine.LogFacts.init),
            routes: routes.map(EffortEngine.RouteFacts.init),
            sessions: sessions.map(EffortEngine.SessionFacts.init)
        )
        return EffortEngine.weeklySummary(entries: entries, age: profiles.first?.computedAge, now: Date())
    }

    var body: some View {
        let summary = summary
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("⚡️")
                    .font(.title)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.isComplete ? "Weekly Goal Reached! 🎉" : "Effort Points This Week")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("\(summary.pointsText) / \(summary.targetText) pts")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                // Reserve trailing space for the info button in the overlay below.
                Color.clear.frame(width: 24, height: 1)
            }

            SwiftUI.ProgressView(value: summary.fraction)
                .progressViewStyle(FitnessProgressStyle(tint: .white))
                .accessibilityHidden(true)

            Text(summary.includesEstimates
                 ? "Minutes × effort. Some entries had no time, so they're estimated."
                 : "Minutes × effort, from every kind of workout.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#0EA5E9"), Color(hex: "#4F46E5")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Effort Points this week: \(summary.pointsText) of \(summary.targetText)."
            + (summary.isComplete ? " Weekly goal reached." : "")
        )
        .accessibilityIdentifier("effortPointsCard")
        // Kept outside the combined element so VoiceOver can reach it.
        .overlay(alignment: .topTrailing) {
            Button {
                showExplainer = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("How your score works")
            .accessibilityIdentifier("effortPointsInfo")
            .padding(2)
        }
        .sheet(isPresented: $showExplainer) {
            EffortPointsExplainer()
        }
    }
}

/// The formula, written down for people (the C7 feedback asked for this).
struct EffortPointsExplainer: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Effort Points = minutes of activity × how hard you worked.")
                        .font(.headline)
                    Text("Aim for \(Int(EffortEngine.weeklyTarget)) points a week, a nod to the World Health Organization's 150 active minutes. That's about 85 minutes of walking or 30 minutes of running.")
                }

                Section("How hard you worked") {
                    LabeledContent("Heart-rate zone 1–5", value: "1–5 pts/min")
                    Text("When Apple Health has heart rate for a walk or run (from an Apple Watch or other sensor) and your profile has your date of birth, your zone sets the points. Zones are a share of your max heart rate (220 − your age): under 60% is zone 1, then every 10% is one more zone, up to zone 5 at 90%.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Walk", value: "1.75 pts/min")
                    LabeledContent("Run", value: "4.9 pts/min")
                    LabeledContent("Strength", value: "1.75 pts/min")
                    LabeledContent("Duration entries", value: "2 pts/min")
                    Text("Without heart rate, each activity uses half its MET value (a standard measure of effort from the Compendium of Physical Activities).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Where the minutes come from") {
                    Text("Tracked walks and runs: moving time, pauses left out.")
                    Text("Strength sessions with a start and end time: the session's length.")
                    Text("Duration entries: the minutes you logged.")
                    Text("Entries with no time are estimated: 12 minutes per km (a 5 km/h walk), or 2 minutes per strength set.")
                }

                Section {
                    Text("Effort Points aren't calories, and they don't count toward badges. They're a simple way to see how active your week was.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("How Your Score Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    EffortPointsCard()
        .padding()
        .modelContainer(for: [ActivityLog.self, RouteSummary.self, WorkoutSession.self, UserProfile.self], inMemory: true)
}
