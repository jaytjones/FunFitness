//
//  ProfileView.swift
//  FunFitness
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var activities: [ActivityLog]
    @Query private var achievements: [UnlockedAchievement]

    @Bindable var viewModel: AppViewModel

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingClearActivityAlert = false
    @State private var showingClearAllDataAlert  = false
    @State private var showLogSheet  = false
    @State private var showExportSheet = false
    @State private var exportURL: URL? = nil

    private var profile: UserProfile? { profiles.first }
    private var pref: UnitPreference   { profile?.unitPref ?? .imperial }

    private var totalDistanceKm: Double {
        activities.filter { $0.activityType == .distance }.reduce(0) { $0 + $1.value }
    }

    // Profile completeness: fraction of optional fields filled in
    private var profileCompleteness: Double {
        guard let profile else { return 0 }
        let checks: [Bool] = [
            !profile.name.isEmpty,
            !profile.email.isEmpty,
            profile.dateOfBirth != nil,
            (profile.heightCm ?? 0) > 0,
            (profile.weightKg ?? 0) > 0
        ]
        let filled = checks.filter { $0 }.count
        return Double(filled) / Double(checks.count)
    }

    private var profileCompletenessLabel: String {
        let pct = Int(profileCompleteness * 100)
        switch pct {
        case 100: return "Complete"
        case 80...: return "\(pct)% — almost there!"
        case 60...: return "\(pct)% complete"
        default:    return "\(pct)% — add more details"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Avatar and Name
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let imageData = profile?.avatarImageData,
                                       let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: "#5B21B6"))
                                                .frame(width: 80, height: 80)
                                            Text(profile?.name.prefix(2).uppercased() ?? "FF")
                                                .font(.title)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    Image(systemName: "camera.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white, Color(hex: "#5B21B6"))
                                        .offset(x: 4, y: 4)
                                }
                            }
                            .onChange(of: selectedPhotoItem) {
                                Task {
                                    if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data),
                                       let downscaled = uiImage.downscaled(to: 256),
                                       let compressed = downscaled.jpegData(compressionQuality: 0.85) {
                                        profile?.avatarImageData = compressed
                                    }
                                }
                            }
                            .accessibilityLabel("Profile photo — tap to change")

                            VStack(spacing: 4) {
                                Text(profile?.name ?? "User")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                Text(profile?.fitnessGoal ?? "Stay Active")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            // Profile completeness meter
                            if profileCompleteness < 1.0 {
                                VStack(spacing: 6) {
                                    SwiftUI.ProgressView(value: profileCompleteness)
                                        .progressViewStyle(FitnessProgressStyle(tint: Color(hex: "#A78BFA")))
                                        .accessibilityLabel("Profile completeness")
                                        .accessibilityValue(profileCompletenessLabel)
                                    Text(profileCompletenessLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 32)
                            }
                        }
                        .padding(.top)

                        // Stats Row
                        HStack(spacing: 16) {
                            StatBox(title: "Workouts", value: "\(activities.count)")
                            StatBox(
                                title: "Distance",
                                value: UnitConverter.distanceString(totalDistanceKm, pref: pref)
                            )
                            StatBox(title: "Badges", value: "\(achievements.count)")
                        }
                        .padding(.horizontal)

                        // Personal Information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Personal Information")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                EditableProfileRow(title: "Name", value: Binding(
                                    get: { profile?.name ?? "" },
                                    set: { profile?.name = $0 }
                                ))

                                Divider()

                                EditableEmailRow(
                                    title: "Email",
                                    value: Binding(
                                        get: { profile?.email ?? "" },
                                        set: { profile?.email = $0 }
                                    )
                                )

                                Divider()

                                DateOfBirthRow(
                                    dateOfBirth: Binding(
                                        get: { profile?.dateOfBirth },
                                        set: { profile?.dateOfBirth = $0 }
                                    )
                                )

                                Divider()

                                EditableNumberRow(
                                    title: "Height",
                                    value: Binding(
                                        get: {
                                            if let cm = profile?.heightCm, cm > 0 {
                                                return pref == .imperial ? cm / 2.54 : cm
                                            }
                                            return 0
                                        },
                                        set: { newValue in
                                            guard newValue > 0 else { profile?.heightCm = nil; return }
                                            profile?.heightCm = pref == .imperial ? newValue * 2.54 : newValue
                                        }
                                    ),
                                    unit: pref == .imperial ? "in" : "cm"
                                )

                                Divider()

                                EditableNumberRow(
                                    title: "Weight",
                                    value: Binding(
                                        get: {
                                            if let kg = profile?.weightKg, kg > 0 {
                                                return UnitConverter.fromKg(kg, to: pref)
                                            }
                                            return 0
                                        },
                                        set: { newValue in
                                            guard newValue > 0 else { profile?.weightKg = nil; return }
                                            profile?.weightKg = UnitConverter.toKg(newValue, from: pref)
                                        }
                                    ),
                                    unit: pref.weightUnit
                                )
                            }
                            .background(Color.appCard)
                            .clipShape(.rect(cornerRadius: 20))
                        }

                        // Units
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Units")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal)

                            FlowLayout(spacing: 8) {
                                ForEach(UnitPreference.allCases, id: \.self) { option in
                                    SelectionChip(
                                        title: option.displayName,
                                        isSelected: pref == option,
                                        action: {
                                            profile?.unitPreference = option.rawValue
                                            viewModel.unitPreference = option
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Fitness Goal
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Fitness Goal")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal)

                            FlowLayout(spacing: 8) {
                                ForEach(["Build Endurance", "Lose Weight", "Build Muscle", "Stay Active", "Train for Race"], id: \.self) { goal in
                                    SelectionChip(
                                        title: goal,
                                        isSelected: profile?.fitnessGoal == goal,
                                        action: { profile?.fitnessGoal = goal }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Weekly Goals
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Weekly Goals")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                EditableNumberRow(
                                    title: "Distance",
                                    value: Binding(
                                        get: {
                                            if let km = profile?.weeklyDistanceGoal, km > 0 {
                                                return UnitConverter.fromKm(km, to: pref)
                                            }
                                            return 0
                                        },
                                        set: { newValue in
                                            guard newValue > 0 else { profile?.weeklyDistanceGoal = nil; return }
                                            profile?.weeklyDistanceGoal = UnitConverter.toKm(newValue, from: pref)
                                        }
                                    ),
                                    unit: "\(pref.distanceUnit)/wk"
                                )

                                Divider()

                                EditableNumberRow(
                                    title: "Weight",
                                    value: Binding(
                                        get: {
                                            if let kg = profile?.weeklyWeightGoal, kg > 0 {
                                                return UnitConverter.fromKg(kg, to: pref)
                                            }
                                            return 0
                                        },
                                        set: { newValue in
                                            guard newValue > 0 else { profile?.weeklyWeightGoal = nil; return }
                                            profile?.weeklyWeightGoal = UnitConverter.toKg(newValue, from: pref)
                                        }
                                    ),
                                    unit: "\(pref.weightUnit)/wk"
                                )
                            }
                            .background(Color.appCard)
                            .clipShape(.rect(cornerRadius: 20))
                        }

                        // Notifications
                        NotificationSettingsSection(profile: profile)

                        // Settings
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Settings")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                SettingsActionRow(
                                    title: "Export Data (CSV)",
                                    icon: "square.and.arrow.up",
                                    iconColor: Color(hex: "#0284C7"),
                                    action: { prepareAndShowExport() }
                                )
                                Divider()
                                SettingsActionRow(
                                    title: "Clear Activity Data",
                                    icon: "trash.fill",
                                    iconColor: Color(hex: "#EA580C"),
                                    action: { showingClearActivityAlert = true }
                                )
                                Divider()
                                SettingsActionRow(
                                    title: "Clear All Data",
                                    icon: "exclamationmark.triangle.fill",
                                    iconColor: Color(hex: "#E11D48"),
                                    action: { showingClearAllDataAlert = true }
                                )
                            }
                            .background(Color.appCard)
                            .clipShape(.rect(cornerRadius: 20))
                        }
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLogSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(hex: "#A78BFA"))
                    }
                    .accessibilityLabel("Log activity")
                }
            }
            .alert("Clear Activity Data", isPresented: $showingClearActivityAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) { clearActivityData() }
            } message: {
                Text("This will delete all your logged activities and achievements. Your profile information will be kept. This action cannot be undone.")
            }
            .alert("Clear All Data", isPresented: $showingClearAllDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Everything", role: .destructive) { clearAllData() }
            } message: {
                Text("This will delete your profile, all activities, and all achievements. You'll need to set up your account again. This action cannot be undone.")
            }
            .sheet(isPresented: $showLogSheet) {
                LogActivitySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showExportSheet, onDismiss: { exportURL = nil }) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func prepareAndShowExport() {
        exportURL = ExportManager.csvFileURL(activities: activities, pref: pref)
        if exportURL != nil { showExportSheet = true }
    }

    private func clearActivityData() {
        for activity in activities   { modelContext.delete(activity)    }
        for achievement in achievements { modelContext.delete(achievement) }
        viewModel.activities = []
        viewModel.unlockedAchievementIds.removeAll()
        try? modelContext.save()
    }

    private func clearAllData() {
        clearActivityData()
        if let profile { modelContext.delete(profile) }
        try? modelContext.save()
    }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Date of Birth Row

struct DateOfBirthRow: View {
    @Binding var dateOfBirth: Date?
    @State private var isEditing = false

    private var displayText: String {
        if let dob = dateOfBirth {
            let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
            return "\(dob.formatted(date: .abbreviated, time: .omitted)) (age \(age))"
        }
        return "Not set"
    }

    var body: some View {
        HStack {
            Text("Birthday")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            if isEditing {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date() },
                        set: { dateOfBirth = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color(hex: "#A78BFA"))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(displayText)
                    .foregroundStyle(dateOfBirth == nil ? .secondary : .primary)
                Spacer()
            }

            Button {
                isEditing.toggle()
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                    .foregroundStyle(Color(hex: "#A78BFA"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(isEditing ? "Save birthday" : "Edit birthday")
        }
        .padding()
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appCard)
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Editable Profile Row (live-save, text keyboard)

struct EditableProfileRow: View {
    let title: String
    @Binding var value: String
    var placeholder: String = "Not set"
    var keyboardType: UIKeyboardType = .default
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            if isEditing {
                TextField(placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary)
                    .keyboardType(keyboardType)
                    .focused($isFocused)
                    .onSubmit { isEditing = false }
            } else {
                Text(value.isEmpty ? placeholder : value)
                    .foregroundStyle(value.isEmpty ? .secondary : .primary)
                Spacer()
            }

            Button {
                isEditing.toggle()
                if isEditing { isFocused = true }
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                    .foregroundStyle(Color(hex: "#A78BFA"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(isEditing ? "Save \(title)" : "Edit \(title)")
        }
        .padding()
    }
}

// MARK: - Editable Email Row (staged-save with validation)

struct EditableEmailRow: View {
    let title: String
    @Binding var value: String
    @State private var isEditing = false
    @State private var editValue: String = ""
    @State private var showValidationError = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)

                if isEditing {
                    TextField("email@example.com", text: $editValue)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.primary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .focused($isFocused)
                        .onSubmit { saveValue() }
                } else {
                    Text(value.isEmpty ? "Not set" : value)
                        .foregroundStyle(value.isEmpty ? .secondary : .primary)
                    Spacer()
                }

                Button {
                    if isEditing { saveValue() }
                    else {
                        editValue = value
                        isEditing = true
                        showValidationError = false
                        isFocused = true
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .foregroundStyle(Color(hex: "#A78BFA"))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(isEditing ? "Save \(title)" : "Edit \(title)")
            }
            .padding()

            if showValidationError {
                Text("Please enter a valid email address (e.g., name@example.com)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    private func saveValue() {
        let trimmed = editValue.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty {
            value = ""; isEditing = false; showValidationError = false; return
        }
        if isValidEmail(trimmed) {
            value = trimmed; isEditing = false; showValidationError = false
        } else {
            showValidationError = true
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let regex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }
}

// MARK: - Editable Number Row (staged-save; unit label provided by caller)

struct EditableNumberRow: View {
    let title: String
    @Binding var value: Double
    let unit: String
    @State private var isEditing = false
    @State private var editValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            if isEditing {
                HStack(spacing: 4) {
                    TextField("0", text: $editValue)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.primary)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .onSubmit { saveValue() }
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                if value > 0 {
                    Text(String(format: "%.1f %@", value, unit))
                        .foregroundStyle(.primary)
                } else {
                    Text("Not set")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                if isEditing { saveValue() }
                else {
                    editValue = value > 0 ? String(format: "%.1f", value) : ""
                    isEditing = true
                    isFocused = true
                }
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                    .foregroundStyle(Color(hex: "#A78BFA"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(isEditing ? "Save \(title)" : "Edit \(title)")
        }
        .padding()
    }

    private func saveValue() {
        if let newValue = Double(editValue), newValue > 0 { value = newValue }
        isEditing = false
    }
}

// MARK: - Notification Settings Section

struct NotificationSettingsSection: View {
    let profile: UserProfile?

    @State private var isAuthorized = false
    @State private var showPermissionPrompt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                if !isAuthorized {
                    Button {
                        Task {
                            let granted = await NotificationManager.shared.requestPermission()
                            isAuthorized = granted
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(Color(hex: "#A78BFA"))
                                .frame(width: 24)
                            Text("Enable Notifications")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding()
                    }
                    .buttonStyle(.plain)
                } else {
                    NotificationToggleRow(
                        title: "Streak At Risk",
                        subtitle: "Thursday nudge if you haven't logged yet",
                        icon: "flame.fill",
                        iconColor: Color(hex: "#EA580C"),
                        isOn: Binding(
                            get: { profile?.notifyStreakAtRisk ?? false },
                            set: { profile?.notifyStreakAtRisk = $0 }
                        )
                    )
                    Divider()
                    NotificationToggleRow(
                        title: "Milestone Nudge",
                        subtitle: "Alert when you're close to your next badge",
                        icon: "trophy.fill",
                        iconColor: Color(hex: "#D97706"),
                        isOn: Binding(
                            get: { profile?.notifyMilestoneNudge ?? false },
                            set: { profile?.notifyMilestoneNudge = $0 }
                        )
                    )
                    Divider()
                    NotificationToggleRow(
                        title: "Weekly Recap",
                        subtitle: "Sunday summary of your week",
                        icon: "calendar.badge.checkmark",
                        iconColor: Color(hex: "#0284C7"),
                        isOn: Binding(
                            get: { profile?.notifyWeeklyRecap ?? false },
                            set: { profile?.notifyWeeklyRecap = $0 }
                        )
                    )
                    Divider()
                    NotificationToggleRow(
                        title: "Comparison of the Day",
                        subtitle: "Daily motivational fact (may be funny)",
                        icon: "lightbulb.fill",
                        iconColor: Color(hex: "#7C3AED"),
                        isOn: Binding(
                            get: { profile?.notifyComparisonOfDay ?? false },
                            set: { profile?.notifyComparisonOfDay = $0 }
                        )
                    )
                }
            }
            .background(Color.appCard)
            .clipShape(.rect(cornerRadius: 20))
        }
        .task {
            isAuthorized = await NotificationManager.shared.isAuthorized()
        }
    }
}

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(hex: "#A78BFA"))
        }
        .padding()
    }
}

// MARK: - Settings Action Row

struct SettingsActionRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UIImage downscaling helper

private extension UIImage {
    func downscaled(to maxDimension: CGFloat) -> UIImage? {
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

#Preview {
    ProfileView(viewModel: AppViewModel())
        .modelContainer(for: [UserProfile.self, ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
