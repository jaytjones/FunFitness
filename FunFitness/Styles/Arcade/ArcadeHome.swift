//
//  ArcadeHome.swift
//  FunFitness
//
//  Arcade's Home top (3.3): wordmark + level chip, the featured "next card", the Weight and Streak
//  tiles, and the collection row. Specs: docs/design/arcade/README.md and components/HeroStat.md,
//  StatTile.md, RankCard.md, StreakCard.md, ProgressMeter.md, BadgeTile.md. Every number is one the
//  app already computes (milestones, unlocks, silly-title tiers); nothing new is stored.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES. Text is verbatim so none of it reaches the
//  string catalog; at launch, move it into the catalog.
//

#if INTERNAL_STYLES

import SwiftUI

// MARK: - Display rules (pure)

/// Rarity is position within the activity type's ordered milestones, not luck (README): top 10% is
/// Legendary (min 1), the next 20% Epic (min 1), the first 40% Common, the rest Rare.
nonisolated enum ArcadeRarity: Equatable, Sendable {
    case common, rare, epic, legendary

    init(index i: Int, count n: Int) {
        let legendary = max(1, Int((Double(n) * 0.1).rounded()))
        let epic = max(1, Int((Double(n) * 0.2).rounded()))
        let common = Int((Double(n) * 0.4).rounded())
        if i >= n - legendary { self = .legendary }
        else if i >= n - legendary - epic { self = .epic }
        else if i < common { self = .common }
        else { self = .rare }
    }

    var word: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }

    var color: Color {
        switch self {
        case .common: return .ffRarityCommon
        case .rare: return .ffRarityRare
        case .epic: return .ffRarityEpic
        case .legendary: return .ffRarityLegendary
        }
    }
}

enum ArcadeRules {
    /// Lit segments of 8: round(progress × 8), held at 1–7 until the milestone is reached.
    static func litSegments(progress: Double) -> Int {
        ArcadeSegmentRule.lit(progress: progress)
    }

    /// The type a milestone belongs to, its 1-based position and the type's count ("NEXT 03/15").
    static func position(of milestoneId: String) -> (type: ActivityType, index: Int, count: Int)? {
        for type in ActivityType.allCases {
            let list = ComparisonEngine.milestones(for: type)
            if let i = list.firstIndex(where: { $0.id == milestoneId }) { return (type, i, list.count) }
        }
        return nil
    }

    static func rarity(of milestoneId: String) -> ArcadeRarity? {
        position(of: milestoneId).map { ArcadeRarity(index: $0.index, count: $0.count) }
    }

    /// "2,589 lbs" → ("2,589", "lbs"), so the unit word can sit smaller beside the numeral.
    static func split(_ display: String) -> (value: String, unit: String) {
        guard let space = display.lastIndex(of: " ") else { return (display, "") }
        return (String(display[..<space]), String(display[display.index(after: space)...]))
    }
}

// MARK: - Top of Home

struct ArcadeHomeTop: View {
    let viewModel: AppViewModel
    let unlocked: [UnlockedAchievement]
    let onLog: (ActivityType) -> Void
    let onUseShield: () -> Void

    private var unlockedIds: Set<String> { Set(unlocked.map(\.milestoneId)) }

    var body: some View {
        VStack(spacing: FFSpace.s3) {
            header
            ArcadeFeaturedCard(viewModel: viewModel, unlockedIds: unlockedIds) { onLog(.distance) }
            HStack(alignment: .top, spacing: FFSpace.s3) {
                ArcadeWeightTile(viewModel: viewModel) { onLog(.weight) }
                ArcadeStreakTile(viewModel: viewModel, onUseShield: onUseShield)
            }
            ArcadeCollectionRow(viewModel: viewModel, unlocked: unlocked)
        }
    }

    private var header: some View {
        let level = SillyTitleEngine.level(unlockedIds: unlockedIds)
        let rank = SillyTitleEngine.sillyTitle(unlockedIds: unlockedIds).rank
        return HStack {
            (Text(verbatim: "FUN") + Text(verbatim: "FITNESS").foregroundColor(.ffAccent))
                .ffFont(.title)
                .foregroundStyle(Color.ffInk)
                .accessibilityLabel(Text(verbatim: "FunFitness"))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text(verbatim: "LVL \(level.level) · \(rank)")
                .ffFont(.label)
                .fontWeight(.bold)
                .foregroundStyle(Color.ffRank)
                .padding(.horizontal, FFSpace.s2)
                .padding(.vertical, FFSpace.s1)
                .overlay(RoundedRectangle(cornerRadius: FFRadius.sm).strokeBorder(Color.ffLineStrong, lineWidth: 1))
                .accessibilityLabel(Text(verbatim: "Level \(level.level), \(rank)"))
            // Shares the silly title and rank (Playful Bold's title banner does this today).
            ArcadeShareButton(
                content: .title(viewModel.sillyTitle, badgeCount: unlockedIds.count),
                filename: "funfitness_title.png"
            )
        }
        .padding(.bottom, FFSpace.s1)
    }
}

// MARK: - Featured next card (HeroStat.md)

struct ArcadeFeaturedCard: View {
    let viewModel: AppViewModel
    let unlockedIds: Set<String>
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private let type: ActivityType = .distance
    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        let next = viewModel.remainingToNextMilestone(type: type)
        let shape = RoundedRectangle(cornerRadius: FFRadius.lg, style: .continuous)
        Button(action: onTap) {
            Group {
                if let milestone = next.milestone {
                    content(milestone, remaining: next.remaining)
                } else {
                    Text(verbatim: "Every distance card collected!")
                        .ffFont(.title)
                        .foregroundStyle(Color.ffInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(FFSpace.s4)
            .background(Color.ffSurface, in: shape)
            .overlay(shape.strokeBorder(Color.ffBrandGradient, lineWidth: 2))
            // shadow-neon: a soft cyan halo in Arcade, a lift in Daylight.
            .shadow(color: colorScheme == .dark ? Color.ffAccent.opacity(0.22) : Color.black.opacity(0.12),
                    radius: colorScheme == .dark ? 16 : 12, y: colorScheme == .dark ? 0 : 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(verbatim: "Logs a distance activity"))
        .accessibilityIdentifier("arcadeFeaturedCard")
    }

    private func content(_ milestone: Milestone, remaining: Double) -> some View {
        let position = ArcadeRules.position(of: milestone.id)
        let rarity = ArcadeRules.rarity(of: milestone.id) ?? .common
        let progress = viewModel.progressToNextMilestone(type: type)
        let emoji = ComparisonEngine.content(packId: viewModel.activePack.id, milestoneId: milestone.id)?.emoji ?? type.emoji
        let level = SillyTitleEngine.level(unlockedIds: unlockedIds)
        let total = viewModel.displayTotal(for: type)
        let goal = UnitConverter.displayString(milestone.threshold, type: type, pref: pref)

        return HStack(alignment: .top, spacing: FFSpace.s3) {
            VStack(alignment: .leading, spacing: FFSpace.s2) {
                HStack(spacing: FFSpace.s2) {
                    Text(verbatim: String(format: "Next %02d/%02d", (position?.index ?? 0) + 1, position?.count ?? 0))
                        .ffFont(.label)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.ffAccent)
                    Text(verbatim: rarity.word)
                        .ffFont(.label)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.ffOnRarity)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rarity.color, in: RoundedRectangle(cornerRadius: FFRadius.sm))
                }
                Text(verbatim: milestone.title(pref: pref))
                    .ffFont(.display)
                    .foregroundStyle(Color.ffInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: "Dist \(total) / \(goal)")
                    .ffFont(.label)
                    .foregroundStyle(Color.ffInkMuted)
                ArcadeSegmentBar(progress: progress, tint: type.ffFill)
                Text(verbatim: "\(UnitConverter.displayString(remaining, type: type, pref: pref)) to go · \(Int((progress * 100).rounded()))%")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
                if let nextRank = level.nextRank {
                    Text(verbatim: "+1 badge · \(level.badgesToNext) to \(nextRank)")
                        .ffFont(.label)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.ffRank)
                }
            }
            Spacer(minLength: 0)
            // Card art: the pack emoji as a silhouette in the type colour, glow behind (no text on it).
            ArcadeSilhouette(emoji: emoji, tint: type.ffFill, size: 44)
                .frame(width: 84, height: 84)
                .background(
                    RadialGradient(colors: [.ffGlow, .ffSurfaceAlt], center: .center, startRadius: 0, endRadius: 46),
                    in: RoundedRectangle(cornerRadius: FFRadius.md)
                )
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tiles (StatTile.md, StreakCard.md)

private struct ArcadeTile<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpace.s1) {
            Text(verbatim: label)
                .ffFont(.label)
                .foregroundStyle(Color.ffInkMuted)
            content
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(FFSpace.s4)
        .background(Color.ffSurface, in: RoundedRectangle(cornerRadius: FFRadius.md))
        .overlay(RoundedRectangle(cornerRadius: FFRadius.md).strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
    }
}

/// A numeral with its unit word at 0.62em beside it ("6 weeks").
private struct ArcadeNumeral: View {
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verbatim: value)
                .ffFont(.numeral)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !unit.isEmpty {
                Text(verbatim: unit)
                    .font(.system(size: FFTextStyle.numeral.size * 0.62, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
    }
}

struct ArcadeWeightTile: View {
    let viewModel: AppViewModel
    let onTap: () -> Void

    var body: some View {
        let type: ActivityType = .weight
        let parts = ArcadeRules.split(viewModel.displayTotal(for: type))
        let fit = ReferenceUnitEngine.bestFit(total: viewModel.total(for: type), type: type, packId: viewModel.activePack.id)
        Button(action: onTap) {
            ArcadeTile(label: "Weight") {
                ArcadeNumeral(value: parts.value, unit: parts.unit, color: .ffInk)
                // The real ticker comparison, or nothing (StatTile.md: don't make one up).
                if let fit {
                    Text(verbatim: "\(fit.phrase) \(fit.unit.emoji)")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(verbatim: "Logs a weight activity"))
    }
}

struct ArcadeStreakTile: View {
    let viewModel: AppViewModel
    let onUseShield: () -> Void

    /// Same rule as today's StreakCard: shields left, not active this week, a streak to protect.
    private var canUseShield: Bool {
        viewModel.shieldsAvailable > 0 && !viewModel.isActiveThisWeekStreak && viewModel.currentStreak > 0
    }

    var body: some View {
        let weeks = viewModel.currentStreak
        ArcadeTile(label: "Streak") {
            ArcadeNumeral(value: "\(weeks)", unit: weeks == 1 ? "week" : "weeks", color: .ffStreak)
            Text(verbatim: "best \(viewModel.longestStreak) · \(viewModel.shieldsAvailable) shield\(viewModel.shieldsAvailable == 1 ? "" : "s")")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
            if canUseShield {
                Button(action: onUseShield) {
                    Text(verbatim: "Use shield")
                        .ffFont(.label)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.ffSuccess)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .topTrailing) {
            if weeks > 0 {
                ArcadeShareButton(
                    content: .streak(current: weeks, longest: viewModel.longestStreak),
                    filename: "funfitness_streak.png"
                )
                .padding(FFSpace.s2)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Collection row (BadgeTile.md .slots)

struct ArcadeCollectionRow: View {
    let viewModel: AppViewModel
    let unlocked: [UnlockedAchievement]

    var body: some View {
        let recent = unlocked.sorted { $0.unlockedAt > $1.unlockedAt }.prefix(3).reversed()
        VStack(alignment: .leading, spacing: FFSpace.s2) {
            Text(verbatim: "Collection · \(Set(unlocked.map(\.milestoneId)).count)/\(ComparisonEngine.allMilestones.count)")
                .ffFont(.label)
                .foregroundStyle(Color.ffInkMuted)
            HStack(spacing: FFSpace.s3) {
                ForEach(Array(recent), id: \.milestoneId) { achievement in
                    slot(for: achievement.milestoneId)
                }
                emptySlot
                ForEach(0..<max(0, 3 - recent.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func slot(for id: String) -> some View {
        let rarity = ArcadeRules.rarity(of: id) ?? .common
        let emoji = ComparisonEngine.content(packId: viewModel.activePack.id, milestoneId: id)?.emoji ?? "🏅"
        return Text(verbatim: emoji)
            .font(.system(size: 30))
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Color.ffSurfaceAlt, in: RoundedRectangle(cornerRadius: FFRadius.md))
            .overlay(RoundedRectangle(cornerRadius: FFRadius.md).strokeBorder(rarity.color, lineWidth: 2))
            .accessibilityLabel(Text(verbatim: "\(rarity.word) card"))
    }

    /// The next card's place: dashed `line-strong`, nothing inside yet.
    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: FFRadius.md)
            .strokeBorder(Color.ffLineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(maxWidth: .infinity, minHeight: 72)
            .overlay(Image(systemName: "questionmark").foregroundStyle(Color.ffLineStrong))
            .accessibilityLabel(Text(verbatim: "Next card"))
    }
}

// MARK: - Ticker (Ticker.md)

/// "Right now…": one line per type with a live comparison, each led by a mono type tag in that
/// type's colour; a flat panel instead of today's inverted card.
struct ArcadeTicker: View {
    let viewModel: AppViewModel

    private static func tag(_ type: ActivityType) -> String {
        switch type {
        case .distance: return "Dist"
        case .weight: return "Wt"
        case .duration: return "Time"
        case .reps: return "Reps"
        }
    }

    var body: some View {
        let lines = ActivityType.allCases.compactMap { type in
            viewModel.absurdityTickerText(for: type).map { (type, $0) }
        }
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: FFSpace.s3) {
                Text(verbatim: "Right now…")
                    .ffFont(.label)
                    .foregroundStyle(Color.ffInkMuted)
                ForEach(lines, id: \.0) { type, line in
                    HStack(alignment: .firstTextBaseline, spacing: FFSpace.s2) {
                        Text(verbatim: Self.tag(type))
                            .ffFont(.label)
                            .fontWeight(.bold)
                            .foregroundStyle(type.ffFill)
                            .frame(width: 44, alignment: .leading)
                        // Wraps, never truncates (Ticker.md).
                        Text(verbatim: line)
                            .ffFont(.headline)
                            .foregroundStyle(Color.ffInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .ffCard(padding: FFSpace.s4, radius: FFRadius.md)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("absurdityTicker")
        }
    }
}

// MARK: - Pieces

/// 8 segments (ProgressMeter.md): lit in the type colour, unlit `progress-track`.
struct ArcadeSegmentBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ArcadeSegments(progress: progress, tint: tint)
    }
}

/// An emoji as a single-colour silhouette (card art before unlock).
struct ArcadeSilhouette: View {
    let emoji: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        tint
            .mask(Text(verbatim: emoji).font(.system(size: size)))
            .frame(width: size * 1.3, height: size * 1.3)
            .accessibilityHidden(true)
    }
}

#endif
