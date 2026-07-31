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
    @Query private var achievements: [UnlockedAchievement]
    @Bindable var viewModel: AppViewModel

    @State private var editingActivity: ActivityLog? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
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
                                .foregroundStyle(.primary)
                            Text("Log your first workout to see it here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(activities) { activity in
                                ActivityRow(activity: activity)
                                    .listRowBackground(Color.appCard)
                                    .listRowSeparatorTint(Color.primary.opacity(0.1))
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteActivity(activity)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            editingActivity = activity
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(Color(hex: "#5B21B6"))
                                    }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .accessibilityIdentifier("activityHistoryList")
                    }
                }
            }
            .navigationTitle("Activity History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
            .sheet(item: $editingActivity) { activity in
                EditActivitySheet(activity: activity) { value, loggedAt, notes in
                    commitEdit(activity: activity, value: value, loggedAt: loggedAt, notes: notes)
                }
            }
        }
    }

    private func deleteActivity(_ activity: ActivityLog) {
        viewModel.activities.removeAll { $0.id == activity.id }
        modelContext.delete(activity)
        try? modelContext.save()
    }

    private func commitEdit(activity: ActivityLog, value: Double, loggedAt: Date, notes: String?) {
        activity.value = value
        activity.loggedAt = loggedAt
        activity.notes = notes
        try? modelContext.save()
        reconcileAchievements()
    }

    private func reconcileAchievements() {
        let earned = viewModel.earnedMilestoneIds()
        let recorded = Set(achievements.map(\.milestoneId))

        for id in earned.subtracting(recorded) {
            modelContext.insert(UnlockedAchievement(milestoneId: id))
            viewModel.unlockedAchievementIds.insert(id)
        }

        let stale = recorded.subtracting(earned)
        for record in achievements where stale.contains(record.milestoneId) {
            modelContext.delete(record)
            viewModel.unlockedAchievementIds.remove(record.milestoneId)
        }
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
                    .foregroundStyle(.primary)
                Text(activity.loggedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(activity.activityType == .distance
                 ? String(format: "%.1f mi", activity.value)
                 : String(format: "%.0f lbs", activity.value))
                .font(.headline)
                .foregroundStyle(.primary)
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

// MARK: - Edit Activity Sheet

struct EditActivitySheet: View {
    @Environment(\.dismiss) private var dismiss

    let activity: ActivityLog
    let onSave: (Double, Date, String?) -> Void

    @State private var inputValue = ""
    @State private var loggedAt = Date()
    @State private var showValidationError = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Activity type (read-only indicator)
                    HStack {
                        Text(activity.activityType == .distance ? "🏃" : "💪")
                            .font(.title2)
                            .accessibilityHidden(true)
                        Text(activity.activityType == .distance ? "Distance" : "Weight Lifted")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(activity.activityType == .distance ? "miles" : "lbs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.appCard)
                    .clipShape(.rect(cornerRadius: 14))
                    .padding(.horizontal)

                    // Value field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(activity.activityType == .distance ? "Distance (miles)" : "Weight (lbs)")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        TextField(
                            activity.activityType == .distance ? "0.0" : "0",
                            text: $inputValue
                        )
                        .keyboardType(activity.activityType == .distance ? .decimalPad : .numberPad)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding()
                        .background(Color.appCard)
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(showValidationError ? Color.red : Color.clear, lineWidth: 2)
                        )
                        .focused($isInputFocused)
                        .accessibilityIdentifier("editActivityValueInput")

                        if showValidationError {
                            Text("Please enter a valid value greater than 0")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)

                    // Date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date & Time")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        DatePicker(
                            "Activity date",
                            selection: $loggedAt,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(Color(hex: "#A78BFA"))
                        .accessibilityIdentifier("editActivityDatePicker")
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button {
                        saveChanges()
                    } label: {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#5B21B6"))
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .accessibilityIdentifier("saveEditButton")
                }
                .padding(.top)
            }
            .navigationTitle("Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
            .onAppear {
                inputValue = activity.activityType == .distance
                    ? String(format: "%.1f", activity.value)
                    : String(format: "%.0f", activity.value)
                loggedAt = activity.loggedAt
                isInputFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func saveChanges() {
        guard let value = Double(inputValue), value > 0 else {
            showValidationError = true
            return
        }
        onSave(value, loggedAt, activity.notes)
        dismiss()
    }
}

#Preview {
    ActivityHistorySheet(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
