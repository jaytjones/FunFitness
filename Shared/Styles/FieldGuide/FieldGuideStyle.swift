//
//  FieldGuideStyle.swift
//  FunFitness (Shared/: compiled into the app and the widget extension)
//
//  Field Guide (3.3): FunFitness as a naturalist's field guide — quiet ink on parchment, rules
//  instead of cards, square corners, numbered plates and specimens. "Daylight" is the light
//  appearance (primary), "Lamplight" the dark. Values from docs/design/field-guide/tokens.json.
//
//  UNRELEASED — Jay-only. Compiled only with INTERNAL_STYLES (see ArcadeStyle.swift).
//
//  Fonts: the spec calls for Fraunces / Newsreader / IBM Plex Mono. Following Arcade's choice
//  (2026-11-15), system stand-ins for now: New York (serif) for display and body, SF Mono for
//  labels, tabs and data.
//

#if INTERNAL_STYLES

import SwiftUI

// MARK: - Shared tokens in Field Guide

extension FFColorToken {
    /// Daylight (light) / Lamplight (dark), or nil to use Playful Bold's.
    nonisolated var fieldGuide: (light: UInt32, dark: UInt32)? {
        switch self {
        case .bg: return (0xEDE5D0, 0x1A1813)
        case .surface: return (0xF5F0E3, 0x24211B)
        case .surfaceAlt: return (0xE2D8BC, 0x2F2B23)
        case .ink: return (0x23211C, 0xEDE5D0)
        case .inkMuted: return (0x5C5546, 0xB3A98F)
        case .line: return (0x23211C, 0x9C927B)
        case .accent: return (0xA63D27, 0xE58A6E)
        case .onAccent: return (0xF5F0E3, 0x1A1813)
        case .accent2: return (0x4A6B3A, 0x9DBE88)
        case .onAccent2: return (0xF5F0E3, 0x1A1813)
        // Links are rust (accent), which is text-safe on bg and surface.
        case .link: return (0xA63D27, 0xE58A6E)
        case .typeDistance: return (0xA63D27, 0xE58A6E)
        case .onTypeDistance: return (0xF5F0E3, 0x1A1813)
        case .typeWeight: return (0x4A6B3A, 0x9DBE88)
        case .onTypeWeight: return (0xF5F0E3, 0x1A1813)
        case .typeDuration: return (0x3D5873, 0x93AFCC)
        case .onTypeDuration: return (0xF5F0E3, 0x1A1813)
        case .typeReps: return (0x7D5A12, 0xD6AE5A)
        case .onTypeReps: return (0xF5F0E3, 0x1A1813)
        case .progressTrack: return (0x8C826C, 0x7D7462)
        case .streak: return (0x8A4A12, 0xE0A25C)
        case .success: return (0x3F5F31, 0x9DBE88)
        case .danger: return (0x9A2A1C, 0xF08A7A)
        case .focus: return (0x2F5D8A, 0x8FB8E6)
        // Not in Field Guide's tokens. Selected chips invert to ink (README "States"), so the
        // brand-yellow chip fill becomes ink; the heat map is redrawn as stipple (Stats).
        case .brandYellow: return (0x23211C, 0xEDE5D0)
        case .heat1: return (0xE2D8BC, 0x2F2B23)
        case .heat2: return (0x8C826C, 0x7D7462)
        case .heat3: return (0xA63D27, 0xE58A6E)
        // No shadows in the guide.
        case .shadowInk: return nil
        }
    }
}

// MARK: - Field Guide-only tokens

extension Color {
    /// Text on an `ink` fill (the Log an entry bar, inverted chips).
    nonisolated static let ffOnInk = FFColor.dynamic(0xF5F0E3, 0x1A1813)
    // Lock Screen Live Activity: fixed across appearances (it sits on dark system material).
    nonisolated static let ffLiveGround = FFColor.dynamic(0x1F1D19, 0x1F1D19)
    nonisolated static let ffLiveInk = FFColor.dynamic(0xF2EBDA, 0xF2EBDA)
    nonisolated static let ffLiveInkMuted = FFColor.dynamic(0xB8AE95, 0xB8AE95)
    nonisolated static let ffLiveAccent = FFColor.dynamic(0xEB9377, 0xEB9377)
}

// MARK: - Type

extension FFTextStyle {
    nonisolated var fieldGuideSize: CGFloat {
        switch self {
        case .displayHero, .numeral: return 40
        case .display: return 30
        case .title: return 22
        case .headline: return 19
        case .body, .bodyStrong: return 17
        case .caption: return 15
        case .tab: return 13
        case .label: return 12
        }
    }

    nonisolated var fieldGuideWeight: Font.Weight {
        switch self {
        case .displayHero, .display, .numeral: return .heavy
        case .title: return .bold
        case .headline, .bodyStrong: return .semibold
        case .body, .caption: return .regular
        case .label, .tab: return .medium
        }
    }

    nonisolated var fieldGuideTracking: CGFloat {
        switch self {
        case .displayHero: return -0.015 * 40
        case .display: return -0.01 * 30
        case .numeral: return -0.01 * 40
        case .label: return 0.14 * 12
        case .tab: return 0.12 * 13
        default: return 0
        }
    }

    /// Labels and tabs are uppercase mono; everything else keeps the app's casing.
    nonisolated var fieldGuideIsUppercase: Bool {
        self == .label || self == .tab
    }

    /// New York (serif) for display and body, SF Mono for labels and tabs.
    nonisolated var fieldGuideDesign: Font.Design {
        (self == .label || self == .tab) ? .monospaced : .serif
    }

    /// Figure captions are italic.
    nonisolated var fieldGuideIsItalic: Bool {
        self == .caption
    }
}

// MARK: - Progress: the ruler

/// The guide's progress mark (README "Progress: the ruler"): ticks in `line` (minor every 5%,
/// major every 25%) over a solid bar in the type colour; the unfilled length is a 1px track rule.
/// Never a rounded pill.
struct FieldGuideRuler: View {
    let progress: Double
    let tint: Color

    var body: some View {
        let fraction = min(1, max(0, progress))
        VStack(spacing: 0) {
            Canvas { context, size in
                for i in 0...20 {
                    let x = min(size.width - 0.5, max(0.5, size.width * CGFloat(i) / 20))
                    let major = i % 5 == 0
                    let height: CGFloat = major ? size.height : size.height * 0.55
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: size.height))
                    tick.addLine(to: CGPoint(x: x, y: size.height - height))
                    context.stroke(tick, with: .color(.ffLine), lineWidth: major ? 1.5 : 1)
                }
            }
            .frame(height: 9)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.ffProgressTrack).frame(height: 1)
                    Rectangle().fill(tint).frame(width: geometry.size.width * fraction, height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 8)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "\(Int((fraction * 100).rounded())) percent"))
    }
}

#endif
