//
//  LogActivitySheet.swift
//  FunFitness
//

import SwiftUI
import SwiftData

struct LogActivitySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @Bindable var viewModel: AppViewModel

    /// `initialType` nil (the general "+" buttons) opens on the last-logged type; per-card
    /// buttons pass their own type. (2.4.4)
    init(viewModel: AppViewModel, initialType: ActivityType? = nil) {
        self.viewModel = viewModel
        let type = initialType ?? viewModel.defaultLogType
        _selectedType = State(initialValue: type)
        _repsText = State(initialValue: Self.prefilledReps(for: type, viewModel: viewModel))
    }

    private enum Field { case value, reps }

    @State private var selectedType: ActivityType
    @State private var inputValue: String = ""
    // Reps are on by default and prefilled from the last entry of the same type (2.4.4).
    @State private var includeReps = true
    // Typed rep count as text, so the field can be cleared while editing (2.4.4).
    @State private var repsText: String
    @State private var logDate: Date = Date()
    @State private var showValidationError = false
    @State private var showRepsError = false
    @FocusState private var focusedField: Field?

    private var pref: UnitPreference { viewModel.unitPreference }

    private static func prefilledReps(for type: ActivityType, viewModel: AppViewModel) -> String {
        "\(viewModel.lastReps(for: type) ?? 1)"
    }

    // Steps the typed count by `delta`, treating unparseable text as 1 and staying in range.
    private func stepReps(by delta: Int) {
        let range = ActivityType.repCountRange
        let current = ActivityType.parseRepCount(repsText) ?? range.lowerBound
        repsText = "\(min(max(current + delta, range.lowerBound), range.upperBound))"
        showRepsError = false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Activity Type Toggle — one segment per type (v2.2: distance, weight,
                        // duration, reps), so new types appear here automatically.
                        Picker("Activity Type", selection: $selectedType) {
                            ForEach(ActivityType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: selectedType) {
                            inputValue = ""
                            includeReps = true
                            repsText = Self.prefilledReps(for: selectedType, viewModel: viewModel)
                            showValidationError = false
                            showRepsError = false
                        }

                        // Live GPS tracking is the other way to log distance. (3.1)
                        if selectedType == .distance && !WorkoutTracker.shared.isRecording {
                            Button {
                                viewModel.trackerRequestedFromLogSheet = true
                                dismiss()
                            } label: {
                                Label("Track a walk or run live instead", systemImage: "location.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(hex: "#A78BFA"))
                            }
                            .accessibilityIdentifier("trackLiveInsteadButton")
                        }

                        // Value Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text(UnitConverter.fieldLabel(for: selectedType, pref: pref))
                                .font(.headline)
                                .foregroundStyle(.primary)

                            TextField(
                                selectedType.usesDecimalInput ? "0.0" : "0",
                                text: $inputValue
                            )
                            .keyboardType(selectedType.usesDecimalInput ? .decimalPad : .numberPad)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding()
                            .background(Color.appCard)
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(showValidationError ? Color.red : Color.clear, lineWidth: 2)
                            )
                            .focused($focusedField, equals: .value)
                            .accessibilityIdentifier("activityValueInput")

                            if let hint = selectedType.fieldHint {
                                Text(hint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("activityFieldHint")
                            }

                            if showValidationError {
                                Text("Please enter a valid value greater than 0")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal)

                        // Reps (rep-using types only, e.g. weight)
                        if selectedType.usesReps {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $includeReps.animation()) {
                                    Text("Include rep count")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                                .tint(Color(hex: "#A78BFA"))
                                .padding(.horizontal)

                                if includeReps {
                                    // Tap the number to type a count; +/− nudge it. (2.4.4)
                                    HStack(spacing: 20) {
                                        Button {
                                            stepReps(by: -1)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color(hex: "#A78BFA"))
                                        }
                                        .accessibilityLabel("Decrease reps")

                                        HStack(spacing: 6) {
                                            TextField("1", text: $repsText)
                                                .keyboardType(.numberPad)
                                                .multilineTextAlignment(.trailing)
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(.primary)
                                                .fixedSize()
                                                .focused($focusedField, equals: .reps)
                                                .accessibilityLabel("Rep count")
                                                .accessibilityIdentifier("repsInput")
                                                .onChange(of: repsText) {
                                                    // Digits only, at most as many as the max count.
                                                    let maxDigits = String(ActivityType.repCountRange.upperBound).count
                                                    let digits = String(repsText.filter(\.isNumber).prefix(maxDigits))
                                                    if digits != repsText { repsText = digits }
                                                    showRepsError = false
                                                }
                                            Text("reps")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                                .accessibilityHidden(true)
                                        }
                                        .frame(minWidth: 80)
                                        .contentShape(.rect)
                                        .onTapGesture { focusedField = .reps }

                                        Button {
                                            stepReps(by: 1)
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
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(showRepsError ? Color.red : Color.clear, lineWidth: 2)
                                    )
                                    .padding(.horizontal)
                                    .accessibilityIdentifier("repsControl")

                                    if showRepsError {
                                        Text("Enter a rep count from \(ActivityType.repCountRange.lowerBound) to \(ActivityType.repCountRange.upperBound)")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                            .padding(.horizontal)
                                    }
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
                                Text("Log \(selectedType.displayName)")
                                    .font(.headline)
                                Text(selectedType.emoji)
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
                    Button("Done") { focusedField = nil }
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
            .onAppear {
                focusedField = .value
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

        var reps: Int? = nil
        if selectedType.usesReps && includeReps {
            guard let count = ActivityType.parseRepCount(repsText) else {
                showRepsError = true
                return
            }
            reps = count
        }

        // Convert user input from display units to SI for storage
        let siValue = UnitConverter.toSI(rawValue, type: selectedType, from: pref)

        let newMilestones = ActivityWriter.log(
            type: selectedType,
            value: siValue,
            reps: reps,
            date: logDate,
            context: modelContext,
            viewModel: viewModel,
            writeBackToHealth: profiles.first?.healthKitWriteBackEnabled ?? false
        )
        viewModel.celebrate(newMilestones)

        dismiss()
    }
}

#Preview {
    LogActivitySheet(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}

#Preview("Weight") {
    LogActivitySheet(viewModel: AppViewModel(), initialType: .weight)
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
