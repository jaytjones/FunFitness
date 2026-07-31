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
                                ActivityRow(activity: activity, pref: viewModel.unitPreference)
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
                EditActivitySheet(
                    activity: activity,
                    pref: viewModel.unitPreference
                ) { value, reps, loggedAt, notes in
                    commitEdit(activity: activity, value: value, reps: reps, loggedAt: loggedAt, notes: notes)
                }
            }
        }
    }

    private func deleteActivity(_ activity: ActivityLog) {
        viewModel.activities.removeAll { $0.id == activity.id }
        modelContext.delete(activity)
        try? modelContext.save()
    }

    private func commitEdit(activity: ActivityLog, value: Double, reps: Int?, loggedAt: Date, notes: String?) {
        activity.value    = value
        activity.reps     = reps
        activity.loggedAt = loggedAt
        activity.notes    = notes
        try? modelContext.save()
        reconcileAchievements()
    }

    private func reconcileAchievements() {
        let earned   = viewModel.earnedMilestoneIds()
        let recorded = Set(achievements.map(\.milestoneId))

        for id in earned.subtracting(recorded) {
            modelContext.insert(UnlockedAchievement(milestoneId: id))
            viewModel.unlockedAchievementIds.insert(id)
        }
        for record in achievements where recorded.subtracting(earned).contains(record.milestoneId) {
            modelContext.delete(record)
            viewModel.unlockedAchievementIds.remove(record.milestoneId)
        }
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: ActivityLog
    let pref: UnitPreference

    private var valueLabel: String {
        if activity.activityType == .distance {
            return UnitConverter.distanceString(activity.value, pref: pref)
        } else {
            return UnitConverter.weightString(activity.value, reps: activity.reps, pref: pref)
        }
    }

    private var accessibilityLabel: String {
        let type = activity.activityType == .distance ? "Distance" : "Weight lifted"
        let date = activity.loggedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(type), \(valueLabel), logged \(date)"
    }

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

            Text(valueLabel)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Edit Activity Sheet

struct EditActivitySheet: View {
    @Environment(\.dismiss) private var dismiss

    let activity: ActivityLog
    let pref: UnitPreference
    let onSave: (Double, Int?, Date, String?) -> Void

    @State private var inputValue = ""
    @State private var includeReps = false
    @State private var repsCount = 1
    @State private var loggedAt = Date()
    @State private var showValidationError = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Type indicator (read-only)
                        HStack {
                            Text(activity.activityType == .distance ? "🏃" : "💪")
                                .font(.title2)
                                .accessibilityHidden(true)
                            Text(activity.activityType == .distance ? "Distance" : "Weight Lifted")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(activity.activityType == .distance ? pref.distanceUnit : pref.weightUnit)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.appCard)
                        .clipShape(.rect(cornerRadius: 14))
                        .padding(.horizontal)

                        // Value field
                        VStack(alignment: .leading, spacing: 8) {
                            Text(activity.activityType == .distance
                                 ? "Distance (\(pref.distanceUnit))"
                                 : "Weight (\(pref.weightUnit))")
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

                        // Reps (weight only)
                        if activity.activityType == .weight {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $includeReps.animation()) {
                                    Text("Include rep count")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                                .tint(Color(hex: "#A78BFA"))
                                .padding(.horizontal)

                                if includeReps {
                                    HStack(spacing: 20) {
                                        Button {
                                            if repsCount > 1 { repsCount -= 1 }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color(hex: "#A78BFA"))
                                        }
                                        .accessibilityLabel("Decrease reps")

                                        Text("\(repsCount) reps")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .frame(minWidth: 80)

                                        Button {
                                            repsCount += 1
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color(hex: "#A78BFA"))
                                        }
                                        .accessibilityLabel("Increase reps")
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.appCard)
                                    .clipShape(.rect(cornerRadius: 14))
                                    .padding(.horizontal)
                                }
                            }
                        }

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

                        Spacer(minLength: 0)

                        Button { saveChanges() } label: {
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
                // Pre-fill: convert stored SI → display units
                if activity.activityType == .distance {
                    inputValue = UnitConverter.distanceInputString(activity.value, pref: pref)
                } else {
                    inputValue = UnitConverter.weightInputString(activity.value, pref: pref)
                }
                if let existingReps = activity.reps, existingReps > 1 {
                    includeReps = true
                    repsCount   = existingReps
                }
                loggedAt       = activity.loggedAt
                isInputFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func saveChanges() {
        guard let rawValue = Double(inputValue), rawValue > 0 else {
            showValidationError = true
            return
        }
        let siValue = activity.activityType == .distance
            ? UnitConverter.toKm(rawValue, from: pref)
            : UnitConverter.toKg(rawValue, from: pref)
        let reps = (activity.activityType == .weight && includeReps) ? repsCount : nil
        onSave(siValue, reps, loggedAt, activity.notes)
        dismiss()
    }
}

#Preview {
    ActivityHistorySheet(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
