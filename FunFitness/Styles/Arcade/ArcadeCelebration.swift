//
//  ArcadeCelebration.swift
//  FunFitness
//
//  Arcade's milestone celebration (3.3): a card-pack reveal. The new card starts face down, scales
//  from 0.9 and flips once (0.6s spring) while rays fade in behind it; Keep Going and Share as
//  today, with the same success haptic. Reduce Motion shows the finished frame at once: no flip,
//  no rays. Spec: docs/design/arcade/components/Celebration.md. `MilestoneView` shows this when
//  Arcade is active.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI
import SwiftData

struct ArcadeCelebration<ShareButton: View>: View {
    let milestone: Milestone
    let pack: ThemePack
    let pref: UnitPreference
    let onDismiss: () -> Void
    @ViewBuilder let shareButton: ShareButton

    @Query private var achievements: [UnlockedAchievement]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var hapticTrigger = 0

    var body: some View {
        ZStack {
            Color.ffBg.ignoresSafeArea()

            if !reduceMotion {
                ArcadeRays()
                    .opacity(revealed ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(0.2), value: revealed)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }

            VStack(spacing: FFSpace.s6) {
                Spacer()
                Text(verbatim: "New card")
                    .ffFont(.label)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.ffAccent)

                ArcadeRevealCard(milestone: milestone, pack: pack, pref: pref, unlockedIds: Set(achievements.map(\.milestoneId)))
                    .modifier(ArcadeFlip(angle: revealed || reduceMotion ? 0 : 180))
                    .scaleEffect(revealed || reduceMotion ? 1 : 0.9)
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.75), value: revealed)
                    .padding(.horizontal, FFSpace.s8)

                Spacer()

                VStack(spacing: FFSpace.s3) {
                    Button(action: onDismiss) {
                        Text(verbatim: "Keep going")
                    }
                    .buttonStyle(.ffPrimary)
                    .accessibilityIdentifier("keepGoingButton")
                    shareButton
                }
                .padding(.horizontal, FFSpace.s8)
                .padding(.bottom, FFSpace.s8)
            }
        }
        .onAppear {
            revealed = true
            // Same as today's celebration: the haptic goes with the motion.
            if !reduceMotion { hapticTrigger += 1 }
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
        .accessibilityElement(children: .contain)
    }
}

/// The revealed card: rarity frame, glowing art, title, comparison, rarity word and id.
private struct ArcadeRevealCard: View {
    let milestone: Milestone
    let pack: ThemePack
    let pref: UnitPreference
    let unlockedIds: Set<String>

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let rarity = ArcadeRules.rarity(of: milestone.id) ?? .common
        let level = SillyTitleEngine.level(unlockedIds: unlockedIds)
        let shape = RoundedRectangle(cornerRadius: FFRadius.lg, style: .continuous)
        VStack(spacing: FFSpace.s3) {
            HStack {
                Text(verbatim: rarity.word)
                    .ffFont(.label)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.ffOnRarity)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(rarity.color, in: RoundedRectangle(cornerRadius: FFRadius.sm))
                Spacer()
                Text(verbatim: milestone.id)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.ffInkMuted)
            }
            Text(verbatim: milestone.getEmoji(for: pack))
                .font(.system(size: 80))
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(
                    RadialGradient(colors: [.ffGlow, .ffSurfaceAlt], center: .center, startRadius: 0, endRadius: 110),
                    in: RoundedRectangle(cornerRadius: FFRadius.md)
                )
                .accessibilityHidden(true)
            Text(verbatim: milestone.title(pref: pref))
                .ffFont(.display)
                .foregroundStyle(Color.ffInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: milestone.getComparison(for: pack))
                .ffFont(.body)
                .foregroundStyle(Color.ffInkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let nextRank = level.nextRank {
                Text(verbatim: "+1 badge · \(level.badgesToNext) to \(nextRank)")
                    .ffFont(.label)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.ffRank)
            }
        }
        .padding(FFSpace.s4)
        .background(Color.ffSurface, in: shape)
        .overlay(shape.strokeBorder(rarity.color, lineWidth: 3))
        .shadow(color: colorScheme == .dark ? rarity.color.opacity(0.35) : .black.opacity(0.14),
                radius: colorScheme == .dark ? 22 : 14, y: colorScheme == .dark ? 0 : 8)
        .accessibilityElement(children: .combine)
    }
}

/// The face-down side: the brand gradient with a card mark.
private struct ArcadeCardBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: FFRadius.lg, style: .continuous)
            .fill(Color.ffBrandGradient)
            .overlay(
                Image(systemName: "sparkles")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Color.ffOnGradient)
            )
    }
}

/// Flips around the vertical axis, showing the back past 90° so the turn reads as one flip.
private struct ArcadeFlip: ViewModifier, Animatable {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(angle < 90 ? 1 : 0)
            .overlay {
                if angle >= 90 {
                    ArcadeCardBack()
                }
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

/// Soft rays behind the card (motion only).
private struct ArcadeRays: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height * 0.45)
            let radius = max(size.width, size.height)
            let count = 16
            for i in 0..<count {
                let start = Angle.degrees(Double(i) * 360 / Double(count))
                let end = Angle.degrees(Double(i) * 360 / Double(count) + 360 / Double(count) / 2)
                var wedge = Path()
                wedge.move(to: center)
                wedge.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .radialGradient(
                    Gradient(colors: [Color.ffAccent.opacity(0.22), Color.ffGlow.opacity(0)]),
                    center: center, startRadius: 0, endRadius: radius * 0.6
                ))
            }
        }
    }
}

#endif
