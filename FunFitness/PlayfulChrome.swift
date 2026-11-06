//
//  PlayfulChrome.swift
//  FunFitness
//
//  The structural pieces of the Playful Bold Style (3.2), from docs/design/playful-bold/components:
//  the floating word-only TabBar with the LogButton beside it (answers TestFlight D1), and Home's
//  HeroStat and StatTile. ContentView and HomeView place them; tokens come from Shared/Style.swift.
//

import SwiftUI

// MARK: - Tabs

/// The four tabs. Labels are shortened so they fit at large text sizes (TabBar.md).
enum AppTab: Int, CaseIterable, Identifiable {
    case home, progress, badges, you

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .home:     return "Home"
        case .progress: return "Progress"
        case .badges:   return "Badges"
        case .you:      return "You"
        }
    }

    /// For the system tab bar used at accessibility text sizes.
    var symbol: String {
        switch self {
        case .home:     return "house"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .badges:   return "trophy"
        case .you:      return "person.circle"
        }
    }
}

/// Floating pill of word tabs; the selected one sits on a brand-yellow pill.
struct FFTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        // Tabs size to their words (equal widths truncated "Progress"); spare room goes between them.
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == selection
                if tab != AppTab.allCases.first { Spacer(minLength: 0) }
                Button {
                    selection = tab
                } label: {
                    Text(tab.label)
                        .ffFont(.tab)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(isSelected ? Color.ffOnAccent : Color.ffInk)
                        .padding(.horizontal, FFSpace.s2 + 2)
                        .frame(minHeight: 44)
                                .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.ffBrandYellow)
                                    .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("tab_\(tab.label)")
            }
        }
        .padding(FFSpace.s1 + 2)
        .background(Color.ffSurface, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
        .background(Capsule().fill(Color.ffShadowInk).offset(x: FFShadow.pop, y: FFShadow.pop))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }
}

/// The round pink "+" (LogButton.md). Tap opens the log sheet on the last-used type; long-press
/// offers each type and Repeat last.
struct LogButton: View {
    let onLog: (ActivityType?) -> Void
    let repeatLastLabel: String?
    let onRepeatLast: () -> Void

    var body: some View {
        Menu {
            ForEach(ActivityType.allCases, id: \.self) { type in
                Button("Log \(type.displayName.lowercased())", systemImage: type.symbolName) { onLog(type) }
            }
            if let repeatLastLabel {
                Divider()
                Button("Repeat last: \(repeatLastLabel)", systemImage: "arrow.counterclockwise", action: onRepeatLast)
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.ffOnAccent)
                .frame(width: 64, height: 64)
                .background(Color.ffAccent, in: .circle)
                .overlay(Circle().strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
                .background(Circle().fill(Color.ffShadowInk).offset(x: FFShadow.pop, y: FFShadow.pop))
                .contentShape(.circle)
        } primaryAction: {
            onLog(nil)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Log an activity")
        .accessibilityHint("Touch and hold for more options")
        .accessibilityIdentifier("logButton")
    }
}

// MARK: - Home: HeroStat and StatTile

extension ReferenceFit {
    /// The count alone, formatted like `phrase` ("2.4").
    var countText: String {
        phrase.components(separatedBy: " ").first ?? ""
    }

    /// The unit words after the count ("honeybee flights to the flowers").
    var unitText: String {
        String(phrase.dropFirst(countText.count)).trimmingCharacters(in: .whitespaces)
    }
}

/// The one big Home card (HeroStat.md): the giant reference count, the unit as the punchline, the
/// real total and progress to the next milestone.
struct HeroStat: View {
    let viewModel: AppViewModel
    let type: ActivityType
    let onTap: () -> Void

    private var pref: UnitPreference { viewModel.unitPreference }

    var body: some View {
        let fit = ReferenceUnitEngine.bestFit(total: viewModel.total(for: type), type: type, packId: viewModel.activePack.id)
        let next = viewModel.remainingToNextMilestone(type: type)
        let total = viewModel.displayTotal(for: type)

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: FFSpace.s3) {
                FFTag(text: type.tagText, fill: type.ffFill, foreground: type.ffOnFill)

                if let fit {
                    HStack(alignment: .center) {
                        Text(fit.countText)
                            .ffFont(.displayHero)
                            .foregroundStyle(Color.ffInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer(minLength: FFSpace.s2)
                        // Pack illustration stand-in: the unit's emoji in an outlined circle.
                        Text(fit.unit.emoji)
                            .font(.system(size: 40))
                            .frame(width: 72, height: 72)
                            .background(Color.ffSurfaceAlt, in: .circle)
                            .overlay(Circle().strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
                            .accessibilityHidden(true)
                    }
                    Text("\(fit.unitText)!")
                        .ffFont(.title)
                        .foregroundStyle(Color.ffInk)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Log your first \(type.displayName.lowercased()) to start the comparisons!")
                        .ffFont(.title)
                        .foregroundStyle(Color.ffInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(subline(total: total, next: next.milestone?.title(pref: pref)))
                    .ffFont(.body)
                    .foregroundStyle(Color.ffInkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                SwiftUI.ProgressView(value: viewModel.progressToNextMilestone(type: type))
                    .progressViewStyle(FFMeterStyle(fill: type.ffFill))
                    .accessibilityHidden(true)

                if next.remaining > 0 {
                    Text("\(UnitConverter.displayString(next.remaining, type: type, pref: pref)) to go")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffInkMuted)
                }
            }
            .ffCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(fit: fit, total: total, next: next.milestone?.title(pref: pref)))
        .accessibilityHint("Logs a \(type.displayName.lowercased()) activity")
        .accessibilityIdentifier("\(type.rawValue)HeroStat")
    }

    private func subline(total: String, next: String?) -> String {
        if let next {
            let end = next.last.map { "!?.".contains($0) } == true ? "" : "."
            return "\(total) logged. Next stop: \(next)\(end)"
        }
        return "\(total) logged. Every milestone done!"
    }

    private func accessibilityText(fit: ReferenceFit?, total: String, next: String?) -> String {
        let joke = fit.map { "\($0.phrase)! " } ?? ""
        return joke + subline(total: total, next: next)
    }
}

/// A full-colour tile for a secondary type (StatTile.md): total on the left, comparison on the right.
struct StatTile: View {
    let viewModel: AppViewModel
    let type: ActivityType
    let onTap: () -> Void

    private var label: String {
        switch type {
        case .distance: return "Distance"
        case .weight:   return "Weight lifted"
        case .duration: return "Time moving"
        case .reps:     return "Reps"
        }
    }

    var body: some View {
        let fit = ReferenceUnitEngine.bestFit(total: viewModel.total(for: type), type: type, packId: viewModel.activePack.id)
        let total = viewModel.displayTotal(for: type)

        Button(action: onTap) {
            HStack(alignment: .top, spacing: FFSpace.s4) {
                VStack(alignment: .leading, spacing: FFSpace.s1) {
                    Text(label).ffFont(.label)
                    Text(total)
                        .ffFont(.numeral)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer(minLength: FFSpace.s2)
                if let fit {
                    Text("\(fit.phrase)! \(fit.unit.emoji)")
                        .ffFont(.headline)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(type.ffOnFill)
            .ffCard(padding: FFSpace.s5, radius: FFRadius.md, fill: type.ffFill)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(total)" + (fit.map { ". \($0.phrase)!" } ?? ""))
        .accessibilityHint("Logs a \(type.displayName.lowercased()) activity")
        .accessibilityIdentifier("\(type.rawValue)StatTile")
    }
}
