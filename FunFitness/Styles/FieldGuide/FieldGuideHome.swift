//
//  FieldGuideHome.swift
//  FunFitness
//
//  Field Guide's Guide tab (3.3): masthead, the lead plate (headline from the ticker, the next
//  milestone as a framed plate with its Fig. caption and ruler), a ruled specimen grid for the other
//  types and the streak tally, the title page, and the ticker as numbered field notes. Specs:
//  docs/design/field-guide/README.md and components/HeroStat.md, StatTile.md, StreakCard.md,
//  RankCard.md, Ticker.md. Every number comes from ReferenceUnit / ComparisonEngine.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI

// MARK: - Guide voice (pure)

enum FieldGuideRules {
    /// Specimen number: the milestone's place in the full catalogue, 1-based ("No. 07", "Fig. 07").
    static func specimenNumber(_ milestoneId: String) -> Int? {
        ComparisonEngine.allMilestones.firstIndex { $0.id == milestoneId }.map { $0 + 1 }
    }

    /// Latin binomials, Animals pack only (README "Captions").
    static func binomial(for emoji: String, packId: String) -> String? {
        guard packId == "animals" else { return nil }
        switch emoji {
        case "🐳", "🐋": return "Balaenoptera musculus"
        case "🐻": return "Ursus arctos"
        case "🐝": return "Apis mellifera"
        case "🦛": return "Hippopotamus amphibius"
        case "🦒": return "Giraffa camelopardalis"
        case "🐘": return "Loxodonta africana"
        default: return nil
        }
    }

    /// "21.9 mi" → "21.9 miles" for the headline (units sit in the chrome, spelled out).
    static func totalInWords(_ display: String) -> String {
        let words = ["mi": "miles", "km": "kilometers", "lbs": "pounds", "lb": "pounds", "kg": "kilograms",
                     "min": "minutes", "hr": "hours", "reps": "reps"]
        var parts = display.split(separator: " ").map(String.init)
        if let last = parts.last, let word = words[last] {
            parts[parts.count - 1] = word
            if parts.first == "1" { parts[parts.count - 1] = String(word.dropLast()) }
        }
        return parts.joined(separator: " ")
    }

    /// Lowercase roman numerals for field notes (i–xx is plenty).
    static func roman(_ n: Int) -> String {
        let table = [(10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]
        var n = n, out = ""
        for (value, symbol) in table { while n >= value { out += symbol; n -= value } }
        return out
    }

    /// "a" or "an" from the title's first letter (RankCard.md).
    static func article(for title: String) -> String {
        guard let first = title.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }
}

// MARK: - Top of Guide

struct FieldGuideHomeTop: View {
    let viewModel: AppViewModel
    let unlocked: [UnlockedAchievement]
    let onLog: (ActivityType) -> Void
    let onUseShield: () -> Void

    private var unlockedIds: Set<String> { Set(unlocked.map(\.milestoneId)) }

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpace.s5) {
            FieldGuideMasthead(runningHead: "Vol. I")
            FieldGuideLeadPlate(viewModel: viewModel) { onLog(.distance) }
            FieldGuideSpecimenGrid(viewModel: viewModel, onLog: onLog, onUseShield: onUseShield)
            FieldGuideTitlePage(viewModel: viewModel, unlockedIds: unlockedIds)
        }
    }
}

/// "THE FUNFITNESS FIELD GUIDE" left, the page's running head right, a 2px ink rule under.
struct FieldGuideMasthead: View {
    let runningHead: String

    var body: some View {
        VStack(spacing: FFSpace.s2) {
            HStack {
                Text(verbatim: "The FunFitness Field Guide")
                Spacer()
                Text(verbatim: runningHead)
            }
            .ffFont(.label)
            .foregroundStyle(Color.ffInk)
            Rectangle().fill(Color.ffInk).frame(height: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Lead plate (HeroStat.md)

struct FieldGuideLeadPlate: View {
    let viewModel: AppViewModel
    let onTap: () -> Void

    private let type: ActivityType = .distance
    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        let total = viewModel.displayTotal(for: type)
        let fit = ReferenceUnitEngine.bestFit(total: viewModel.total(for: type), type: type, packId: viewModel.activePack.id)
        let next = viewModel.remainingToNextMilestone(type: type)
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: FFSpace.s3) {
                Text(verbatim: "Plate 01 · \(type.displayName)")
                    .ffFont(.label)
                    .foregroundStyle(type.ffFill)
                headline(total: total, fit: fit)
                if let milestone = next.milestone {
                    plate(for: milestone)
                    ruler(total: total, milestone: milestone, remaining: next.remaining)
                } else {
                    Text(verbatim: "Every distance plate observed.")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(verbatim: "Logs a distance entry"))
        .accessibilityIdentifier("fieldGuideLeadPlate")
    }

    /// "21.9 miles is roughly *2.4 honeybee flights to the flowers*." (italic rust comparison).
    @ViewBuilder
    private func headline(total: String, fit: ReferenceFit?) -> some View {
        if let fit {
            (Text(verbatim: "\(FieldGuideRules.totalInWords(total)) is roughly ")
             + Text(verbatim: "\(fit.countText) \(fit.unitText)").italic().foregroundColor(.ffAccent)
             + Text(verbatim: "."))
                .ffFont(.displayHero)
                .foregroundStyle(Color.ffInk)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(verbatim: "Log your first entry to begin the guide.")
                .ffFont(.display)
                .foregroundStyle(Color.ffInk)
        }
    }

    /// The next milestone as a plate: its pack figure in an outlined box, captioned "Fig. NN.".
    private func plate(for milestone: Milestone) -> some View {
        let pack = viewModel.activePack
        let emoji = milestone.getEmoji(for: pack)
        let number = FieldGuideRules.specimenNumber(milestone.id) ?? 0
        let name = FieldGuideRules.binomial(for: emoji, packId: pack.id)
        return VStack(alignment: .leading, spacing: FFSpace.s2) {
            Text(verbatim: emoji)
                .font(.system(size: 64))
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(Color.ffSurface)
                .overlay(Rectangle().strokeBorder(Color.ffLine, lineWidth: 1))
                .accessibilityHidden(true)
            Text(verbatim: "Fig. \(String(format: "%02d", number)). " + (name.map { "\($0). " } ?? "") + milestone.title(pref: pref))
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ruler(total: String, milestone: Milestone, remaining: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldGuideRuler(progress: viewModel.progressToNextMilestone(type: type), tint: type.ffFill)
            HStack {
                Text(verbatim: "\(total) logged")
                Spacer()
                Text(verbatim: "\(UnitConverter.displayString(remaining, type: type, pref: pref)) to go")
            }
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Color.ffInkMuted)
        }
    }
}

// MARK: - Specimen grid (StatTile.md, StreakCard.md)

struct FieldGuideSpecimenGrid: View {
    let viewModel: AppViewModel
    let onLog: (ActivityType) -> Void
    let onUseShield: () -> Void

    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        // Weight always; time and reps once they have data (as today's tiles).
        let types = [ActivityType.weight] + [.duration, .reps].filter { viewModel.total(for: $0) > 0 }
        let cells: [AnyView] = types.map { type in AnyView(typeCell(type)) } + [AnyView(streakCell)]
        let rows = stride(from: 0, to: cells.count, by: 2).map { Array(cells[$0..<min($0 + 2, cells.count)]) }
        VStack(spacing: 0) {
            Rectangle().fill(Color.ffLine).frame(height: 1)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 0) {
                    row[0].frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(Color.ffLine).frame(width: 1)
                    Group {
                        if row.count > 1 { row[1] } else { Color.clear }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Color.ffLine).frame(height: 1)
            }
        }
    }

    private func typeCell(_ type: ActivityType) -> some View {
        let next = viewModel.remainingToNextMilestone(type: type)
        return Button { onLog(type) } label: {
            VStack(alignment: .leading, spacing: FFSpace.s2) {
                // Colour on the label and bar only; the numeral stays ink (StatTile.md).
                Text(verbatim: type.displayName)
                    .ffFont(.label)
                    .foregroundStyle(type.ffFill)
                Text(verbatim: viewModel.displayTotal(for: type))
                    .ffFont(.display)
                    .foregroundStyle(Color.ffInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                FieldGuideRuler(progress: viewModel.progressToNextMilestone(type: type), tint: type.ffFill)
                if next.remaining > 0 {
                    Text(verbatim: "\(UnitConverter.displayString(next.remaining, type: type, pref: pref)) to go")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.ffInkMuted)
                }
            }
            .padding(FFSpace.s3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var streakCell: some View {
        let weeks = viewModel.currentStreak
        let canUseShield = viewModel.shieldsAvailable > 0 && !viewModel.isActiveThisWeekStreak && weeks > 0
        return VStack(alignment: .leading, spacing: FFSpace.s2) {
            Text(verbatim: "Streak")
                .ffFont(.label)
                .foregroundStyle(Color.ffStreak)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(weeks)")
                    .ffFont(.display)
                    .foregroundStyle(Color.ffStreak)
                Text(verbatim: weeks == 1 ? "week running" : "weeks running")
                    .ffFont(.body)
                    .foregroundStyle(Color.ffInk)
            }
            FieldGuideTally(count: weeks)
            Text(verbatim: "Best \(viewModel.longestStreak) · \(viewModel.shieldsAvailable) streak shield\(viewModel.shieldsAvailable == 1 ? "" : "s")")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
            if canUseShield {
                Button(action: onUseShield) {
                    Text(verbatim: "Use a shield to cover this week")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffAccent)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FFSpace.s3)
        .accessibilityElement(children: .contain)
    }
}

/// Weeks as tally marks in `streak`: groups of five with a strike, capped at 10, then "+N".
struct FieldGuideTally: View {
    let count: Int

    var body: some View {
        let shown = min(count, 10)
        HStack(spacing: 8) {
            ForEach(0..<Int((Double(shown) / 5).rounded(.up)), id: \.self) { group in
                let inGroup = min(5, shown - group * 5)
                Canvas { context, size in
                    for i in 0..<min(inGroup, 4) {
                        let x = 2 + CGFloat(i) * 5
                        var stroke = Path()
                        stroke.move(to: CGPoint(x: x, y: 1))
                        stroke.addLine(to: CGPoint(x: x, y: size.height - 1))
                        context.stroke(stroke, with: .color(.ffStreak), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    }
                    if inGroup == 5 {
                        var strike = Path()
                        strike.move(to: CGPoint(x: 0, y: size.height - 3))
                        strike.addLine(to: CGPoint(x: 19, y: 3))
                        context.stroke(strike, with: .color(.ffStreak), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    }
                }
                .frame(width: 20, height: 16)
            }
            if count > 10 {
                Text(verbatim: "+\(count - 10)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.ffStreak)
            }
        }
        .frame(minHeight: 16)
        .accessibilityHidden(true)
    }
}

// MARK: - Title page (RankCard.md)

struct FieldGuideTitlePage: View {
    let viewModel: AppViewModel
    let unlockedIds: Set<String>

    var body: some View {
        let title = SillyTitleEngine.sillyTitle(unlockedIds: unlockedIds)
        let level = SillyTitleEngine.level(unlockedIds: unlockedIds)
        VStack(spacing: FFSpace.s2) {
            Text(verbatim: "being the field notes of \(FieldGuideRules.article(for: title.title))")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
            Text(verbatim: title.title)
                .ffFont(.display)
                .foregroundStyle(Color.ffInk)
                .multilineTextAlignment(.center)
            Text(verbatim: "\(title.rank) rank · \(unlockedIds.count) of \(ComparisonEngine.allMilestones.count) observed")
                .ffFont(.label)
                .foregroundStyle(Color.ffAccent2)
            if let nextRank = level.nextRank {
                Text(verbatim: "\(level.badgesToNext) badge\(level.badgesToNext == 1 ? "" : "s") to \(nextRank)")
                    .ffFont(.body)
                    .foregroundStyle(Color.ffInk)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FFSpace.s5)
        .background(Color.ffSurface)
        // Double hairline frame: border plus an inset outline.
        .overlay(Rectangle().strokeBorder(Color.ffLine, lineWidth: 1))
        .overlay(Rectangle().strokeBorder(Color.ffLine, lineWidth: 1).padding(4))
        .overlay(alignment: .topTrailing) {
            ArcadeShareButton(
                content: .title(viewModel.sillyTitle, badgeCount: unlockedIds.count),
                filename: "funfitness_title.png"
            )
            .padding(FFSpace.s3)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Field notes (Ticker.md)

struct FieldGuideFieldNotes: View {
    let viewModel: AppViewModel

    var body: some View {
        let lines = ActivityType.allCases.compactMap { viewModel.absurdityTickerText(for: $0) }
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: FFSpace.s3) {
                Text(verbatim: "Field notes")
                    .ffFont(.label)
                    .foregroundStyle(Color.ffInk)
                Rectangle().fill(Color.ffLine).frame(height: 1)
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: FFSpace.s3) {
                        Text(verbatim: "\(FieldGuideRules.roman(index + 1)).")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.ffInkMuted)
                            .frame(width: 30, alignment: .trailing)
                        // Printed exactly as ReferenceUnit writes them, emoji included.
                        Text(verbatim: line)
                            .ffFont(.body)
                            .foregroundStyle(Color.ffInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("absurdityTicker")
        }
    }
}

#endif
