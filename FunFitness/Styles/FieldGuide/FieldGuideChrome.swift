//
//  FieldGuideChrome.swift
//  FunFitness
//
//  Field Guide's dock (3.3): text tabs GUIDE · PROGRESS · COLLECTION · PROFILE under a 2px ink
//  rule (active = accent, semibold, 2px accent underline), and the full-width ink "Log an entry"
//  bar above them on Guide only. Specs: docs/design/field-guide/components/TabBar.md, LogButton.md.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI

extension AppTab {
    /// The guide's names; the views behind them don't change (TabBar.md).
    var fieldGuideLabel: String {
        switch self {
        case .home: return "Guide"
        case .progress: return "Progress"
        case .badges: return "Collection"
        case .you: return "Profile"
        }
    }
}

struct FieldGuideTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        VStack(spacing: 0) {
            // rule-heavy: pairs with the masthead rule.
            Rectangle().fill(Color.ffInk).frame(height: 2)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    let isSelected = tab == selection
                    if tab != AppTab.allCases.first { Spacer(minLength: 0) }
                    Button {
                        selection = tab
                    } label: {
                        VStack(spacing: 4) {
                            Text(verbatim: tab.fieldGuideLabel)
                                .ffFont(.tab)
                                .fontWeight(isSelected ? .semibold : .medium)
                                .lineLimit(1)
                                .fixedSize()
                                .foregroundStyle(isSelected ? Color.ffAccent : Color.ffInk)
                            Rectangle()
                                .fill(isSelected ? Color.ffAccent : .clear)
                                .frame(height: 2)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: tab.fieldGuideLabel))
                    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                    .accessibilityIdentifier("tab_\(tab.label)")
                }
            }
            .padding(.top, FFSpace.s2)
        }
        .background(Color.ffBg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "Tabs"))
    }
}

/// The LogButton's face in the guide: a full-width square ink bar, "Log an entry", with the
/// repeat-last line as a mono sub-label. Never rust (rust marks progress).
struct FieldGuideLogBarFace: View {
    let repeatLastLabel: String?

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: "Log an entry")
                .font(.system(size: 20, weight: .bold, design: .serif))
            if let repeatLastLabel {
                Text(verbatim: "Hold to repeat: \(repeatLastLabel)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .opacity(0.8)
            }
        }
        .foregroundStyle(Color.ffOnInk)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color.ffInk, in: Rectangle())
        .contentShape(Rectangle())
    }
}

#endif
