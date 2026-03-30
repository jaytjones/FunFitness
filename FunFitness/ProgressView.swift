//
//  ProgressView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

struct ProgressView: View {
    @Query private var activities: [ActivityLog]
    @Bindable var viewModel: AppViewModel
    
    @State private var showLogSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D1A")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Overall Progress Card
                        OverallProgressCard(
                            totalActivities: viewModel.totalActivities,
                            isActiveThisWeek: viewModel.isActiveThisWeek
                        )
                        
                        // Distance Tracking Card
                        TrackingCard(
                            title: "Distance Tracking",
                            subtitle: "Running & Walking",
                            icon: "🏃",
                            currentValue: viewModel.totalDistance,
                            unit: "mi",
                            progress: viewModel.progressToNextMilestone(type: .distance),
                            nextMilestone: viewModel.remainingToNextMilestone(type: .distance).milestone?.getTitle(for: viewModel.activeTheme) ?? "All Complete!",
                            remaining: viewModel.remainingToNextMilestone(type: .distance).remaining,
                            remainingUnit: "mi"
                        )
                        
                        // Weight Tracking Card
                        TrackingCard(
                            title: "Weight Tracking",
                            subtitle: "Strength Training",
                            icon: "💪",
                            currentValue: viewModel.totalWeight,
                            unit: "lbs",
                            progress: viewModel.progressToNextMilestone(type: .weight),
                            nextMilestone: viewModel.remainingToNextMilestone(type: .weight).milestone?.getTitle(for: viewModel.activeTheme) ?? "All Complete!",
                            remaining: viewModel.remainingToNextMilestone(type: .weight).remaining,
                            remainingUnit: "lbs"
                        )
                        
                        // Motivational Card
                        MotivationalCard()
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress")
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

// MARK: - Overall Progress Card
struct OverallProgressCard: View {
    let totalActivities: Int
    let isActiveThisWeek: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Overall Progress")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            HStack(spacing: 16) {
                // Total Activities
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Activities")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    Text("\(totalActivities)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                // This Week Status
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isActiveThisWeek ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(isActiveThisWeek ? "Active" : "Inactive")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(hex: "#7C3AED"), Color(hex: "#4C1D95")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }
}

// MARK: - Tracking Card
struct TrackingCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let currentValue: Double
    let unit: String
    let progress: Double
    let nextMilestone: String
    let remaining: Double
    let remainingUnit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(icon)
                    .font(.title2)
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
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Current Total
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("Total:")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#9CA3AF"))
                Text(String(format: "%.1f", currentValue))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#5B21B6"))
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
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(String(format: "%.1f %@ to go", remaining, remainingUnit))
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
            }
        }
        .padding()
        .background(Color(hex: "#1A1A2E"))
        .cornerRadius(20)
    }
}

// MARK: - Motivational Card
struct MotivationalCard: View {
    let messages = [
        "Keep Going! Every step and rep counts.",
        "You're doing amazing! Stay consistent.",
        "Progress, not perfection. Keep it up!",
        "Your future self will thank you.",
        "One workout at a time. You've got this!"
    ]
    
    var body: some View {
        HStack(spacing: 16) {
            Text("💪")
                .font(.system(size: 40))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(messages.randomElement() ?? messages[0])
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(hex: "#059669"))
        .cornerRadius(20)
    }
}

#Preview {
    ProgressView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self], inMemory: true)
}
