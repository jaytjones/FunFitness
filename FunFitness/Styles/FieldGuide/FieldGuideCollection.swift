//
//  FieldGuideCollection.swift
//  FunFitness
//
//  Field Guide's Collection tab (3.3): every milestone as a catalogued specimen, No. 01–42 in
//  milestone order. Observed specimens show the figure, title, comparison and "Observed <date>";
//  unobserved ones are dashed empty frames with the requirement (no comparison — it spoils the
//  reveal). Spec: docs/design/field-guide/components/BadgeTile.md. Tap an observed specimen for its
//  page, with the share icon in the top-right corner (Jay, 2026-11-15).
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI

struct FieldGuideCollection: View {
    let achievements: [UnlockedAchievement]
    let viewModel: AppViewModel

    @State private var detail: Milestone?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 2)
    private var pref: UnitPreference { viewModel.unitPreference }

    private var observed: [String: Date] {
        Dictionary(achievements.map { ($0.milestoneId, $0.unlockedAt) }, uniquingKeysWith: min)
    }

    var body: some View {
        let dates = observed
        VStack(alignment: .leading, spacing: FFSpace.s5) {
            FieldGuideMasthead(runningHead: "Collection")
            Text(verbatim: "\(dates.count) of \(ComparisonEngine.allMilestones.count) specimens observed")
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)
            FieldGuideRuler(progress: Double(dates.count) / Double(max(1, ComparisonEngine.allMilestones.count)), tint: .ffAccent2)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(ComparisonEngine.allMilestones.enumerated()), id: \.element.id) { index, milestone in
                    Button {
                        if dates[milestone.id] != nil { detail = milestone }
                    } label: {
                        FieldGuideSpecimen(
                            number: index + 1,
                            milestone: milestone,
                            emoji: milestone.getEmoji(for: viewModel.activePack),
                            comparison: milestone.getComparison(for: viewModel.activePack),
                            observedAt: dates[milestone.id],
                            requirement: ArcadeBinder.requirement(milestone, pref: pref),
                            pref: pref
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $detail) { milestone in
            FieldGuideSpecimenPage(
                number: FieldGuideRules.specimenNumber(milestone.id) ?? 0,
                milestone: milestone,
                pack: viewModel.activePack,
                pref: pref,
                observedAt: observed[milestone.id]
            )
            .presentationDetents([.medium, .large])
        }
    }
}

struct FieldGuideSpecimen: View {
    let number: Int
    let milestone: Milestone
    let emoji: String
    let comparison: String
    let observedAt: Date?
    let requirement: String
    let pref: UnitPreference

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpace.s2) {
            Text(verbatim: String(format: "No. %02d", number))
                .ffFont(.label)
                .foregroundStyle(observedAt == nil ? Color.ffInkMuted : Color.ffAccent)
            frame
            if let observedAt {
                Text(verbatim: milestone.title(pref: pref))
                    .ffFont(.bodyStrong)
                    .foregroundStyle(Color.ffInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: comparison)
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
                    .lineLimit(3)
                Text(verbatim: "Observed \(observedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.ffAccent2)
            } else {
                Text(verbatim: "Not yet observed")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
                Text(verbatim: "\(requirement) to unlock")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.ffInkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(FFSpace.s3)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .background(observedAt == nil ? Color.clear : Color.ffSurface)
        .overlay {
            if observedAt == nil {
                Rectangle().strokeBorder(Color.ffInkMuted, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .padding(2)
            } else {
                Rectangle().strokeBorder(Color.ffLine, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: observedAt == nil
            ? "Number \(number), not yet observed. \(requirement) to unlock."
            : "Number \(number). \(milestone.title(pref: pref)). \(comparison)"))
    }

    /// Observed: the figure centred in an outlined frame. Unobserved: an empty frame with a
    /// diagonal — no drawing yet (never a greyed-out one).
    @ViewBuilder
    private var frame: some View {
        if observedAt != nil {
            Text(verbatim: emoji)
                .font(.system(size: 40))
                .frame(maxWidth: .infinity, minHeight: 80)
                .overlay(Rectangle().strokeBorder(Color.ffLine, lineWidth: 1))
                .accessibilityHidden(true)
        } else {
            Canvas { context, size in
                var diagonal = Path()
                diagonal.move(to: CGPoint(x: 0, y: size.height))
                diagonal.addLine(to: CGPoint(x: size.width, y: 0))
                context.stroke(diagonal, with: .color(.ffInkMuted), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .overlay(Rectangle().strokeBorder(Color.ffInkMuted, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .accessibilityHidden(true)
        }
    }
}

/// A specimen's own page, with the share icon in the top-right corner.
private struct FieldGuideSpecimenPage: View {
    let number: Int
    let milestone: Milestone
    let pack: ThemePack
    let pref: UnitPreference
    let observedAt: Date?

    var body: some View {
        let emoji = milestone.getEmoji(for: pack)
        let name = FieldGuideRules.binomial(for: emoji, packId: pack.id)
        VStack(alignment: .leading, spacing: FFSpace.s4) {
            Text(verbatim: String(format: "Specimen No. %02d", number))
                .ffFont(.label)
                .foregroundStyle(Color.ffAccent)
            Text(verbatim: milestone.title(pref: pref))
                .ffFont(.display)
                .foregroundStyle(Color.ffInk)
            Text(verbatim: emoji)
                .font(.system(size: 72))
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color.ffSurface)
                .overlay(Rectangle().strokeBorder(Color.ffLine, lineWidth: 1))
                .accessibilityHidden(true)
            Text(verbatim: "Fig. \(String(format: "%02d", number)). " + (name.map { "\($0). " } ?? "") + milestone.getComparison(for: pack))
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let observedAt {
                Text(verbatim: "Observed \(observedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.ffAccent2)
            }
            Spacer(minLength: 0)
        }
        .padding(FFSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if observedAt != nil {
                ArcadeShareButton(content: .milestone(milestone, pack: pack, pref: pref), filename: "funfitness_milestone.png")
                    .padding(FFSpace.s4)
            }
        }
        .background(Color.ffBg.ignoresSafeArea())
    }
}

#endif
