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
    @State private var showInputError = false
    @State private var showEndConfirm = false
    @FocusState private var focusedField: Field?

    private var pref: UnitPreference { viewModel.unitPreference }
    private let accent = Color(hex: "#A78BFA")

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

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
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
            case .active:
                Button("Hide") { dismiss() }
                    .foregroundStyle(accent)
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
                    .foregroundStyle(accent)
                    .accessibilityIdentifier("strengthEndButton")
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { focusedField = nil }
                .foregroundStyle(accent)
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            restPicker

            Spacer(minLength: 0)

            if (WorkoutTracker.shared.phase != .idle) {
                Text("Finish your walk or run before starting a strength session.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                WorkoutLiveActivityController.shared.configure(pref: pref, packId: viewModel.activePack.id)
                manager.start(restSeconds: restSeconds, context: modelContext, viewModel: viewModel)
            } label: {
                Text("Start Session")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(hex: "#7C3AED").opacity((WorkoutTracker.shared.phase != .idle) ? 0.4 : 1))
                    .clipShape(.capsule)
            }
            .disabled((WorkoutTracker.shared.phase != .idle))
            .padding(.horizontal)
            .padding(.bottom)
            .accessibilityIdentifier("strengthStartButton")
        }
    }

    private var restPicker: some View {
        VStack(spacing: 8) {
            Text("Rest between sets")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(StrengthSession.restOptions, id: \.self) { option in
                    SelectionChip(
                        title: UnitConverter.elapsedString(option),
                        isSelected: restSeconds == option,
                        selectedBackground: accent,
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
        .padding()
        .background(Color.appCard)
        .clipShape(.rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func restBanner(_ session: StrengthSession, now: Date) -> some View {
        if session.isResting(at: now) {
            let remaining = session.restRemaining(at: now)
            VStack(spacing: 8) {
                HStack {
                    Label("Rest", systemImage: "hourglass")
                        .font(.headline)
                    Spacer()
                    Text(UnitConverter.elapsedString(remaining.rounded(.up)))
                        .font(.title2.weight(.bold).monospacedDigit())
                }
                SwiftUI.ProgressView(value: session.restSeconds > 0 ? 1 - remaining / session.restSeconds : 1)
                    .progressViewStyle(FitnessProgressStyle(tint: .white))
                    .accessibilityHidden(true)
                Button("Skip rest") { manager.skipRest() }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("strengthSkipRestButton")
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(colors: [Color(hex: "#D97706"), Color(hex: "#B45309")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(.rect(cornerRadius: 20))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Resting, \(Int(remaining.rounded(.up))) seconds left")
        } else if session.setCount > 0 {
            Text("Ready for your next set 💪")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appCard)
                .clipShape(.rect(cornerRadius: 20))
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

            if setType == .weight {
                HStack(spacing: 12) {
                    numberField("Weight (\(pref.weightUnit))", text: $weightText, field: .weight, keyboard: .decimalPad)
                    Text("×").font(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
                    numberField("Reps", text: $repsText, field: .reps)
                }
            } else {
                numberField("Reps", text: $bodyweightText, field: .bodyweight)
                if let hint = ActivityType.reps.fieldHint {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                }
            }

            if showInputError {
                Text(setType == .weight
                     ? "Enter a weight above 0 and \(ActivityType.repCountRange.lowerBound)–\(ActivityType.repCountRange.upperBound) reps"
                     : "Enter \(ActivityType.repCountRange.lowerBound)–\(ActivityType.repCountRange.upperBound) reps")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: logSet) {
                Label("Log Set", systemImage: "plus.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "#059669"))
                    .clipShape(.capsule)
            }
            .accessibilityIdentifier("strengthLogSetButton")
        }
        .padding()
        .background(Color.appCard)
        .clipShape(.rect(cornerRadius: 20))
    }

    private func numberField(_ label: String, text: Binding<String>, field: Field, keyboard: UIKeyboardType = .numberPad) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", text: text)
                .keyboardType(keyboard)
                .font(.system(size: 26, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground)
                .clipShape(.rect(cornerRadius: 12))
                .focused($focusedField, equals: field)
                .accessibilityLabel(label)
        }
    }

    private func setList(_ session: StrengthSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This session")
                .font(.headline)
                .foregroundStyle(.primary)
            ForEach(Array(session.sets.enumerated().reversed()), id: \.element.id) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    Text(set.type.emoji).accessibilityHidden(true)
                    Text(WorkoutLiveActivityContent.setText(set, pref: pref))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(set.loggedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(.rect(cornerRadius: 20))
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
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#D946EF")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(.rect(cornerRadius: 20))
                }

                Text(session.setCount == 0 ? "No sets logged this time." : "Every set is already in your log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                manager.reset()
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#5B21B6"))
                    .clipShape(.rect(cornerRadius: 14))
            }
            .accessibilityIdentifier("strengthDoneButton")
        }
        .padding()
    }

    // MARK: - Helpers

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
        if bodyweightText.isEmpty {
            let lastBodyweight = viewModel.activities.filter { $0.activityType == .reps }.max { $0.loggedAt < $1.loggedAt }
            bodyweightText = lastBodyweight.map { UnitConverter.wholeInputString($0.value) } ?? "10"
        }
    }

    private func logSet() {
        let logged: Bool
        switch setType {
        case .weight:
            guard let weight = Double(weightText), weight > 0,
                  let reps = ActivityType.parseRepCount(repsText) else {
                showInputError = true
                return
            }
            logged = manager.logSet(type: .weight, valueSI: UnitConverter.toKg(weight, from: pref), reps: reps)
        default:
            guard let count = ActivityType.parseRepCount(bodyweightText) else {
                showInputError = true
                return
            }
            logged = manager.logSet(type: .reps, valueSI: Double(count), reps: nil)
        }
        showInputError = !logged
        if logged { focusedField = nil }
    }
}

#Preview {
    StrengthSessionView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self, UserProfile.self], inMemory: true)
}

