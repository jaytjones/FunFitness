//
//  ProfileView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
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
    @State private var showingClearAllDataAlert = false
    @State private var showLogSheet = false

    private var profile: UserProfile? { profiles.first }

    private var totalMiles: Double {
        activities.filter { $0.activityType == .distance }.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D1A")
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
                                    .foregroundStyle(.white)
                                Text(profile?.fitnessGoal ?? "Stay Active")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(hex: "#9CA3AF"))
                            }
                        }
                        .padding(.top)

                        // Stats Row
                        HStack(spacing: 16) {
                            StatBox(title: "Workouts", value: "\(activities.count)")
                            StatBox(title: "Miles", value: String(format: "%.1f", totalMiles))
                            StatBox(title: "Badges", value: "\(achievements.count)")
                        }
                        .padding(.horizontal)

                        // Personal Information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Personal Information")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                EditableProfileRow(title: "Name", value: Binding(
                                    get: { profile?.name ?? "" },
                                    set: { profile?.name = $0 }
                                ))

                                Divider().background(Color.white.opacity(0.1))

                                EditableEmailRow(
                                    title: "Email",
                                    value: Binding(
                                        get: { profile?.email ?? "" },
                                        set: { profile?.email = $0 }
                                    )
                                )

                                Divider().background(Color.white.opacity(0.1))

                                EditableProfileRow(
                                    title: "Age",
                                    value: Binding(
                                        get: { profile?.age.map { "\($0)" } ?? "" },
                                        set: { str in profile?.age = str.isEmpty ? nil : Int(str) }
                                    ),
                                    keyboardType: .numberPad
                                )

                                Divider().background(Color.white.opacity(0.1))

                                EditableNumberRow(
                                    title: "Height",
                                    value: Binding(
                                        get: {
                                            if let heightStr = profile?.heightInches,
                                               let height = Double(heightStr.filter(\.isNumber)) {
                                                return height
                                            }
                                            return 0
                                        },
                                        set: { newValue in
                                            profile?.heightInches = newValue > 0 ? String(format: "%.0f", newValue) : nil
                                        }
                                    ),
                                    unit: "in"
                                )

                                Divider().background(Color.white.opacity(0.1))

                                EditableNumberRow(
                                    title: "Weight",
                                    value: Binding(
                                        get: { profile?.weightLbs ?? 0 },
                                        set: { profile?.weightLbs = $0 > 0 ? $0 : nil }
                                    ),
                                    unit: "lbs"
                                )
                            }
                            .background(Color(hex: "#1A1A2E"))
                            .clipShape(.rect(cornerRadius: 20))
                        }

                        // Fitness Goal
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Fitness Goal")
                                .font(.headline)
                                .foregroundStyle(.white)
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

                        // Settings
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Settings")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                SettingsActionRow(
                                    title: "Clear Activity Data",
                                    icon: "trash.fill",
                                    iconColor: Color(hex: "#EA580C"),
                                    action: { showingClearActivityAlert = true }
                                )
                                Divider().background(Color.white.opacity(0.1))
                                SettingsActionRow(
                                    title: "Clear All Data",
                                    icon: "exclamationmark.triangle.fill",
                                    iconColor: Color(hex: "#E11D48"),
                                    action: { showingClearAllDataAlert = true }
                                )
                            }
                            .background(Color(hex: "#1A1A2E"))
                            .clipShape(.rect(cornerRadius: 20))
                        }
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        }
    }

    private func clearActivityData() {
        for activity in activities { modelContext.delete(activity) }
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

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color(hex: "#9CA3AF"))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(hex: "#1A1A2E"))
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
                .foregroundStyle(Color(hex: "#9CA3AF"))
                .frame(width: 80, alignment: .leading)

            if isEditing {
                TextField(placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .keyboardType(keyboardType)
                    .focused($isFocused)
                    .onSubmit { isEditing = false }
            } else {
                Text(value.isEmpty ? placeholder : value)
                    .foregroundStyle(value.isEmpty ? Color(hex: "#9CA3AF") : .white)
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
                    .foregroundStyle(Color(hex: "#9CA3AF"))
                    .frame(width: 80, alignment: .leading)

                if isEditing {
                    TextField("email@example.com", text: $editValue)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .focused($isFocused)
                        .onSubmit { saveValue() }
                } else {
                    if value.isEmpty {
                        Text("Not set")
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                    } else {
                        Text(value)
                            .foregroundStyle(.white)
                    }
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
            value = ""
            isEditing = false
            showValidationError = false
            return
        }
        if isValidEmail(trimmed) {
            value = trimmed
            isEditing = false
            showValidationError = false
        } else {
            showValidationError = true
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let regex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }
}

// MARK: - Editable Number Row (staged-save for Height / Weight)

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
                .foregroundStyle(Color(hex: "#9CA3AF"))
                .frame(width: 80, alignment: .leading)

            if isEditing {
                HStack(spacing: 4) {
                    TextField("0", text: $editValue)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .onSubmit { saveValue() }
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
            } else {
                if value > 0 {
                    Text(String(format: "%.0f %@", value, unit))
                        .foregroundStyle(.white)
                } else {
                    Text("Not set")
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                Spacer()
            }

            Button {
                if isEditing { saveValue() }
                else {
                    editValue = value > 0 ? String(format: "%.0f", value) : ""
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
                    .foregroundStyle(.white)
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
