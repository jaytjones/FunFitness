//
//  LogActivitySheet.swift
//  FunFitness
//

import SwiftUI
import SwiftData

struct LogActivitySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: AppViewModel

    @State private var selectedType: ActivityType = .distance
    @State private var inputValue: String = ""
    @State private var includeReps = false
    @State private var repsCount: Int = 1
    @State private var logDate: Date = Date()
    @State private var showValidationError = false
    @FocusState private var isInputFocused: Bool

    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Activity Type Toggle
                        Picker("Activity Type", selection: $selectedType) {
                            Text("Distance").tag(ActivityType.distance)
                            Text("Weight").tag(ActivityType.weight)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: selectedType) {
                            inputValue = ""
                            includeReps = false
                            repsCount = 1
                            showValidationError = false
                        }

                        // Value Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedType == .distance
                                 ? "Distance (\(pref.distanceUnit))"
                                 : "Weight (\(pref.weightUnit))")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            TextField(
                                selectedType == .distance ? "0.0" : "0",
                                text: $inputValue
                            )
                            .keyboardType(selectedType == .distance ? .decimalPad : .numberPad)
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
                            .accessibilityIdentifier("activityValueInput")

                            if showValidationError {
                                Text("Please enter a valid value greater than 0")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal)

                        // Reps (weight only)
                        if selectedType == .weight {
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
                                    .accessibilityIdentifier("repsControl")
                                }
                            }
                        }

                        // Date Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date & Time")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            DatePicker(
                                "Activity date",
                                selection: $logDate,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color(hex: "#A78BFA"))
                            .accessibilityIdentifier("activityDatePicker")
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 0)

                        // Submit
                        Button { logActivity() } label: {
                            HStack {
                                Text(selectedType == .distance ? "Log Distance" : "Log Weight")
                                    .font(.headline)
                                Text(selectedType == .distance ? "🏃" : "💪")
                                    .accessibilityHidden(true)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#5B21B6"))
                            .clipShape(.rect(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                        .accessibilityIdentifier("logActivityButton")
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
            .onAppear {
                isInputFocused = true
                logDate = Date()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func logActivity() {
        guard let rawValue = Double(inputValue), rawValue > 0 else {
            showValidationError = true
            return
        }
        showValidationError = false

        // Convert user input from display units to SI for storage
        let siValue = selectedType == .distance
            ? UnitConverter.toKm(rawValue, from: pref)
            : UnitConverter.toKg(rawValue, from: pref)

        let reps = (selectedType == .weight && includeReps) ? repsCount : nil

        let previousTotal = selectedType == .distance ? viewModel.totalDistance : viewModel.totalWeight
        let newTotal      = previousTotal + (selectedType == .weight ? siValue * Double(reps ?? 1) : siValue)

        let activity = ActivityLog(type: selectedType, value: siValue, reps: reps, loggedAt: logDate)
        modelContext.insert(activity)
        try? modelContext.save()

        viewModel.activities.append(activity)

        let newMilestones = viewModel.checkForMilestones(
            type: selectedType,
            previousTotal: previousTotal,
            newTotal: newTotal
        )
        for milestone in newMilestones {
            modelContext.insert(UnlockedAchievement(milestoneId: milestone.id))
            viewModel.unlockedAchievementIds.insert(milestone.id)
        }
        if !newMilestones.isEmpty {
            viewModel.pendingMilestones = newMilestones
            viewModel.showMilestoneModal = true
        }

        dismiss()
    }
}

#Preview {
    LogActivitySheet(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
