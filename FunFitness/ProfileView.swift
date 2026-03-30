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
    @State private var showingSignOutAlert = false
    @State private var showLogSheet = false
    
    private var profile: UserProfile? {
        profiles.first
    }
    
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
                                    if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self) {
                                        profile?.avatarImageData = data
                                    }
                                }
                            }
                            
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
                        
                        // Personal Info Section
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
                                
                                EditableProfileRow(title: "Email", value: Binding(
                                    get: { profile?.email ?? "" },
                                    set: { profile?.email = $0 }
                                ))
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                EditableProfileRow(title: "Age", value: Binding(
                                    get: { profile?.age != nil ? "\(profile!.age!)" : "" },
                                    set: { profile?.age = Int($0) }
                                ))
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                EditableProfileRow(title: "Height", value: Binding(
                                    get: { profile?.heightFeet ?? "" },
                                    set: { profile?.heightFeet = $0 }
                                ))
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                EditableProfileRow(title: "Weight", value: Binding(
                                    get: { profile?.weightLbs != nil ? String(format: "%.0f lbs", profile!.weightLbs!) : "" },
                                    set: { profile?.weightLbs = Double($0.replacingOccurrences(of: " lbs", with: "")) }
                                ))
                            }
                            .background(Color(hex: "#1A1A2E"))
                            .cornerRadius(20)
                        }
                        
                        // Fitness Goal Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Fitness Goal")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(["Build Endurance", "Lose Weight", "Build Muscle", "Stay Active", "Train for Race"], id: \.self) { goal in
                                    GoalChip(
                                        title: goal,
                                        isSelected: profile?.fitnessGoal == goal,
                                        action: { profile?.fitnessGoal = goal }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Settings Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Settings")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                SettingsRow(title: "Notifications", icon: "bell.fill")
                                Divider().background(Color.white.opacity(0.1))
                                SettingsRow(title: "Privacy & Security", icon: "lock.fill")
                            }
                            .background(Color(hex: "#1A1A2E"))
                            .cornerRadius(20)
                        }
                        
                        // Sign Out Button
                        Button {
                            showingSignOutAlert = true
                        } label: {
                            Text("Sign Out")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#E11D48"))
                                .cornerRadius(14)
                        }
                        .padding(.horizontal)
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
                            .foregroundStyle(Color(hex: "#5B21B6"))
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    // In V1, we just keep the data and could reset to onboarding
                    // For now, we'll just dismiss the alert
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showLogSheet) {
                LogActivitySheet(viewModel: viewModel)
            }
        }
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
        .cornerRadius(12)
    }
}

// MARK: - Editable Profile Row
struct EditableProfileRow: View {
    let title: String
    @Binding var value: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color(hex: "#9CA3AF"))
                .frame(width: 80, alignment: .leading)
            
            if isEditing {
                TextField(title, text: $value)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isFocused)
                    .onSubmit {
                        isEditing = false
                    }
            } else {
                Text(value.isEmpty ? "Not set" : value)
                    .foregroundStyle(value.isEmpty ? Color(hex: "#9CA3AF").opacity(0.5) : .white)
                Spacer()
            }
            
            Button {
                isEditing.toggle()
                if isEditing {
                    isFocused = true
                }
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                    .foregroundStyle(Color(hex: "#5B21B6"))
            }
        }
        .padding()
    }
}

// MARK: - Goal Chip
struct GoalChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Color(hex: "#9CA3AF"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "#5B21B6") : Color(hex: "#1A1A2E"))
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let title: String
    let icon: String
    
    var body: some View {
        Button {
            // V2: Navigate to settings screens
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color(hex: "#5B21B6"))
                    .frame(width: 24)
                
                Text(title)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    ProfileView(viewModel: AppViewModel())
        .modelContainer(for: [UserProfile.self, ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
