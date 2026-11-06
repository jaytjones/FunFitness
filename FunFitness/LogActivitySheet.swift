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
        _surface = State(initialValue: viewModel.lastSurface)
        _exerciseID = State(initialValue: viewModel.lastExerciseID(for: type))
    }

    private enum Field { case value, reps }

    @State private var selectedType: ActivityType
    @State private var inputValue: String = ""
    // Reps are on by default and prefilled from the last entry of the same type (2.4.4).
    @State private var includeReps = true
    // Typed rep count as text, so the field can be cleared while editing (2.4.4).
    @State private var repsText: String
    // Distance surface, prefilled from the last distance entry that had one. (3.1)
    @State private var surface: DistanceSurface?
    // Identical sets to save at once, grouped as one session (3.1 C2). Weight and bodyweight reps only.
    @State private var setsCount = 1
    // Required for Weight/Reps (3.1 C3), prefilled from the last entry of the same type.
    @State private var exerciseID: String?
    @State private var showExerciseError = false
    @State private var logDate: Date = Date()
    @State private var showValidationError = false
    @State private var showRepsError = false
    @FocusState private var focusedField: Field?

    private var pref: UnitPreference { viewModel.unitPreference }

    private static func prefilledReps(for type: ActivityType, viewModel: AppViewModel) -> String {
        "\(viewModel.lastReps(for: type) ?? 1)"
    }

    static let setsRange = 1...20

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
                Color.ffBg
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
                            setsCount = 1
                            exerciseID = viewModel.lastExerciseID(for: selectedType)
                            showExerciseError = false
                            showValidationError = false
                            showRepsError = false
                        }

                        // Live sessions are the other way to log (3.1): GPS for distance, a
                        // strength session for weight and bodyweight reps. One at a time.
                        let liveSessionRunning = WorkoutTracker.shared.isRecording || StrengthSessionManager.shared.isActive
                        if selectedType == .distance && !liveSessionRunning {
                            Button {
                                viewModel.liveSessionRequestedFromLogSheet = .tracker
                                dismiss()
                            } label: {
                                Label("Track a walk or run live instead", systemImage: "location.fill")
                                    .ffFont(.bodyStrong)
                                    .foregroundStyle(Color.ffLink)
                            }
                            .accessibilityIdentifier("trackLiveInsteadButton")
                        }
                        if (selectedType == .weight || selectedType == .reps) && !liveSessionRunning {
                            Button {
                                viewModel.liveSessionRequestedFromLogSheet = .strength
                                dismiss()
                            } label: {
                                Label("Start a live strength session instead", systemImage: "timer")
                                    .ffFont(.bodyStrong)
                                    .foregroundStyle(Color.ffLink)
                            }
                            .accessibilityIdentifier("strengthLiveInsteadButton")
                        }

                        if SessionGrouping.isGroupable(selectedType) {
                            ExercisePickerRow(type: selectedType, exerciseID: $exerciseID, showError: showExerciseError)
                                .padding(.horizontal)
                                .onChange(of: exerciseID) { showExerciseError = false }
                        }

                        // Value Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text(UnitConverter.fieldLabel(for: selectedType, pref: pref))
                                .ffFont(.headline)
                                .foregroundStyle(Color.ffInk)

                            TextField(
                                selectedType.usesDecimalInput ? "0.0" : "0",
                                text: $inputValue
                            )
                            .keyboardType(selectedType.usesDecimalInput ? .decimalPad : .numberPad)
                            .ffFont(.numeral)
                            .foregroundStyle(Color.ffInk)
                            .padding()
                            .ffWell()
                            .overlay(
                                RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
                                    .strokeBorder(showValidationError ? Color.ffDanger : Color.clear, lineWidth: FFStroke.card)
                            )
                            .focused($focusedField, equals: .value)
                            .accessibilityIdentifier("activityValueInput")

                            if let hint = selectedType.fieldHint {
                                Text(hint)
                                    .ffFont(.caption)
                                    .foregroundStyle(Color.ffInkMuted)
                                    .accessibilityIdentifier("activityFieldHint")
                            }

                            if showValidationError {
                                Text("Please enter a valid value greater than 0")
                                    .ffFont(.caption)
                                    .foregroundStyle(Color.ffDanger)
                            }
                        }
                        .padding(.horizontal)

                        // Reps (rep-using types only, e.g. weight)
                        if selectedType.usesReps {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $includeReps.animation()) {
                                    Text("Include rep count")
                                        .ffFont(.headline)
                                        .foregroundStyle(Color.ffInk)
                                }
                                .tint(Color.ffAccent)
                                .padding(.horizontal)

                                if includeReps {
                                    // Tap the number to type a count; +/− nudge it. (2.4.4)
                                    HStack(spacing: 20) {
                                        Button {
                                            stepReps(by: -1)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color.ffLink)
                                        }
                                        .accessibilityLabel("Decrease reps")

                                        HStack(spacing: 6) {
                                            TextField("1", text: $repsText)
                                                .keyboardType(.numberPad)
                                                .multilineTextAlignment(.trailing)
                                                .ffFont(.numeral)
                                                .foregroundStyle(Color.ffInk)
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
                                                .ffFont(.headline)
                                                .foregroundStyle(Color.ffInkMuted)
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
                                                .foregroundStyle(Color.ffLink)
                                        }
                                        .accessibilityLabel("Increase reps")
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .ffWell()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
                                            .strokeBorder(showRepsError ? Color.ffDanger : Color.clear, lineWidth: FFStroke.card)
                                    )
                                    .padding(.horizontal)
                                    .accessibilityIdentifier("repsControl")

                                    if showRepsError {
                                        Text("Enter a rep count from \(ActivityType.repCountRange.lowerBound) to \(ActivityType.repCountRange.upperBound)")
                                            .ffFont(.caption)
                                            .foregroundStyle(Color.ffDanger)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }

                        if SessionGrouping.isGroupable(selectedType) {
                            setsControl
                        }

                        if selectedType == .distance {
                            SurfacePicker(selection: $surface)
                                .padding(.horizontal)
                        }

                        // Date Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date & Time")
                                .ffFont(.headline)
                                .foregroundStyle(Color.ffInk)
                            DatePicker(
                                "Activity date",
                                selection: $logDate,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color.ffAccent)
                            .accessibilityIdentifier("activityDatePicker")
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 0)

                        // Submit
                        Button { logActivity() } label: {
                            HStack {
                                Text(setsCount > 1 ? "Log \(setsCount) Sets" : "Log \(selectedType.displayName)")
                                Text(selectedType.emoji)
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(.ffPrimary)
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
                            .foregroundStyle(Color.ffInkMuted)
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .foregroundStyle(Color.ffLink)
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
        let needsExercise = SessionGrouping.isGroupable(selectedType) && ExerciseLibrary.shared.exercise(id: exerciseID) == nil
        showExerciseError = needsExercise
        guard let rawValue = Double(inputValue), rawValue > 0 else {
            showValidationError = true
            return
        }
        showValidationError = false
        guard !needsExercise else { return }

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

        let newMilestones: [Milestone]
        if SessionGrouping.isGroupable(selectedType) {
            // Strength: one or more sets; several are saved together as a session. (3.1 C2)
            newMilestones = ActivityWriter.logSets(
                type: selectedType, value: siValue, reps: reps, sets: setsCount, date: logDate,
                exerciseID: exerciseID, context: modelContext, viewModel: viewModel
            )
        } else {
            newMilestones = ActivityWriter.log(
                type: selectedType,
                value: siValue,
                reps: reps,
                date: logDate,
                surface: surface,
                context: modelContext,
                viewModel: viewModel,
                writeBackToHealth: profiles.first?.healthKitWriteBackEnabled ?? false
            )
        }
        viewModel.celebrate(newMilestones)

        dismiss()
    }
}

// MARK: - Sets

private extension LogActivitySheet {
    /// "Sets  − 3 +" with a hint that several sets become one session. (3.1 C2)
    var setsControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Text("Sets")
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)
                Spacer()
                Button {
                    setsCount = max(setsCount - 1, Self.setsRange.lowerBound)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.ffLink.opacity(setsCount > Self.setsRange.lowerBound ? 1 : 0.4))
                }
                .disabled(setsCount <= Self.setsRange.lowerBound)
                .accessibilityLabel("Decrease sets")

                Text("\(setsCount)")
                    .ffFont(.numeral)
                    .foregroundStyle(Color.ffInk)
                    .frame(minWidth: 36)
                    .accessibilityLabel("\(setsCount) set\(setsCount == 1 ? "" : "s")")
                    .accessibilityIdentifier("setsCount")

                Button {
                    setsCount = min(setsCount + 1, Self.setsRange.upperBound)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.ffLink.opacity(setsCount < Self.setsRange.upperBound ? 1 : 0.4))
                }
                .disabled(setsCount >= Self.setsRange.upperBound)
                .accessibilityLabel("Increase sets")
            }
            .padding()
            .ffWell()

            if setsCount > 1 {
                Text("Saves \(setsCount) identical sets as one session in History.")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }
        }
        .padding(.horizontal)
        .accessibilityIdentifier("setsControl")
    }
}

#Preview {
    LogActivitySheet(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self], inMemory: true)
}

#Preview("Weight") {
    LogActivitySheet(viewModel: AppViewModel(), initialType: .weight)
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self], inMemory: true)
}
