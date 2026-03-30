//
//  AchievementsView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query private var achievements: [UnlockedAchievement]
    @Bindable var viewModel: AppViewModel
    
    @State private var showLogSheet = false
    
    private var unlockedMilestones: [Milestone] {
        achievements.compactMap { achievement in
            ComparisonEngine.milestone(withId: achievement.milestoneId)
        }.sorted { m1, m2 in
            let a1 = achievements.first { $0.milestoneId == m1.id }
            let a2 = achievements.first { $0.milestoneId == m2.id }
            return (a1?.unlockedAt ?? Date()) > (a2?.unlockedAt ?? Date())
        }
    }
    
    private var lockedMilestones: [Milestone] {
        ComparisonEngine.allMilestones.filter { milestone in
            !achievements.contains { $0.milestoneId == milestone.id }
        }
    }
    
    private var completionPercentage: Int {
        let total = ComparisonEngine.allMilestones.count
        let unlocked = achievements.count
        return total > 0 ? Int((Double(unlocked) / Double(total)) * 100) : 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D1A")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Progress Banner
                        ProgressBanner(
                            unlockedCount: achievements.count,
                            totalCount: ComparisonEngine.allMilestones.count,
                            percentage: completionPercentage
                        )
                        
                        if achievements.isEmpty {
                            // Empty State
                            EmptyAchievementsState()
                        } else {
                            // Unlocked Achievements
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Unlocked")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal)
                                
                                ForEach(unlockedMilestones) { milestone in
                                    if let achievement = achievements.first(where: { $0.milestoneId == milestone.id }) {
                                        AchievementCard(
                                            milestone: milestone,
                                            theme: viewModel.activeTheme,
                                            unlockedAt: achievement.unlockedAt,
                                            isLocked: false
                                        )
                                    }
                                }
                            }
                            
                            // Locked Achievements
                            if !lockedMilestones.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Locked")
                                        .font(.headline)
                                        .foregroundStyle(Color(hex: "#9CA3AF"))
                                        .padding(.horizontal)
                                    
                                    ForEach(lockedMilestones) { milestone in
                                        AchievementCard(
                                            milestone: milestone,
                                            theme: viewModel.activeTheme,
                                            unlockedAt: nil,
                                            isLocked: true
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        }
    }
}

// MARK: - Progress Banner
struct ProgressBanner: View {
    let unlockedCount: Int
    let totalCount: Int
    let percentage: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🏆")
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Progress")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(unlockedCount) of \(totalCount) unlocked")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                Spacer()
                Text("\(percentage)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white)
                        .frame(width: geometry.size.width * (Double(percentage) / 100.0), height: 8)
                        .animation(.easeInOut(duration: 0.6), value: percentage)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(hex: "#EA580C"), Color(hex: "#C2410C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }
}

// MARK: - Empty State
struct EmptyAchievementsState: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("🔒")
                .font(.system(size: 60))
                .padding(.top, 40)
            
            Text("No Achievements Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("Start logging your activities to unlock fun achievements and comparisons!")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "#9CA3AF"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            HStack(spacing: 12) {
                ForEach(["🏃", "💪", "🎯", "⚡️", "🔥", "🏆"], id: \.self) { emoji in
                    Text(emoji)
                        .font(.title)
                        .opacity(0.3)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(hex: "#1A1A2E"))
        .cornerRadius(20)
    }
}

// MARK: - Achievement Card
struct AchievementCard: View {
    let milestone: Milestone
    let theme: Theme
    let unlockedAt: Date?
    let isLocked: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Text(milestone.getEmoji(for: theme))
                .font(.system(size: 40))
                .opacity(isLocked ? 0.3 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.getTitle(for: theme))
                    .font(.headline)
                    .foregroundStyle(isLocked ? Color(hex: "#9CA3AF") : .white)
                
                if !isLocked {
                    Text(milestone.getComparison(for: theme))
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                        .lineLimit(2)
                    
                    if let date = unlockedAt {
                        Text("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#5B21B6"))
                    }
                } else {
                    Text("Reach \(String(format: "%.1f", milestone.threshold)) \(milestone.unit == .miles ? "miles" : "lbs") to unlock")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
            }
            
            Spacer()
            
            if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color(hex: "#9CA3AF"))
                    .opacity(0.5)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "#059669"))
            }
        }
        .padding()
        .background(Color(hex: "#1A1A2E"))
        .cornerRadius(20)
        .opacity(isLocked ? 0.6 : 1.0)
    }
}

#Preview {
    AchievementsView(viewModel: AppViewModel())
        .modelContainer(for: [UnlockedAchievement.self], inMemory: true)
}
