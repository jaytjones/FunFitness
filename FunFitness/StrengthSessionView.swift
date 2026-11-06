//
//  StrengthSessionView.swift
//  FunFitness
//
//  Full-screen live strength session (3.1 B1c): pick a rest length → session clock, set entry
//  (weight × reps or bodyweight reps) with a big Log Set button, rest countdown with Skip, and the
//  sets so far → End shows a summary. Each set is saved as it's logged. "Hide" closes the screen
//  while the session keeps going; Home's card and the Live Activity bring it back.
//

import SwiftUI
import SwiftData

struct StrengthSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AppViewModel

    private let manager = StrengthSessionManager.shared
    private enum Field { case weight, reps, bodyweight }

    @State private var restSeconds: TimeInterval = StrengthSession.defaultRest
    @State private var setType: ActivityType = .weight
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var bodyweightText = ""
    // One exercise per set type, so switching Weight ↔ Bodyweight keeps each choice. (3.1 C3)
    @State private var weightExerciseID: String?
    @State private var bodyweightExerciseID: String?
    @State private var showInputError = false
    @State private var showEndConfirm = false
    @FocusState private var focusedField: Field?

    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ffBg.ignoresSafeArea()

                switch manager.phase {
                case .idle:     startScreen
                case .active:   activeScreen
                case .finished: summaryScreen
                }
            }
            .navigationTitle(manager.phase == .finished ? "Session Done!" : "Strength Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear(perform: prefillIfEmpty)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            switch manager.phase {
            case .idle:
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ffInkMuted)
                }
                .accessibilityLabel("Close")
            case .active:
                Button("Hide") { dismiss() }
                    .foregroundStyle(Color.ffLink)
                    .accessibilityHint("Keeps the session running in the background")
                    .accessibilityIdentifier("strengthHideButton")
            case .finished:
                EmptyView()
            }
        }
        if manager.phase == .active {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("End") { showEndConfirm = true }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.ffDanger)
                    .accessibilityIdentifier("strengthEndButton")
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { focusedField = nil }
                .foregroundStyle(Color.ffLink)
        }
    }

    // MARK: - Start

    private var startScreen: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            Text("🏋️")
                .font(.system(size: 80))
                .accessibilityHidden(true)

            Text("Log each set as you go. A rest timer starts after every set, and your sets save as you log them.")
                .ffFont(.body)
                .foregroundStyle(Color.ffInkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            restPicker

            Spacer(minLength: 0)

            if (WorkoutTracker.shared.phase != .idle) {
                Text("Finish your walk or run before starting a strength session.")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                WorkoutLiveActivityController.shared.configure(pref: pref, packId: viewModel.activePack.id)
                manager.start(restSeconds: restSeconds, context: modelContext, viewModel: viewModel)
            } label: {
                Text("Start Session")
            }
            .buttonStyle(.ffPrimary)
            .disabled((WorkoutTracker.shared.phase != .idle))
            .padding(.horizontal)
            .padding(.bottom)
            .accessibilityIdentifier("strengthStartButton")
        }
    }

    private var restPicker: some View {
        VStack(spacing: 8) {
            Text("Rest between sets")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
            HStack(spacing: 8) {
                ForEach(StrengthSession.restOptions, id: \.self) { option in
                    SelectionChip(
                        title: UnitConverter.elapsedString(option),
                        isSelected: restSeconds == option,
                        selectedBackground: .ffAccent,
                        action: {
                            restSeconds = option
                            manager.setRestSeconds(option)
                        }
                    )
                }
            }
        }
        .accessibilityIdentifier("strengthRestPicker")
    }

    // MARK: - Active

    private var activeScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let session = manager.session {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(spacing: 16) {
                            sessionHeader(session, now: context.date)
                            restBanner(session, now: context.date)
                        }
                    }

                    setEntry

                    if !session.sets.isEmpty {
                        setList(session)
                    }

                    restPicker
                }
            }
            .padding()
        }
        .modifier(SwipeActionsContainer())
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("End this session?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End Session") { manager.end() }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Your sets are already saved.")
        }
    }

    private func sessionHeader(_ session: StrengthSession, now: Date) -> some View {
        HStack(alignment: .top) {
            stat("Time", UnitConverter.elapsedString(manager.elapsedSeconds(at: now)))
            stat(session.setCount == 1 ? "Set" : "Sets", "\(session.setCount)")
            stat("Lifted", session.totalLiftedKg > 0 ? UnitConverter.weightString(session.totalLiftedKg, pref: pref) : "—")
        }
        .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
    }

    @ViewBuilder
    private func restBanner(_ session: StrengthSession, now: Date) -> some View {
        if session.isResting(at: now) {
            let remaining = session.restRemaining(at: now)
            VStack(spacing: 8) {
                HStack {
                    Label("Rest", systemImage: "hourglass")
                        .ffFont(.headline)
                    Spacer()
                    Text(UnitConverter.elapsedString(remaining.rounded(.up)))
                        .ffFont(.numeral)
                }
                SwiftUI.ProgressView(value: session.restSeconds > 0 ? 1 - remaining / session.restSeconds : 1)
                    .progressViewStyle(FitnessProgressStyle(tint: .ffAccent2))
                    .accessibilityHidden(true)
                Button("Skip rest") { manager.skipRest() }
                    .ffFont(.bodyStrong)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("strengthSkipRestButton")
            }
            .foregroundStyle(Color.ffOnTypeDuration)
            .ffCard(padding: FFSpace.s4, radius: FFRadius.md, fill: .ffTypeDuration)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Resting, \(Int(remaining.rounded(.up))) seconds left")
        } else if session.setCount > 0 {
            Text("Ready for your next set 💪")
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)
                .frame(maxWidth: .infinity)
                .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
        }
    }

    private var setEntry: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Set type", selection: $setType) {
                Text("Weight").tag(ActivityType.weight)
                Text("Bodyweight").tag(ActivityType.reps)
            }
            .pickerStyle(.segmented)
            .onChange(of: setType) { showInputError = false }

            ExercisePickerRow(
                type: setType,
                exerciseID: setType == .weight ? $weightExerciseID : $bodyweightExerciseID,
                showError: showInputError && currentExercise == nil
            )

            if setType == .weight {
                HStack(spacing: 12) {
                    numberField("Weight (\(pref.weightUnit))", text: $weightText, field: .weight, keyboard: .decimalPad)
                    Text("×").ffFont(.headline).foregroundStyle(Color.ffInkMuted).accessibilityHidden(true)
                    numberField("Reps", text: $repsText, field: .reps)
                }
            } else {
                numberField("Reps", text: $bodyweightText, field: .bodyweight)
                if let hint = ActivityType.reps.fieldHint {
                    Text(hint).ffFont(.caption).foregroundStyle(Color.ffInkMuted)
                }
            }

            if showInputError {
                Text(currentExercise == nil ? "Choose an exercise for this set" : setType == .weight
                     ? "Enter a weight above 0 and \(ActivityType.repCountRange.lowerBound)–\(ActivityType.repCountRange.upperBound) reps"
                     : "Enter \(ActivityType.repCountRange.lowerBound)–\(ActivityType.repCountRange.upperBound) reps")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffDanger)
            }

            Button(action: logSet) {
                Label("Log Set", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.ffPrimary)
            .accessibilityIdentifier("strengthLogSetButton")
        }
        .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
    }

    private func numberField(_ label: String, text: Binding<String>, field: Field, keyboard: UIKeyboardType = .numberPad) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
            TextField("0", text: text)
                .keyboardType(keyboard)
                .ffFont(.numeral)
                .foregroundStyle(Color.ffInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .ffWell(radius: FFRadius.sm)
                .focused($focusedField, equals: field)
                .accessibilityLabel(label)
        }
    }

    private func setList(_ session: StrengthSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This session")
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)
            ForEach(Array(session.sets.enumerated().reversed()), id: \.element.id) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                        .frame(width: 56, alignment: .leading)
                    Text(set.type.emoji)
                        .frame(width: 32, height: 32)
                        .background(set.type.ffFill, in: .rect(cornerRadius: FFRadius.sm / 2, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: FFRadius.sm / 2, style: .continuous).strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
                        .accessibilityHidden(true)
                    Text(WorkoutLiveActivityContent.namedSetText(set, pref: pref))
                        .ffFont(.bodyStrong)
                        .foregroundStyle(Color.ffInk)
                    Spacer()
                    Text(set.loggedAt.formatted(date: .omitted, time: .shortened))
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                .padding(.vertical, 4)
                .contentShape(.rect)
                .accessibilityElement(children: .combine)
                // Swipe to delete (iOS 27+, see SwipeActionsContainer); long-press works everywhere.
                // Deleting here or in History removes the set everywhere. (FB-0001)
                .swipeActions {
                    Button(role: .destructive) {
                        manager.deleteSet(id: set.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        manager.deleteSet(id: set.id)
                    } label: {
                        Label("Delete Set", systemImage: "trash")
                    }
                }
                .accessibilityAction(named: "Delete Set") {
                    manager.deleteSet(id: set.id)
                }
            }
        }
        .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
    }

    // MARK: - Summary

    private var summaryScreen: some View {
        VStack(spacing: 20) {
            if let session = manager.session {
                Text("🎉")
                    .font(.system(size: 64))
                    .accessibilityHidden(true)

                HStack(alignment: .top) {
                    stat("Time", UnitConverter.elapsedString(manager.elapsedSeconds(at: .now)))
                    stat(session.setCount == 1 ? "Set" : "Sets", "\(session.setCount)")
                }
                HStack(alignment: .top) {
                    stat("Lifted", session.totalLiftedKg > 0 ? UnitConverter.weightString(session.totalLiftedKg, pref: pref) : "—")
                    stat("Bodyweight reps", session.totalBodyweightReps > 0 ? "\(session.totalBodyweightReps)" : "—")
                }

                if session.totalLiftedKg > 0,
                   let fit = ReferenceUnitEngine.bestFit(total: session.totalLiftedKg, type: .weight, packId: viewModel.activePack.id) {
                    Text("You lifted \(fit.phrase) \(fit.unit.emoji)")
                        .ffFont(.headline)
                        .foregroundStyle(Color.ffOnAccent2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .ffCard(padding: FFSpace.s4, radius: FFRadius.md, fill: .ffAccent2)
                }

                Text(session.setCount == 0 ? "No sets logged this time." : "Every set is already in your log.")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }

            Spacer(minLength: 0)

            Button {
                manager.reset()
                dismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(.ffPrimary)
            .accessibilityIdentifier("strengthDoneButton")
        }
        .padding()
    }

    // MARK: - Helpers

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .ffFont(.numeral)
                .foregroundStyle(Color.ffInk)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    /// Starts the fields from the person's most recent sets so a typical next set is one tap.
    private func prefillIfEmpty() {
        if let session = manager.session { restSeconds = session.restSeconds }
        if weightText.isEmpty,
           let lastWeight = viewModel.activities.filter({ $0.activityType == .weight }).max(by: { $0.loggedAt < $1.loggedAt }) {
            weightText = UnitConverter.weightInputString(lastWeight.value, pref: pref)
        }
        if repsText.isEmpty {
            repsText = "\(viewModel.lastReps(for: .weight) ?? 10)"
        }
        if weightExerciseID == nil { weightExerciseID = viewModel.lastExerciseID(for: .weight) }
        if bodyweightExerciseID == nil { bodyweightExerciseID = viewModel.lastExerciseID(for: .reps) }
        if bodyweightText.isEmpty {
            let lastBodyweight = viewModel.activities.filter { $0.activityType == .reps }.max { $0.loggedAt < $1.loggedAt }
            bodyweightText = lastBodyweight.map { UnitConverter.wholeInputString($0.value) } ?? "10"
        }
    }

    /// The chosen exercise for the current set type; required to log a set. (3.1 C3)
    private var currentExercise: Exercise? {
        ExerciseLibrary.shared.exercise(id: setType == .weight ? weightExerciseID : bodyweightExerciseID)
    }

    private func logSet() {
        guard let exercise = currentExercise else {
            showInputError = true
            return
        }
        let logged: Bool
        switch setType {
        case .weight:
            guard let weight = Double(weightText), weight > 0,
                  let reps = ActivityType.parseRepCount(repsText) else {
                showInputError = true
                return
            }
            logged = manager.logSet(type: .weight, valueSI: UnitConverter.toKg(weight, from: pref), reps: reps, exerciseID: exercise.id)
        default:
            guard let count = ActivityType.parseRepCount(bodyweightText) else {
                showInputError = true
                return
            }
            logged = manager.logSet(type: .reps, valueSI: Double(count), reps: nil, exerciseID: exercise.id)
        }
        showInputError = !logged
        if logged { focusedField = nil }
    }
}

/// Lets `.swipeActions` work on the set rows outside a `List`. Needs iOS 27; earlier versions
/// fall back to the rows' long-press menu.
private struct SwipeActionsContainer: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.swipeActionsContainer()
        } else {
            content
        }
    }
}

#Preview {
    StrengthSessionView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self, UserProfile.self, WorkoutSession.self], inMemory: true)
}

