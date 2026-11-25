//
//  ArcadeChrome.swift
//  FunFitness
//
//  Arcade's dock (3.3): the TabBar (HOME · STATS · CARDS · YOU, selected = accent text + 2px
//  underline) and the square gradient LogButton. Specs: docs/design/arcade/components/TabBar.md and
//  LogButton.md. `FFTabBar` and `LogButton` switch to these when Arcade is active.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI

extension AppTab {
    /// Arcade renames two tabs; the views behind them don't change (TabBar.md).
    var arcadeLabel: String {
        switch self {
        case .home: return "Home"
        case .progress: return "Stats"
        case .badges: return "Cards"
        #if INTERNAL_SOCIAL
        case .friends: return "Squad"
        #endif
        case .you: return "You"
        }
    }
}

struct ArcadeTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FFRadius.lg, style: .continuous)
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == selection
                if tab != AppTab.allCases.first { Spacer(minLength: 0) }
                Button {
                    selection = tab
                } label: {
                    // The underline marks the tab without relying on colour alone. It's an overlay
                    // sized to the word; as a stacked Rectangle it stretched its tab.
                    Text(verbatim: tab.arcadeLabel)
                        .ffFont(.tab)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: !AppTab.isCrowded, vertical: false)
                        .foregroundStyle(isSelected ? Color.ffAccent : Color.ffInk)
                        .padding(.bottom, 5)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isSelected ? Color.ffAccent : .clear)
                                .frame(height: 2)
                        }
                        .padding(.horizontal, AppTab.isCrowded ? FFSpace.s1 : FFSpace.s2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: tab.arcadeLabel))
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("tab_\(tab.label)")
            }
        }
        .padding(.horizontal, FFSpace.s3)
        .padding(.vertical, FFSpace.s1)
        .background(Color.ffSurface, in: shape)
        .overlay(shape.strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "Tabs"))
    }
}

/// The LogButton's face in Arcade: a square of the brand gradient with a heavy "+" (no text).
struct ArcadeLogButtonFace: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FFRadius.md, style: .continuous)
        Image(systemName: "plus")
            .font(.system(size: 26, weight: .heavy))
            .foregroundStyle(Color.ffOnGradient)
            .frame(width: 60, height: 60)
            .background(Color.ffBrandGradient, in: shape)
            .contentShape(shape)
    }
}

#endif
