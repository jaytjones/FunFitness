//
//  ProgressView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

// Renamed from ProgressView to avoid shadowing SwiftUI.ProgressView (which enables
// accessible ProgressView(value:) usage and removes the GeometryReader workaround)
struct ProgressTabView: View {
    @Query private var activities: [ActivityLog]
    @Bindable var viewModel: AppViewModel

    @State private var showLogSheet = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        OverallProgressCard(
                            totalActivities: viewModel.totalActivities,
                            isActiveThisWeek: viewModel.isActiveThisWeek
                        )

                        TrackingCard(
                            title: "Distance Tracking",
                            subtitle: "Running & Walking",
                            icon: "🏃",
                            currentValue: viewModel.totalDistance,
                            unit: "mi",
                            progress: viewModel.progressToNextMilestone(type: .distance),
                            nextMilestoneTitle: viewModel.remainingToNextMilestone(type: .distance).milestone?.title ?? "All Complete!",
                            remaining: viewModel.remainingToNextMilestone(type: .distance).remaining,
                            remainingUnit: "mi"
                        )

                        TrackingCard(
                            title: "Weight Tracking",
                            subtitle: "Strength Training",
                            icon: "💪",
                            currentValue: viewModel.totalWeight,
                            unit: "lbs",
                            progress: viewModel.progressToNextMilestone(type: .weight),
                            nextMilestoneTitle: viewModel.remainingToNextMilestone(type: .weight).milestone?.title ?? "All Complete!",
                            remaining: viewModel.remainingToNextMilestone(type: .weight).remaining,
                            remainingUnit: "lbs"
                        )

                        MotivationalCard()
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(Color(hex: "#A78BFA"))
                    }
                    .accessibilityLabel("Activity history")
                }
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
            .sheet(isPresented: $showLogSheet) {
                LogActivitySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showHistory) {
                ActivityHistorySheet(viewModel: viewModel)
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Activities")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(totalActivities)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total activities: \(totalActivities)")

                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isActiveThisWeek ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(isActiveThisWeek ? "Active" : "Inactive")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("This week: \(isActiveThisWeek ? "Active" : "Inactive")")
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
        .clipShape(.rect(cornerRadius: 20))
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
    let nextMilestoneTitle: String
    let remaining: Double
    let remainingUnit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(icon)
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("Total:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f", currentValue))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                SwiftUI.ProgressView(value: progress)
                    .progressViewStyle(FitnessProgressStyle(tint: Color(hex: "#5B21B6")))
                    .accessibilityLabel("\(title) progress")
                    .accessibilityValue(String(format: "%.0f percent", progress * 100))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Milestone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(nextMilestoneTitle)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    Spacer()
                    if remaining > 0 {
                        Text(String(format: "%.1f %@ to go", remaining, remainingUnit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Complete!")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#059669"))
                    }
                }
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(.rect(cornerRadius: 20))
    }
}

// MARK: - Motivational Card

struct MotivationalCard: View {
    private let messages = [
        "Keep Going! Every step and rep counts.",
        "You're doing amazing! Stay consistent.",
        "Progress, not perfection. Keep it up!",
        "Your future self will thank you.",
        "One workout at a time. You've got this!"
    ]
    // Seeded once on creation — no flicker on layout passes
    @State private var message: String = ""

    var body: some View {
        HStack(spacing: 16) {
            Text("💪")
                .font(.title)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Spacer()
        }
        .padding()
        .background(Color(hex: "#059669"))
        .clipShape(.rect(cornerRadius: 20))
        .onAppear {
            if message.isEmpty {
                message = messages.randomElement() ?? messages[0]
            }
        }
    }
}

#Preview {
    ProgressTabView(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self], inMemory: true)
}
