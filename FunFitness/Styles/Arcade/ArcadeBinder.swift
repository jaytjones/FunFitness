//
//  ArcadeBinder.swift
//  FunFitness
//
//  Arcade's Cards tab (3.3): every milestone as a trading card in a binder, grouped by activity type
//  ("Distance · 4 / 15"), with rarity frames; locked cards are dashed silhouettes that still say what
//  unlocks them. Spec: docs/design/arcade/components/BadgeTile.md and README "Rarity". Same data as
//  AchievementsView; `AchievementsView` shows this when Arcade is active.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI

struct ArcadeBinder: View {
    let achievements: [UnlockedAchievement]
    let viewModel: AppViewModel

    @State private var detail: Milestone?

    private var unlockedAt: [String: Date] {
        Dictionary(achievements.map { ($0.milestoneId, $0.unlockedAt) }, uniquingKeysWith: min)
    }
    private var pref: UnitPreference { viewModel.unitPreference }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: FFSpace.s3), count: 3)

    var body: some View {
        let dates = unlockedAt
        VStack(alignment: .leading, spacing: FFSpace.s6) {
            collectionPanel(unlockedCount: dates.count)
            ForEach(ActivityType.allCases, id: \.self) { type in
                let milestones = ComparisonEngine.milestones(for: type)
                let have = milestones.filter { dates[$0.id] != nil }.count
                VStack(alignment: .leading, spacing: FFSpace.s3) {
                    Text(verbatim: "\(type.displayName) · \(have) / \(milestones.count)")
                        .ffFont(.label)
                        .foregroundStyle(Color.ffInkMuted)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: columns, spacing: FFSpace.s3) {
                        ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                            let rarity = ArcadeRarity(index: index, count: milestones.count)
                            Button {
                                detail = milestone
                            } label: {
                                ArcadeTradingCard(
                                    milestone: milestone,
                                    type: type,
                                    rarity: rarity,
                                    emoji: milestone.getEmoji(for: viewModel.activePack),
                                    isUnlocked: dates[milestone.id] != nil,
                                    requirement: ArcadeBinder.requirement(milestone, pref: pref),
                                    pref: pref
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .sheet(item: $detail) { milestone in
            ArcadeCardDetail(
                milestone: milestone,
                pack: viewModel.activePack,
                pref: pref,
                unlockedAt: unlockedAt[milestone.id]
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func collectionPanel(unlockedCount: Int) -> some View {
        let total = ComparisonEngine.allMilestones.count
        let ids = Set(achievements.map(\.milestoneId))
        let level = SillyTitleEngine.level(unlockedIds: ids)
        let rank = SillyTitleEngine.sillyTitle(unlockedIds: ids).rank
        let fraction = total > 0 ? Double(unlockedCount) / Double(total) : 0
        return VStack(alignment: .leading, spacing: FFSpace.s2) {
            HStack {
                Text(verbatim: "Collection · \(unlockedCount)/\(total)")
                    .ffFont(.label)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.ffInk)
                Spacer()
                Text(verbatim: "LVL \(level.level) · \(rank)")
                    .ffFont(.label)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.ffRank)
            }
            ArcadeSegmentBar(progress: fraction, tint: .ffAccent)
            Text(verbatim: "\(Int((fraction * 100).rounded()))% collected")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
        }
        .padding(FFSpace.s4)
        .background(Color.ffSurface, in: RoundedRectangle(cornerRadius: FFRadius.md))
        .overlay(RoundedRectangle(cornerRadius: FFRadius.md).strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
        .accessibilityElement(children: .combine)
    }

    /// "Reach 5 mi", in the person's units.
    static func requirement(_ milestone: Milestone, pref: UnitPreference) -> String {
        let amount: String
        switch milestone.unit {
        case .kilometers: amount = UnitConverter.distanceString(milestone.threshold, pref: pref)
        case .kilograms: amount = UnitConverter.weightString(milestone.threshold, pref: pref)
        case .minutes: amount = UnitConverter.durationString(milestone.threshold)
        case .reps: amount = UnitConverter.repsString(milestone.threshold)
        }
        return "Reach \(amount)"
    }
}

// MARK: - Card

struct ArcadeTradingCard: View {
    let milestone: Milestone
    let type: ActivityType
    let rarity: ArcadeRarity
    let emoji: String
    let isUnlocked: Bool
    let requirement: String
    let pref: UnitPreference

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
        VStack(alignment: .leading, spacing: FFSpace.s2) {
            art
            Text(verbatim: isUnlocked ? milestone.title(pref: pref) : requirement)
                .ffFont(.caption)
                .fontWeight(isUnlocked ? .semibold : .regular)
                .foregroundStyle(isUnlocked ? Color.ffInk : Color.ffInkMuted)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
            HStack(spacing: 4) {
                // Always print the rarity word as well as the frame colour (README).
                Text(verbatim: rarity.word)
                    .ffFont(.label)
                    .fontWeight(.bold)
                    .foregroundStyle(isUnlocked ? Color.ffOnRarity : Color.ffInkMuted)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isUnlocked ? rarity.color : .clear, in: RoundedRectangle(cornerRadius: FFRadius.sm))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                // Not the label style: it would capitalise "D1b".
                Text(verbatim: milestone.id)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.ffInkMuted)
            }
        }
        .padding(FFSpace.s2)
        .background(isUnlocked ? Color.ffSurface : .clear, in: shape)
        .overlay {
            if isUnlocked {
                shape.strokeBorder(rarity.color, lineWidth: 2)
            } else {
                shape.strokeBorder(Color.ffLineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: isUnlocked
            ? "\(milestone.title(pref: pref)). \(rarity.word) card, collected."
            : "\(rarity.word) card, locked. \(requirement) to unlock."))
        .accessibilityHint(Text(verbatim: "Shows the card"))
    }

    /// Unlocked: full-colour emoji on the glow. Locked: a flat `line-strong` silhouette, no glow.
    @ViewBuilder
    private var art: some View {
        let frame = RoundedRectangle(cornerRadius: FFRadius.sm, style: .continuous)
        Group {
            if isUnlocked {
                Text(verbatim: emoji)
                    .font(.system(size: 34))
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(
                        RadialGradient(colors: [.ffGlow, .ffSurfaceAlt], center: .center, startRadius: 0, endRadius: 40),
                        in: frame
                    )
            } else {
                ArcadeSilhouette(emoji: emoji, tint: .ffLineStrong, size: 30)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(Color.ffSurfaceAlt.opacity(0.5), in: frame)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Detail

private struct ArcadeCardDetail: View {
    let milestone: Milestone
    let pack: ThemePack
    let pref: UnitPreference
    let unlockedAt: Date?

    var body: some View {
        let position = ArcadeRules.position(of: milestone.id)
        let rarity = position.map { ArcadeRarity(index: $0.index, count: $0.count) } ?? .common
        VStack(spacing: FFSpace.s4) {
            Text(verbatim: milestone.getEmoji(for: pack))
                .font(.system(size: 64))
                .frame(width: 120, height: 120)
                .background(
                    RadialGradient(colors: [.ffGlow, .ffSurfaceAlt], center: .center, startRadius: 0, endRadius: 64),
                    in: RoundedRectangle(cornerRadius: FFRadius.lg)
                )
                .overlay(RoundedRectangle(cornerRadius: FFRadius.lg).strokeBorder(rarity.color, lineWidth: 2))
                .opacity(unlockedAt == nil ? 0.4 : 1)
            Text(verbatim: "\(rarity.word) · \(milestone.id)")
                .ffFont(.label)
                .fontWeight(.bold)
                .foregroundStyle(rarity.color)
            Text(verbatim: milestone.title(pref: pref))
                .ffFont(.title)
                .foregroundStyle(Color.ffInk)
                .multilineTextAlignment(.center)
            if let unlockedAt {
                Text(verbatim: milestone.getComparison(for: pack))
                    .ffFont(.body)
                    .foregroundStyle(Color.ffInk)
                    .multilineTextAlignment(.center)
                Text(verbatim: "Collected \(unlockedAt.formatted(date: .abbreviated, time: .omitted))")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
                ArcadeShareButton(
                    content: .milestone(milestone, pack: pack, pref: pref),
                    filename: "funfitness_milestone.png"
                )
                .padding(.top, FFSpace.s2)
            } else {
                Text(verbatim: "\(ArcadeBinder.requirement(milestone, pref: pref)) to unlock this card.")
                    .ffFont(.body)
                    .foregroundStyle(Color.ffInkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(FFSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ffBg.ignoresSafeArea())
    }
}

#endif
