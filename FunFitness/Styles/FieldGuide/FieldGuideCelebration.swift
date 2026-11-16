//
//  FieldGuideCelebration.swift
//  FunFitness
//
//  Field Guide's milestone moment (3.3): a freshly recorded plate. The plate's outline is drawn in
//  ink over ~600ms, the "New entry recorded" stamp lands with one haptic, and the comparison is the
//  plate's caption, above a scale bar. Keep Going and Share as today. Reduce Motion: the finished
//  plate at once, haptic kept. The page stays parchment — no rust screen, no gradient, no confetti.
//  Spec: docs/design/field-guide/components/Celebration.md.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI

struct FieldGuideCelebration<ShareButton: View>: View {
    let milestone: Milestone
    let pack: ThemePack
    let pref: UnitPreference
    let onDismiss: () -> Void
    @ViewBuilder let shareButton: ShareButton

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0
    @State private var stamped = false
    @State private var hapticTrigger = 0

    var body: some View {
        let number = FieldGuideRules.specimenNumber(milestone.id) ?? 0
        let emoji = milestone.getEmoji(for: pack)
        let name = FieldGuideRules.binomial(for: emoji, packId: pack.id)
        ZStack {
            Color.ffBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: FFSpace.s4) {
                Spacer(minLength: 0)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: FFSpace.s2) {
                        Text(verbatim: String(format: "Specimen No. %02d", number))
                            .ffFont(.label)
                            .foregroundStyle(Color.ffAccent)
                        Text(verbatim: milestone.title(pref: pref))
                            .ffFont(.display)
                            .foregroundStyle(Color.ffInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: FFSpace.s2)
                    stamp
                }

                // The plate: its outline traced in ink, the figure inside once drawn.
                ZStack {
                    Rectangle()
                        .trim(from: 0, to: drawn)
                        .stroke(Color.ffInk, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    Text(verbatim: emoji)
                        .font(.system(size: 88))
                        .opacity(drawn >= 1 ? 1 : 0)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: drawn)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color.ffSurface)

                scaleBar

                Text(verbatim: "Fig. \(String(format: "%02d", number)). " + (name.map { "\($0). " } ?? "") + milestone.getComparison(for: pack))
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Text(verbatim: "Keep Going")
                }
                .buttonStyle(.ffPrimary)
                .accessibilityIdentifier("keepGoingButton")
                shareButton
            }
            .padding(.horizontal, FFSpace.s6)
            .padding(.bottom, FFSpace.s8)
        }
        .onAppear {
            if reduceMotion {
                drawn = 1
                stamped = true
            } else {
                withAnimation(.easeInOut(duration: 0.6)) { drawn = 1 }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(0.6)) { stamped = true }
            }
            // One haptic as the stamp lands; kept with Reduce Motion (Celebration.md).
            Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 650))
                hapticTrigger += 1
            }
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
        .accessibilityElement(children: .contain)
    }

    /// "New entry recorded", stamped in moss at a slight angle.
    private var stamp: some View {
        Text(verbatim: "New entry\nrecorded")
            .ffFont(.label)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.ffAccent2)
            .padding(.horizontal, FFSpace.s2)
            .padding(.vertical, FFSpace.s1)
            .overlay(Rectangle().strokeBorder(Color.ffAccent2, lineWidth: 2))
            .rotationEffect(.degrees(-8))
            .scaleEffect(stamped ? 1 : 1.6)
            .opacity(stamped ? 1 : 0)
    }

    /// A black-and-white scale bar under the plate (decorative).
    private var scaleBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(i.isMultiple(of: 2) ? Color.ffInk : Color.ffSurface)
                    .frame(width: 28, height: 6)
            }
        }
        .overlay(Rectangle().strokeBorder(Color.ffInk, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

#endif
