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
    @Query private var sessions: [WorkoutSession]
    @Bindable var viewModel: AppViewModel

    @State private var editingActivity: ActivityLog? = nil
    @State private var sessionPendingDelete: SessionRoute? = nil

    private var sessionsByID: [UUID: WorkoutSession] {
        Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ffBg
                    .ignoresSafeArea()

                Group {
                    if activities.isEmpty {
                        VStack(spacing: 16) {
                            Text("📋")
                                .font(.system(size: 60))
                                .accessibilityHidden(true)
                            Text("No Activities Logged")
                                .ffFont(.title)
                                .foregroundStyle(Color.ffInk)
                            Text("Log your first workout to see it here.")
                                .ffFont(.body)
                                .foregroundStyle(Color.ffInkMuted)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        // Sets from one workout show as a single session row (3.1 C1).
                        List {
                            ForEach(HistoryItem.items(from: activities)) { item in
                                switch item {
                                case .single(let activity):
                                    activityRow(activity)
                                case .session(let id, let logs):
                                    let record = sessionsByID[id]
                                    NavigationLink(value: SessionRoute(id: id)) {
                                        SessionRow(
                                            logs: logs,
                                            isAutoGrouped: record?.isAutoGrouped ?? false,
                                            durationSeconds: record.flatMap { $0.isTimed ? $0.durationSeconds : nil },
                                            pref: viewModel.unitPreference
                                        )
                                    }
                                    .listRowBackground(Color.ffSurface)
                                    .listRowSeparatorTint(Color.ffProgressTrack)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            sessionPendingDelete = SessionRoute(id: id)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .accessibilityIdentifier("activityHistoryList")
                    }
                }
            }
            .navigationDestination(for: SessionRoute.self) { route in
                SessionDetailView(sessionID: route.id, viewModel: viewModel)
            }
            .confirmationDialog(
                "Delete this session and all its sets?",
                isPresented: Binding(get: { sessionPendingDelete != nil }, set: { if !$0 { sessionPendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: sessionPendingDelete
            ) { route in
                Button("Delete Session", role: .destructive) {
                    ActivityWriter.deleteSession(route.id, context: modelContext, viewModel: viewModel)
                }
                Button("Cancel", role: .cancel) {}
            }
            .navigationTitle("Activity History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.ffLink)
                }
            }
            .sheet(item: $editingActivity) { activity in
                EditActivitySheet(
                    activity: activity,
                    pref: viewModel.unitPreference
                ) { value, reps, loggedAt, notes, surface, exerciseID in
                    commitEdit(activity: activity, value: value, reps: reps, loggedAt: loggedAt, notes: notes, surface: surface, exerciseID: exerciseID)
                }
            }
        }
    }

    private func activityRow(_ activity: ActivityLog) -> some View {
        ActivityRow(activity: activity, pref: viewModel.unitPreference)
            .listRowBackground(Color.ffSurface)
            .listRowSeparatorTint(Color.ffProgressTrack)
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
                .tint(Color.ffAccent2)
            }
    }

    private func deleteActivity(_ activity: ActivityLog) {
        ActivityWriter.delete(activity, context: modelContext, viewModel: viewModel)
    }

    private func commitEdit(activity: ActivityLog, value: Double, reps: Int?, loggedAt: Date, notes: String?, surface: DistanceSurface?, exerciseID: String?) {
        Self.applyEdit(
            to: activity, value: value, reps: reps, loggedAt: loggedAt, notes: notes, surface: surface,
            exerciseID: exerciseID, achievements: achievements, context: modelContext, viewModel: viewModel
        )
    }

    /// Saves an edit from `EditActivitySheet`. Shared with the session detail screen.
    static func applyEdit(
        to activity: ActivityLog, value: Double, reps: Int?, loggedAt: Date, notes: String?, surface: DistanceSurface?,
        exerciseID: String? = nil,
        achievements: [UnlockedAchievement], context: ModelContext, viewModel: AppViewModel
    ) {
        activity.value    = value
        activity.reps     = reps
        activity.loggedAt = loggedAt
        activity.notes    = notes
        activity.surface  = activity.activityType == .distance ? surface : nil
        if SessionGrouping.isGroupable(activity.activityType) { activity.exerciseID = exerciseID }
        try? context.save()
        StrengthSessionManager.shared.syncWithStore()   // an edited live set updates there too (FB-0001)
        // An in-place edit doesn't reassign the activities array, so refresh the cached totals.
        viewModel.refreshTotals()
        // A local edit may lower a total, so revocation is allowed.
        viewModel.reconcileAchievements(records: achievements, context: context, forceRevocation: true)
    }
}

/// Navigation value for a session's detail screen.
struct SessionRoute: Hashable, Identifiable {
    let id: UUID
}

// MARK: - Session Row

/// "🏋️ Strength · 5 sets" over the date (and duration, once timed), with the session total on the
/// right. Calories stay off the row on purpose — they're only in the detail and Health. (3.1 C1/C4)
struct SessionRow: View {
    let logs: [ActivityLog]
    let isAutoGrouped: Bool
    /// The session's timed length, or nil when it isn't timed.
    var durationSeconds: TimeInterval? = nil
    let pref: UnitPreference

    /// The type whose colour fills the row's chip (weight unless the session is bodyweight reps).
    private var chipType: ActivityType { logs.first?.activityType ?? .weight }

    var body: some View {
        if let summary = SessionSummary(logs: logs) {
            HStack {
                Text(WorkoutSessionKind.strength.emoji)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(chipType.ffFill, in: .rect(cornerRadius: FFRadius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: FFRadius.sm, style: .continuous).strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(WorkoutSessionKind.strength.displayName) · \(summary.setsText)")
                        .ffFont(.bodyStrong)
                        .foregroundStyle(Color.ffInk)
                    Text(subtitle(summary))
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }

                Spacer()

                Text(summary.totalText(pref: pref))
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Strength session, \(summary.setsText), \(summary.totalText(pref: pref)), \(subtitle(summary))")
        }
    }

    // "Oct 16, 2026 at 8:11 PM · 42 min · Auto-grouped"
    private func subtitle(_ summary: SessionSummary) -> String {
        var parts = [summary.startedAt.formatted(date: .abbreviated, time: .shortened)]
        if let durationSeconds { parts.append(SessionTiming.durationText(durationSeconds)) }
        if isAutoGrouped { parts.append("Auto-grouped") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Session Detail

/// One session: its time (editable start/end → duration and an estimated calorie count), indoor/
/// outdoor, notes, Save to Apple Health, and its sets — each can be edited, deleted, or taken out.
/// The ⋯ menu has Ungroup and Delete Session. (3.1 C1, C4, C5, C8)
struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var logs: [ActivityLog]
    @Query private var records: [WorkoutSession]
    @Query private var achievements: [UnlockedAchievement]
    @Query private var profiles: [UserProfile]
    @Bindable var viewModel: AppViewModel

    let sessionID: UUID
    @State private var editingActivity: ActivityLog? = nil
    @State private var showDeleteConfirm = false
    @State private var showUngroupConfirm = false
    // Calorie weight (C4): Health's latest body weight, asked for once per screen when needed.
    @State private var healthWeightKg: Double?
    @State private var checkedHealthWeight = false
    @State private var showWeightPrompt = false
    @State private var weightText = ""

    init(sessionID: UUID, viewModel: AppViewModel) {
        self.sessionID = sessionID
        self.viewModel = viewModel
        let id: UUID? = sessionID
        _logs = Query(filter: #Predicate<ActivityLog> { $0.sessionID == id }, sort: \.loggedAt)
        _records = Query(filter: #Predicate<WorkoutSession> { $0.id == sessionID })
    }

    private var pref: UnitPreference { viewModel.unitPreference }
    private var record: WorkoutSession? { records.first }
    private var profile: UserProfile? { profiles.first }

    private var weightSource: CalorieWeightSource {
        CalorieWeightSource.resolve(
            profileWeightKg: profile?.weightKg,
            healthWeightKg: healthWeightKg,
            promptDeclined: profile?.calorieWeightPromptDeclined ?? false
        )
    }

    private var calorieWeightKg: Double? {
        if case .use(let kg) = weightSource { return kg }
        return nil
    }

    var body: some View {
        ZStack {
            Color.ffBg.ignoresSafeArea()

            List {
                if let summary = SessionSummary(logs: logs) {
                    Section {
                        LabeledContent("Sets", value: "\(summary.setCount)")
                        LabeledContent("Total", value: summary.totalText(pref: pref))
                    }
                    .listRowBackground(Color.ffSurface)
                }

                if let record {
                    SessionInfoSections(
                        session: record,
                        calorieWeightKg: calorieWeightKg,
                        savesToHealth: profile?.healthKitWriteBackEnabled ?? false
                    )
                }

                Section("Sets") {
                    ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .ffFont(.bodyStrong)
                                .foregroundStyle(Color.ffInkMuted)
                                .frame(minWidth: 20)
                                .accessibilityLabel("Set \(index + 1)")
                            ActivityRow(activity: log, pref: pref)
                        }
                        .listRowBackground(Color.ffSurface)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                ActivityWriter.delete(log, context: modelContext, viewModel: viewModel)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                ActivityWriter.removeFromSession(log, context: modelContext)
                            } label: {
                                Label("Remove from Session", systemImage: "rectangle.badge.minus")
                            }
                            .tint(Color.ffStreak)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingActivity = log
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color.ffAccent2)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("sessionDetailList")
        }
        .navigationTitle("Strength Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showUngroupConfirm = true
                    } label: {
                        Label("Ungroup Sets", systemImage: "square.split.2x1")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Session", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Session actions")
                .accessibilityIdentifier("sessionActionsMenu")
            }
        }
        .confirmationDialog("Ungroup these sets?", isPresented: $showUngroupConfirm, titleVisibility: .visible) {
            Button("Ungroup Sets") {
                ActivityWriter.ungroupSession(sessionID, context: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Each set becomes its own entry and won't be grouped automatically again.")
        }
        .confirmationDialog("Delete this session and all its sets?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Session", role: .destructive) {
                ActivityWriter.deleteSession(sessionID, context: modelContext, viewModel: viewModel)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Add your weight for calorie estimates", isPresented: $showWeightPrompt) {
            TextField(UnitConverter.displayUnit(for: .weight, pref: pref), text: $weightText)
                .keyboardType(.decimalPad)
            Button("Save") { saveTypedWeight() }
            Button("No Thanks", role: .cancel) {
                profile?.calorieWeightPromptDeclined = true
                try? modelContext.save()
            }
        } message: {
            Text("Used only to estimate calories for timed sessions. You can change it in Profile.")
        }
        .sheet(item: $editingActivity) { activity in
            EditActivitySheet(activity: activity, pref: pref) { value, reps, loggedAt, notes, surface, exerciseID in
                ActivityHistorySheet.applyEdit(
                    to: activity, value: value, reps: reps, loggedAt: loggedAt, notes: notes, surface: surface,
                    exerciseID: exerciseID, achievements: achievements, context: modelContext, viewModel: viewModel
                )
            }
        }
        .task(id: record?.isTimed) { await findCalorieWeightIfNeeded() }
        .onChange(of: logs.isEmpty) {
            // Last set deleted or removed: the session is gone.
            if logs.isEmpty { dismiss() }
        }
    }

    /// The weight order Jay chose: profile → Health (asking to read body weight) → one in-app
    /// prompt → duration only. Only runs for a timed session with no profile weight.
    private func findCalorieWeightIfNeeded() async {
        guard record?.isTimed == true, profile != nil, profile?.weightKg == nil, !checkedHealthWeight else { return }
        checkedHealthWeight = true
        healthWeightKg = await HealthKitManager.shared.latestBodyMassKg(requestingAccess: true)
        if weightSource == .askInApp { showWeightPrompt = true }
    }

    private func saveTypedWeight() {
        guard let value = Double(weightText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        profile?.weightKg = UnitConverter.toSI(value, type: .weight, from: pref)
        try? modelContext.save()
    }
}

/// The editable parts of a session record: time, calories, location, notes, Apple Health.
private struct SessionInfoSections: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    let calorieWeightKg: Double?
    let savesToHealth: Bool

    @State private var isSavingToHealth = false
    @State private var healthSaveFailed = false

    private var kcal: Double? {
        CalorieEstimator.kcal(seconds: session.durationSeconds, weightKg: calorieWeightKg)
    }

    /// Indoor / Outdoor / Not set, over the optional flag.
    private var location: Binding<Int> {
        Binding(
            get: { session.isIndoor.map { $0 ? 1 : 2 } ?? 0 },
            set: { session.isIndoor = $0 == 0 ? nil : $0 == 1 }
        )
    }

    var body: some View {
        Section {
            DatePicker("Start", selection: $session.startedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            DatePicker("End", selection: $session.endedAt, in: session.startedAt...Date.distantFuture, displayedComponents: [.date, .hourAndMinute])
            LabeledContent("Duration", value: session.isTimed ? SessionTiming.durationText(session.durationSeconds) : "Not timed")
            if let kcal {
                LabeledContent("Calories", value: CalorieEstimator.text(kcal))
                    .accessibilityIdentifier("sessionCalories")
            }
        } header: {
            Text("Time")
        } footer: {
            if !session.isTimed {
                Text("Set the start and end times to see how long this session took.")
            } else if kcal != nil {
                Text("Estimated from the session's length and your body weight (strength training ≈ \(CalorieEstimator.strengthMET.formatted()) MET).")
            }
        }
        .listRowBackground(Color.ffSurface)

        Section("Details") {
            Picker("Location", selection: location) {
                Text("Not set").tag(0)
                Text("Indoor").tag(1)
                Text("Outdoor").tag(2)
            }
            .pickerStyle(.segmented)
            TextField("Notes", text: Binding(
                get: { session.notes ?? "" },
                set: { session.notes = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(1...5)
            .accessibilityIdentifier("sessionNotes")
        }
        .listRowBackground(Color.ffSurface)

        if savesToHealth {
            Section {
                if session.healthKitWorkoutUUID != nil {
                    Label("Saved to Apple Health", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.ffSuccess)
                } else {
                    Button {
                        Task {
                            isSavingToHealth = true
                            healthSaveFailed = !(await ActivityWriter.saveSessionToHealth(session, weightKg: calorieWeightKg, context: modelContext))
                            isSavingToHealth = false
                        }
                    } label: {
                        Label(isSavingToHealth ? "Saving…" : "Save to Apple Health", systemImage: "heart.fill")
                    }
                    .disabled(!session.isTimed || isSavingToHealth)
                    .accessibilityIdentifier("sessionSaveToHealthButton")
                }
            } footer: {
                if healthSaveFailed {
                    Text("Couldn't save to Apple Health. Check FunFitness's access in the Health app's Sharing settings.")
                } else if session.healthKitWorkoutUUID != nil {
                    Text("Changes made after saving aren't sent to Apple Health.")
                } else if !session.isTimed {
                    Text("Set the start and end times to save this session to Apple Health.")
                } else {
                    Text("Saves a Strength Training workout with its time and estimated calories.")
                }
            }
            .listRowBackground(Color.ffSurface)
        }
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: ActivityLog
    let pref: UnitPreference

    private var valueLabel: String {
        UnitConverter.displayString(activity.value, type: activity.activityType, reps: activity.reps, pref: pref)
    }

    /// The exercise name for a named set (3.1 C3), else the type.
    private var title: String {
        ExerciseLibrary.shared.exercise(id: activity.exerciseID)?.name ?? activity.activityType.displayName
    }

    // "Oct 16, 2026 at 8:11 PM · Trail · ♥ 132 avg" — surface and heart rate only when
    // recorded. (3.1)
    private var subtitle: String {
        var parts = [activity.loggedAt.formatted(date: .abbreviated, time: .shortened)]
        if let surface = activity.surface { parts.append(surface.displayName) }
        if let bpm = activity.avgHeartRate { parts.append("♥ \(Int(bpm.rounded())) avg") }
        return parts.joined(separator: " · ")
    }

    private var accessibilityLabel: String {
        let date = activity.loggedAt.formatted(date: .abbreviated, time: .shortened)
        let surface = activity.surface.map { ", on \($0.displayName.lowercased())" } ?? ""
        let heartRate = activity.avgHeartRate.map { ", average heart rate \(Int($0.rounded())) beats per minute" } ?? ""
        return "\(title), \(valueLabel)\(surface)\(heartRate), logged \(date)"
    }

    var body: some View {
        HStack {
            Text(activity.activityType.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(activity.activityType.ffFill, in: .rect(cornerRadius: FFRadius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: FFRadius.sm, style: .continuous).strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .ffFont(.bodyStrong)
                    .foregroundStyle(Color.ffInk)
                Text(subtitle)
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }

            Spacer()

            Text(valueLabel)
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)
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
    let onSave: (Double, Int?, Date, String?, DistanceSurface?, String?) -> Void

    @State private var inputValue = ""
    @State private var includeReps = false
    @State private var repsCount = 1
    @State private var loggedAt = Date()
    @State private var surface: DistanceSurface?
    @State private var exerciseID: String?
    @State private var showValidationError = false
    @FocusState private var isInputFocused: Bool

    private var kind: ActivityType { activity.activityType }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ffBg
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Type indicator (read-only)
                        HStack {
                            Text(kind.emoji)
                                .font(.title2)
                                .accessibilityHidden(true)
                            Text(kind.displayName)
                                .ffFont(.headline)
                                .foregroundStyle(kind.ffOnFill)
                            Spacer()
                            Text(UnitConverter.displayUnit(for: kind, pref: pref))
                                .ffFont(.body)
                                .foregroundStyle(kind.ffOnFill)
                        }
                        .ffCard(padding: FFSpace.s4, radius: FFRadius.md, fill: kind.ffFill)
                        .padding(.horizontal)

                        // Older generic entries can stay generic, so the exercise is optional here.
                        if SessionGrouping.isGroupable(kind) {
                            ExercisePickerRow(type: kind, exerciseID: $exerciseID)
                                .padding(.horizontal)
                        }

                        // Value field
                        VStack(alignment: .leading, spacing: 8) {
                            Text(UnitConverter.fieldLabel(for: kind, pref: pref))
                                .ffFont(.headline)
                                .foregroundStyle(Color.ffInk)

                            TextField(
                                kind.usesDecimalInput ? "0.0" : "0",
                                text: $inputValue
                            )
                            .keyboardType(kind.usesDecimalInput ? .decimalPad : .numberPad)
                            .ffFont(.numeral)
                            .foregroundStyle(Color.ffInk)
                            .padding()
                            .ffWell()
                            .overlay(
                                RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
                                    .strokeBorder(showValidationError ? Color.ffDanger : Color.clear, lineWidth: FFStroke.card)
                            )
                            .focused($isInputFocused)
                            .accessibilityIdentifier("editActivityValueInput")

                            if showValidationError {
                                Text("Please enter a valid value greater than 0")
                                    .ffFont(.caption)
                                    .foregroundStyle(Color.ffDanger)
                            }
                        }
                        .padding(.horizontal)

                        // Reps (rep-using types only, e.g. weight)
                        if kind.usesReps {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $includeReps.animation()) {
                                    Text("Include rep count")
                                        .ffFont(.headline)
                                        .foregroundStyle(Color.ffInk)
                                }
                                .tint(Color.ffAccent)
                                .padding(.horizontal)

                                if includeReps {
                                    HStack(spacing: 20) {
                                        Button {
                                            if repsCount > 1 { repsCount -= 1 }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color.ffLink)
                                        }
                                        .accessibilityLabel("Decrease reps")

                                        Text("\(repsCount) reps")
                                            .ffFont(.numeral)
                                            .foregroundStyle(Color.ffInk)
                                            .frame(minWidth: 80)

                                        Button {
                                            repsCount += 1
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
                                    .padding(.horizontal)
                                }
                            }
                        }

                        if kind == .distance {
                            // GPS-tracked runs were outdoors, so no treadmill option for them.
                            SurfacePicker(
                                selection: $surface,
                                options: activity.source == .tracked ? DistanceSurface.outdoor : DistanceSurface.allCases
                            )
                            .padding(.horizontal)
                        }

                        // Date picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date & Time")
                                .ffFont(.headline)
                                .foregroundStyle(Color.ffInk)
                            DatePicker(
                                "Activity date",
                                selection: $loggedAt,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color.ffAccent)
                            .accessibilityIdentifier("editActivityDatePicker")
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 0)

                        Button { saveChanges() } label: {
                            Text("Save Changes")
                        }
                        .buttonStyle(.ffPrimary)
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
                        .foregroundStyle(Color.ffLink)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                        .foregroundStyle(Color.ffLink)
                }
            }
            .onAppear {
                // Pre-fill: convert stored SI → display units
                inputValue = UnitConverter.inputString(activity.value, type: kind, pref: pref)
                if let existingReps = activity.reps, existingReps > 1 {
                    includeReps = true
                    repsCount   = existingReps
                }
                loggedAt       = activity.loggedAt
                surface        = activity.surface
                exerciseID     = activity.exerciseID
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
        let siValue = UnitConverter.toSI(rawValue, type: kind, from: pref)
        let reps = (kind.usesReps && includeReps) ? repsCount : nil
        onSave(siValue, reps, loggedAt, activity.notes, surface, exerciseID)
        dismiss()
    }
}

#Preview {
    ActivityHistorySheet(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self], inMemory: true)
}

#Preview("Sessions") {
    let container = try! ModelContainer(
        for: ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self, UserProfile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let vm = AppViewModel()
    let now = Date()
    ActivityWriter.log(type: .distance, value: 4.2, reps: nil, date: now, context: context, viewModel: vm)
    ActivityWriter.logSets(type: .weight, value: 61.2, reps: 10, sets: 3, date: now.addingTimeInterval(-3_600), context: context, viewModel: vm)
    ActivityWriter.log(type: .weight, value: 40, reps: 12, date: now.addingTimeInterval(-90_000), context: context, viewModel: vm)
    ActivityWriter.log(type: .reps, value: 20, reps: nil, date: now.addingTimeInterval(-89_400), context: context, viewModel: vm)
    return ActivityHistorySheet(viewModel: vm)
        .modelContainer(container)
}

#Preview("Session Detail") {
    let container = try! ModelContainer(
        for: ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self, UserProfile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let vm = AppViewModel()
    let profile = UserProfile()
    profile.weightKg = 80
    profile.healthKitWriteBackEnabled = true
    context.insert(profile)
    ActivityWriter.logSets(type: .weight, value: 61.2, reps: 10, sets: 3, date: Date(), context: context, viewModel: vm)
    let session = (try? context.fetch(FetchDescriptor<WorkoutSession>()))?.first
    session?.startedAt = Date().addingTimeInterval(-45 * 60)   // a 45-minute session
    let sessionID = session?.id ?? UUID()
    return NavigationStack {
        SessionDetailView(sessionID: sessionID, viewModel: vm)
    }
    .modelContainer(container)
}
