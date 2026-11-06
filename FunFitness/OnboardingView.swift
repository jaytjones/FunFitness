//
//  OnboardingView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var selectedGoal: String = "Stay Active"
    @State private var showValidationError = false

    let onComplete: () -> Void

    private let fitnessGoals = ["Build Endurance", "Lose Weight", "Build Muscle", "Stay Active", "Train for Race"]

    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 80

    var body: some View {
        ZStack {
            Color.ffBg
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Text("💪")
                        .font(.system(size: logoSize))
                        .accessibilityHidden(true)

                    Text("FunFitness")
                        .ffFont(.display)
                        .foregroundStyle(Color.ffInk)

                    Text("Turn your progress into fun comparisons")
                        .ffFont(.body)
                        .foregroundStyle(Color.ffInkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's your name?")
                            .ffFont(.headline)
                            .foregroundStyle(Color.ffInk)

                        TextField("Enter your name", text: $name)
                            .ffFont(.body)
                            .foregroundStyle(Color.ffInk)
                            .padding()
                            .ffWell()
                            .overlay(
                                RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
                                    .strokeBorder(showValidationError ? Color.ffDanger : Color.clear, lineWidth: FFStroke.card)
                            )

                        if showValidationError {
                            Text("Please enter your name")
                                .ffFont(.caption)
                                .foregroundStyle(Color.ffDanger)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's your fitness goal?")
                            .ffFont(.headline)
                            .foregroundStyle(Color.ffInk)

                        FlowLayout(spacing: 8) {
                            ForEach(fitnessGoals, id: \.self) { goal in
                                SelectionChip(
                                    title: goal,
                                    isSelected: selectedGoal == goal,
                                    action: { selectedGoal = goal }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    completeOnboarding()
                } label: {
                    Text("Get Started")
                }
                .buttonStyle(.ffPrimary)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            showValidationError = true
            return
        }
        showValidationError = false
        modelContext.insert(UserProfile(name: name, fitnessGoal: selectedGoal))
        onComplete()
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: UserProfile.self, inMemory: true)
}
