//
//  HealthAccessNotice.swift
//  FunFitness
//
//  "Health access is off" and "couldn't save" notices with a Settings link (FB-0020). HealthKit
//  never asks again for a type the person declined, so Settings is the only way to fix it.
//

import SwiftUI

struct HealthAccessNotice: View {
    enum Kind {
        /// Before a save: write access is off, so this won't reach Health.
        case accessOff
        /// After a save that didn't make it (Home's banner).
        case saveFailed(HealthSaveResult)
    }

    let kind: Kind
    /// Shows a close button when set (Home's banner).
    var onDismiss: (() -> Void)?

    @Environment(\.openURL) private var openURL

    private var accessOff: Bool {
        switch kind {
        case .accessOff: return true
        case .saveFailed(let result): return result == .accessOff
        }
    }

    private var message: String {
        switch kind {
        case .accessOff:
            return "Apple Health access is off for FunFitness, so workouts won't be saved to Health."
        case .saveFailed(let result):
            return result == .accessOff
                ? "Your last workout wasn't saved to Apple Health because access is off for FunFitness."
                : "Your last workout couldn't be saved to Apple Health."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "heart.slash.fill")
                    .foregroundStyle(Color.ffDanger)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(message)
                        .ffFont(.bodyStrong)
                        .foregroundStyle(Color.ffInk)
                    if accessOff {
                        Text("In Settings, open Health → FunFitness and turn on Workouts and Walking + Running Distance.")
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffInkMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.ffInkMuted)
                    }
                    .accessibilityLabel("Dismiss")
                }
            }
            if accessOff {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .ffFont(.bodyStrong)
                .foregroundStyle(Color.ffLink)
                .accessibilityIdentifier("healthOpenSettingsButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("healthAccessNotice")
    }
}

/// Asks once (per device) after a finished workout whether to save workouts to Apple Health,
/// while that setting is off (FB-0020 item 3). Testers didn't find the setting in Profile, so
/// their workouts never reached Health or Fitness.
struct HealthSavePrompt: View {
    static let answeredKey = "healthSavePromptAnswered"

    let profile: UserProfile?
    /// Runs after Health access has been requested, so the caller can save right away.
    var onTurnOn: () -> Void = {}

    @AppStorage(HealthSavePrompt.answeredKey) private var answered = false

    var body: some View {
        if !answered, HealthKitManager.shared.isAvailable, let profile, !profile.healthKitWriteBackEnabled {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color.ffAccent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Save workouts to Apple Health?")
                            .ffFont(.bodyStrong)
                            .foregroundStyle(Color.ffInk)
                        Text("Your walks, runs and strength sessions will show up in Health and Fitness and count toward your rings. You can change this in Profile.")
                            .ffFont(.caption)
                            .foregroundStyle(Color.ffInkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 12) {
                    Button("Turn On") {
                        profile.healthKitWriteBackEnabled = true
                        answered = true
                        Task {
                            await HealthKitManager.shared.requestAuthorization()
                            onTurnOn()
                        }
                    }
                    .buttonStyle(.ffPrimary)
                    .accessibilityIdentifier("healthSavePromptTurnOn")

                    Button("Not Now") { answered = true }
                        .buttonStyle(.ffSecondary)
                        .accessibilityIdentifier("healthSavePromptNotNow")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("healthSavePrompt")
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HealthAccessNotice(kind: .accessOff)
        HealthAccessNotice(kind: .saveFailed(.accessOff), onDismiss: {})
        HealthAccessNotice(kind: .saveFailed(.failed), onDismiss: {})
    }
    .padding()
    .background(Color.ffBg)
}
