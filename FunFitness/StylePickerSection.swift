//
//  StylePickerSection.swift
//  FunFitness
//
//  Profile › Style (3.3): pick the app's look, see what's locked and how far the streak goal is,
//  and unlock every Style now with the one purchase (or restore / redeem a code).
//
//  UNRELEASED — compiled only with INTERNAL_STYLES, and shown only when more than one Style is
//  available. All text is verbatim so none of it reaches the string catalog that ships in every
//  build; at launch, remove the #if and move the text into the catalog.
//

#if INTERNAL_STYLES

import SwiftUI
import SwiftData
import StoreKit

struct StylePickerSection: View {
    let profile: UserProfile?
    @Bindable var viewModel: AppViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var isBuying = false
    @State private var message: String?
    @State private var showRedeem = false

    private var purchases: StylePurchases { .shared }
    private var access: StyleAccess { viewModel.styleAccess }
    private var selected: StyleID {
        StyleID.resolve(profile?.activeStyleID ?? "", isAvailable: access.isAvailable)
    }
    private var anyLocked: Bool {
        access.visibleStyles.contains { !access.status(of: $0).isUnlocked }
    }

    var body: some View {
        if access.visibleStyles.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: "Style")
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(Array(access.visibleStyles.enumerated()), id: \.element) { index, style in
                        if index > 0 { Divider() }
                        row(style)
                    }
                }
                .ffCard(padding: 0, radius: FFRadius.md)
                .padding(.horizontal)

                purchaseArea
                    .padding(.horizontal)
            }
            .offerCodeRedemption(isPresented: $showRedeem) { _ in
                Task { await purchases.refreshEntitlements() }
            }
            .accessibilityIdentifier("stylePickerSection")
        }
    }

    // MARK: Rows

    private func row(_ style: StyleID) -> some View {
        let status = access.status(of: style)
        return Button {
            guard status.isUnlocked, style != selected else { return }
            profile?.activeStyleID = style.rawValue
            try? modelContext.save()
        } label: {
            HStack(spacing: 12) {
                swatch(style)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: style.displayName)
                        .ffFont(.bodyStrong)
                        .foregroundStyle(Color.ffInk)
                    Text(verbatim: statusText(style, status))
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
                Spacer()
                if style == selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.ffSuccess)
                } else if !status.isUnlocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.ffInkMuted)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(style == selected ? .isSelected : [])
    }

    /// Three dots in that Style's own ground, surface and accent, in the current appearance.
    private func swatch(_ style: StyleID) -> some View {
        HStack(spacing: -6) {
            ForEach([FFColorToken.bg, .surface, .accent], id: \.self) { token in
                let pair = token.pair(in: style)
                Circle()
                    .fill(Color(FFColor.rgb(colorScheme == .dark ? pair.dark : pair.light)))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(Color.ffLine, lineWidth: 1))
            }
        }
        .accessibilityHidden(true)
    }

    private func statusText(_ style: StyleID, _ status: StyleAccess.Status) -> String {
        let base: String
        switch status {
        case .free: base = "Free"
        case .earned: base = "Unlocked with your streak"
        case .purchased: base = "Unlocked"
        case .owner: base = "Unlocked (owner)"
        case .locked(let weeksToGo):
            let goal = style.streakWeeksToUnlock ?? weeksToGo
            base = "Keep a \(goal)-week streak · \(weeksToGo) to go"
        }
        return style.isReleased ? base : base + " · not released"
    }

    // MARK: Purchase

    @ViewBuilder
    private var purchaseArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            if purchases.ownsAllStyles {
                Label {
                    Text(verbatim: "All styles unlocked")
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
                .ffFont(.bodyStrong)
                .foregroundStyle(Color.ffSuccess)
            } else {
                Button {
                    Task { await buy() }
                } label: {
                    Text(verbatim: buyTitle)
                }
                .buttonStyle(.ffPrimary)
                .disabled(isBuying || purchases.product == nil)
                .accessibilityIdentifier("unlockAllStylesButton")

                if purchases.product == nil {
                    Text(verbatim: "Not available yet. The in-app purchase hasn't been set up in App Store Connect.")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                } else if anyLocked {
                    Text(verbatim: "Or keep your streak going: styles unlock at 4, 8, 12 weeks…")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
            }

            HStack(spacing: 20) {
                Button {
                    Task {
                        await purchases.restore()
                        message = purchases.ownsAllStyles ? "Restored." : "Nothing to restore."
                    }
                } label: {
                    Text(verbatim: "Restore Purchases")
                }
                Button {
                    showRedeem = true
                } label: {
                    Text(verbatim: "Redeem Code")
                }
            }
            .ffFont(.bodyStrong)
            .foregroundStyle(Color.ffLink)

            if let message {
                Text(verbatim: message)
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }
        }
    }

    private var buyTitle: String {
        if isBuying { return "Unlocking…" }
        if let price = purchases.product?.displayPrice { return "Unlock all styles now · \(price)" }
        return "Unlock all styles now"
    }

    private func buy() async {
        isBuying = true
        defer { isBuying = false }
        switch await purchases.purchase() {
        case .purchased: message = "All styles unlocked."
        case .pending: message = "Waiting for approval."
        case .cancelled: message = nil
        case .failed: message = "Couldn't complete the purchase. Try again later."
        }
    }
}

#endif
