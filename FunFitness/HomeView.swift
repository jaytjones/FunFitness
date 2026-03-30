//
//  HomeView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [ActivityLog]
    @Query private var achievements: [UnlockedAchievement]
    @Bindable var viewModel: AppViewModel
    
    @State private var showLogSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D1A")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Distance Card
                        StatCard(
                            title: "Distance Tracking",
                            subtitle: "Running & Walking",
                            icon: "🏃",
                            value: viewModel.totalDistance,
                            unit: "mi",
                            progress: viewModel.progressToNextMilestone(type: .distance),
                            nextMilestone: viewModel.remainingToNextMilestone(type: .distance).milestone?.getTitle(for: viewModel.activeTheme) ?? "Complete!",
                            remaining: viewModel.remainingToNextMilestone(type: .distance).remaining,
                            remainingUnit: "mi",
                            gradientColors: [Color(hex: "#2563EB"), Color(hex: "#1E40AF")]
                        )
                        
                        // Weight Card
                        StatCard(
                            title: "Weight Tracking",
                            subtitle: "Strength Training",
                            icon: "💪",
                            value: viewModel.totalWeight,
                            unit: "lbs",
                            progress: viewModel.progressToNextMilestone(type: .weight),
                            nextMilestone: viewModel.remainingToNextMilestone(type: .weight).milestone?.getTitle(for: viewModel.activeTheme) ?? "Complete!",
                            remaining: viewModel.remainingToNextMilestone(type: .weight).remaining,
                            remainingUnit: "lbs",
                            gradientColors: [Color(hex: "#7C3AED"), Color(hex: "#4C1D95")]
                        )
                        
                        // Theme Selector
                        ThemeSelector(selectedTheme: $viewModel.activeTheme)
                        
                        // Achievement Preview
                        AchievementPreview(
                            unlockedCount: achievements.count,
                            theme: viewModel.activeTheme
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("FunFitness")
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
            .sheet(isPresented: $showLogSheet) {
                LogActivitySheet(viewModel: viewModel)
            }
            .onAppear {
                viewModel.calculateTotals(activities: activities)
                viewModel.loadUnlockedAchievements(achievements)
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let value: Double
    let unit: String
    let progress: Double
    let nextMilestone: String
    let remaining: Double
    let remainingUnit: String
    let gradientColors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(icon)
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                Spacer()
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.title3)
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.easeInOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 8)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Milestone")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    Text(nextMilestone)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                Text(String(format: "%.1f %@ to go", remaining, remainingUnit))
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }
}

// MARK: - Theme Selector
struct ThemeSelector: View {
    @Binding var selectedTheme: Theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievement Theme")
                .font(.headline)
                .foregroundStyle(.white)
            
            HStack(spacing: 12) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    ThemeChip(
                        theme: theme,
                        isSelected: selectedTheme == theme,
                        action: { selectedTheme = theme }
                    )
                }
            }
        }
        .padding()
        .background(Color(hex: "#1A1A2E"))
        .cornerRadius(20)
    }
}

struct ThemeChip: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(theme.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Color(hex: "#9CA3AF"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color(hex: "#D946EF") : Color.white.opacity(0.1)
                )
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Achievement Preview
struct AchievementPreview: View {
    let unlockedCount: Int
    let theme: Theme
    
    var body: some View {
        VStack(spacing: 16) {
            if unlockedCount == 0 {
                VStack(spacing: 12) {
                    Text("🎯")
                        .font(.system(size: 48))
                    Text("Log your first activity to unlock achievements!")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 8) {
                        ForEach(["🏃", "💪", "🎯", "⚡️", "🔥", "🏆"], id: \.self) { emoji in
                            Text(emoji)
                                .font(.title2)
                                .opacity(0.3)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "#1A1A2E"))
                .cornerRadius(20)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Achievements")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(unlockedCount) of 12 unlocked")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(hex: "#1A1A2E"))
                .cornerRadius(20)
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    HomeView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
