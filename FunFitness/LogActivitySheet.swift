//
//  LogActivitySheet.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

struct LogActivitySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var activities: [ActivityLog]
    
    @Bindable var viewModel: AppViewModel
    
    @State private var selectedType: ActivityType = .distance
    @State private var inputValue: String = ""
    @State private var showValidationError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D1A")
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Activity Type Toggle
                    Picker("Activity Type", selection: $selectedType) {
                        Text("Distance").tag(ActivityType.distance)
                        Text("Weight").tag(ActivityType.weight)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedType) {
                        inputValue = ""
                        showValidationError = false
                    }
                    
                    // Input Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedType == .distance ? "Distance (miles)" : "Weight (lbs)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        TextField(
                            selectedType == .distance ? "0.0" : "0",
                            text: $inputValue
                        )
                        .keyboardType(selectedType == .distance ? .decimalPad : .numberPad)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color(hex: "#1A1A2E"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(showValidationError ? Color.red : Color.clear, lineWidth: 2)
                        )
                        
                        if showValidationError {
                            Text("Please enter a valid value greater than 0")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Submit Button
                    Button {
                        logActivity()
                    } label: {
                        HStack {
                            Text(selectedType == .distance ? "Log Distance" : "Log Weight")
                                .font(.headline)
                            Text(selectedType == .distance ? "🏃" : "💪")
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#5B21B6"))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)
            }
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func logActivity() {
        guard let value = Double(inputValue), value > 0 else {
            showValidationError = true
            return
        }
        
        showValidationError = false
        
        // Store previous totals for milestone checking
        let previousDistance = viewModel.totalDistance
        let previousWeight = viewModel.totalWeight
        
        // Create and save activity
        let activity = ActivityLog(type: selectedType, value: value)
        modelContext.insert(activity)
        
        // Force save to ensure the activity is persisted
        try? modelContext.save()
        
        // Wait a moment for SwiftData to process, then recalculate with fresh query
        // The activities query will automatically update, so we just need to trigger recalculation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Recalculate totals with current activities (query will be updated by now)
            viewModel.calculateTotals(activities: activities)
            
            // Check for new milestones
            let previousTotal = selectedType == .distance ? previousDistance : previousWeight
            let newTotal = selectedType == .distance ? viewModel.totalDistance : viewModel.totalWeight
            
            let newMilestones = viewModel.checkForMilestones(
                type: selectedType,
                previousTotal: previousTotal,
                newTotal: newTotal
            )
            
            // Save unlocked achievements
            for milestone in newMilestones {
                let achievement = UnlockedAchievement(milestoneId: milestone.id)
                modelContext.insert(achievement)
                viewModel.unlockedAchievementIds.insert(milestone.id)
            }
            
            // Queue milestones for celebration
            if !newMilestones.isEmpty {
                viewModel.pendingMilestones = newMilestones
                viewModel.showMilestoneModal = true
            }
        }
        
        dismiss()
    }
}

#Preview {
    LogActivitySheet(viewModel: AppViewModel())
        .modelContainer(for: [ActivityLog.self, UnlockedAchievement.self], inMemory: true)
}
