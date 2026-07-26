//
//  ActivityHistorySheet.swift
//  FunFitness
//

import SwiftUI
import SwiftData

struct ActivityHistorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ActivityLog.loggedAt, order: .reverse) private var activities: [ActivityLog]
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D1A")
                    .ignoresSafeArea()

                Group {
                    if activities.isEmpty {
                        VStack(spacing: 16) {
                            Text("📋")
                                .font(.system(size: 60))
                                .accessibilityHidden(true)
                            Text("No Activities Logged")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Log your first workout to see it here.")
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "#9CA3AF"))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(activities) { activity in
                                ActivityRow(activity: activity)
                                    .listRowBackground(Color(hex: "#1A1A2E"))
                                    .listRowSeparatorTint(Color.white.opacity(0.1))
                            }
                            .onDelete { indexSet in
                                deleteActivities(at: indexSet)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Activity History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
        }
    }

    private func deleteActivities(at indexSet: IndexSet) {
        for index in indexSet {
            let activity = activities[index]
            viewModel.activities.removeAll { $0.id == activity.id }
            modelContext.delete(activity)
        }
        try? modelContext.save()
    }
}

struct ActivityRow: View {
    let activity: ActivityLog

    var body: some View {
        HStack {
            Text(activity.activityType == .distance ? "🏃" : "💪")
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.activityType == .distance ? "Distance" : "Weight Lifted")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(activity.loggedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }

            Spacer()

            Text(activity.activityType == .distance
                 ? String(format: "%.1f mi", activity.value)
                 : String(format: "%.0f lbs", activity.value))
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(activity.activityType == .distance ? "Distance" : "Weight lifted"), " +
            "\(activity.activityType == .distance ? String(format: "%.1f miles", activity.value) : String(format: "%.0f pounds", activity.value)), " +
            "logged \(activity.loggedAt.formatted(date: .abbreviated, time: .shortened))"
        )
    }
}

#Preview {
    ActivityHistorySheet(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self], inMemory: true)
}
