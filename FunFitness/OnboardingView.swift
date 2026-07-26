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
            Color(hex: "#0D0D1A")
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Text("💪")
                        .font(.system(size: logoSize))
                        .accessibilityHidden(true)

                    Text("FunFitness")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Turn your progress into fun comparisons")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's your name?")
                            .font(.headline)
                            .foregroundStyle(.white)

                        TextField("Enter your name", text: $name)
                            .font(.body)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color(hex: "#1A1A2E"))
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(showValidationError ? Color.red : Color.clear, lineWidth: 2)
                            )

                        if showValidationError {
                            Text("Please enter your name")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's your fitness goal?")
                            .font(.headline)
                            .foregroundStyle(.white)

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
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#5B21B6"))
                        .clipShape(.rect(cornerRadius: 14))
                }
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
