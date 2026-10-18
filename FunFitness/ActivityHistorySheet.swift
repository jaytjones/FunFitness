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

    private var autoGroupedSessionIDs: Set<UUID> {
        Set(sessions.filter(\.isAutoGrouped).map(\.id))
    }

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
                        // Sets from one workout show as a single session row (3.1 C1).
                        List {
                            ForEach(HistoryItem.items(from: activities)) { item in
                                switch item {
                                case .single(let activity):
                                    activityRow(activity)
                                case .session(let id, let logs):
                                    NavigationLink(value: SessionRoute(id: id)) {
                                        SessionRow(logs: logs, isAutoGrouped: autoGroupedSessionIDs.contains(id), pref: viewModel.unitPreference)
                                    }
                                    .listRowBackground(Color.appCard)
                                    .listRowSeparatorTint(Color.primary.opacity(0.1))
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
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
            .sheet(item: $editingActivity) { activity in
                EditActivitySheet(
                    activity: activity,
                    pref: viewModel.unitPreference
                ) { value, reps, loggedAt, notes, surface in
                    commitEdit(activity: activity, value: value, reps: reps, loggedAt: loggedAt, notes: notes, surface: surface)
                }
            }
        }
    }

    private func activityRow(_ activity: ActivityLog) -> some View {
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

    private func deleteActivity(_ activity: ActivityLog) {
        ActivityWriter.delete(activity, context: modelContext, viewModel: viewModel)
    }

    private func commitEdit(activity: ActivityLog, value: Double, reps: Int?, loggedAt: Date, notes: String?, surface: DistanceSurface?) {
        Self.applyEdit(
            to: activity, value: value, reps: reps, loggedAt: loggedAt, notes: notes, surface: surface,
            achievements: achievements, context: modelContext, viewModel: viewModel
        )
    }

    /// Saves an edit from `EditActivitySheet`. Shared with the session detail screen.
    static func applyEdit(
        to activity: ActivityLog, value: Double, reps: Int?, loggedAt: Date, notes: String?, surface: DistanceSurface?,
        achievements: [UnlockedAchievement], context: ModelContext, viewModel: AppViewModel
    ) {
        activity.value    = value
        activity.reps     = reps
        activity.loggedAt = loggedAt
        activity.notes    = notes
        activity.surface  = activity.activityType == .distance ? surface : nil
        try? context.save()
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

/// "🏋️ Strength · 5 sets" over the date, with the session total on the right. (3.1 C1)
struct SessionRow: View {
    let logs: [ActivityLog]
    let isAutoGrouped: Bool
    let pref: UnitPreference

    var body: some View {
        if let summary = SessionSummary(logs: logs) {
            HStack {
                Text(WorkoutSessionKind.strength.emoji)
                    .font(.title2)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(WorkoutSessionKind.strength.displayName) · \(summary.setsText)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle(summary))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(summary.totalText(pref: pref))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Strength session, \(summary.setsText), \(summary.totalText(pref: pref)), \(subtitle(summary))")
        }
    }

    // "Oct 16, 2026 at 8:11 PM · Auto-grouped"
    private func subtitle(_ summary: SessionSummary) -> String {
        let date = summary.startedAt.formatted(date: .abbreviated, time: .shortened)
        return isAutoGrouped ? "\(date) · Auto-grouped" : date
    }
}

// MARK: - Session Detail

/// One session's sets, with Ungroup and Delete Session. Each set can be edited, deleted, or taken
/// out of the session. (3.1 C1)
struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var logs: [ActivityLog]
    @Query private var records: [WorkoutSession]
    @Query private var achievements: [UnlockedAchievement]
    @Bindable var viewModel: AppViewModel

    let sessionID: UUID
    @State private var editingActivity: ActivityLog? = nil
    @State private var showDeleteConfirm = false
    @State private var showUngroupConfirm = false

    init(sessionID: UUID, viewModel: AppViewModel) {
        self.sessionID = sessionID
        self.viewModel = viewModel
        let id: UUID? = sessionID
        _logs = Query(filter: #Predicate<ActivityLog> { $0.sessionID == id }, sort: \.loggedAt)
        _records = Query(filter: #Predicate<WorkoutSession> { $0.id == sessionID })
    }

    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            List {
                if let summary = SessionSummary(logs: logs) {
                    Section {
                        LabeledContent("Sets", value: "\(summary.setCount)")
                        LabeledContent("Total", value: summary.totalText(pref: pref))
                        LabeledContent("Time", value: timeRange(summary))
                    }
                    .listRowBackground(Color.appCard)
                }

                Section("Sets") {
                    ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 20)
                                .accessibilityLabel("Set \(index + 1)")
                            ActivityRow(activity: log, pref: pref)
                        }
                        .listRowBackground(Color.appCard)
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
                            .tint(.orange)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingActivity = log
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color(hex: "#5B21B6"))
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
        .sheet(item: $editingActivity) { activity in
            EditActivitySheet(activity: activity, pref: pref) { value, reps, loggedAt, notes, surface in
                ActivityHistorySheet.applyEdit(
                    to: activity, value: value, reps: reps, loggedAt: loggedAt, notes: notes, surface: surface,
                    achievements: achievements, context: modelContext, viewModel: viewModel
                )
            }
        }
        .onChange(of: logs.isEmpty) {
            // Last set deleted or removed: the session is gone.
            if logs.isEmpty { dismiss() }
        }
    }

    // "8:11 – 8:42 PM"
    private func timeRange(_ summary: SessionSummary) -> String {
        let start = records.first?.startedAt ?? summary.startedAt
        let end = max(records.first?.endedAt ?? summary.endedAt, summary.endedAt)
        return (start..<max(end, start.addingTimeInterval(1))).formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: ActivityLog
    let pref: UnitPreference

    private var valueLabel: String {
        UnitConverter.displayString(activity.value, type: activity.activityType, reps: activity.reps, pref: pref)
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
        return "\(activity.activityType.displayName), \(valueLabel)\(surface)\(heartRate), logged \(date)"
    }

    var body: some View {
        HStack {
            Text(activity.activityType.emoji)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.activityType.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
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
    let onSave: (Double, Int?, Date, String?, DistanceSurface?) -> Void

    @State private var inputValue = ""
    @State private var includeReps = false
    @State private var repsCount = 1
    @State private var loggedAt = Date()
    @State private var surface: DistanceSurface?
    @State private var showValidationError = false
    @FocusState private var isInputFocused: Bool

    private var kind: ActivityType { activity.activityType }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Type indicator (read-only)
                        HStack {
                            Text(kind.emoji)
                                .font(.title2)
                                .accessibilityHidden(true)
                            Text(kind.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(UnitConverter.displayUnit(for: kind, pref: pref))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.appCard)
                        .clipShape(.rect(cornerRadius: 14))
                        .padding(.horizontal)

                        // Value field
                        VStack(alignment: .leading, spacing: 8) {
                            Text(UnitConverter.fieldLabel(for: kind, pref: pref))
                                .font(.headline)
                                .foregroundStyle(.primary)

                            TextField(
                                kind.usesDecimalInput ? "0.0" : "0",
                                text: $inputValue
                            )
                            .keyboardType(kind.usesDecimalInput ? .decimalPad : .numberPad)
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

                        // Reps (rep-using types only, e.g. weight)
                        if kind.usesReps {
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
                inputValue = UnitConverter.inputString(activity.value, type: kind, pref: pref)
                if let existingReps = activity.reps, existingReps > 1 {
                    includeReps = true
                    repsCount   = existingReps
                }
                loggedAt       = activity.loggedAt
                surface        = activity.surface
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
        onSave(siValue, reps, loggedAt, activity.notes, surface)
        dismiss()
    }
}

#Preview {
    ActivityHistorySheet(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self], inMemory: true)
}

#Preview("Sessions") {
    let container = try! ModelContainer(
        for: ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self,
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
        for: ActivityLog.self, UnlockedAchievement.self, WorkoutSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let vm = AppViewModel()
    ActivityWriter.logSets(type: .weight, value: 61.2, reps: 10, sets: 3, date: Date(), context: context, viewModel: vm)
    let sessionID = (try? context.fetch(FetchDescriptor<WorkoutSession>()))?.first?.id ?? UUID()
    return NavigationStack {
        SessionDetailView(sessionID: sessionID, viewModel: vm)
    }
    .modelContainer(container)
}
