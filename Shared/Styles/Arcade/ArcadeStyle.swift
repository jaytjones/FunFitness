//
//  ArcadeStyle.swift
//  FunFitness (Shared/: compiled into the app and the widget extension)
//
//  Arcade (3.3): a game-HUD look, dark-first. "Arcade" is the dark appearance, "Daylight" the light.
//  Values from docs/design/arcade/tokens.json (the source of truth; edit there first).
//
//  UNRELEASED — Jay-only. The whole file is compiled only with INTERNAL_STYLES (Debug and Internal
//  builds), so Release builds contain nothing of Arcade. Launch = remove this #if, set
//  `StyleID.arcade.isReleased`, move user-facing text into the string catalog.
//
//  Fonts (Jay, 2026-11-15): Chakra Petch Bold for headings (display-hero, display, title, tab) only;
//  SF Pro for body and numerals, SF Mono for HUD labels. The font file and its licence sit in
//  Fonts/ and are excluded from Release builds (EXCLUDED_SOURCE_FILE_NAMES), and it's registered at
//  launch rather than through Info.plist, so Release builds don't name it either.
//

#if INTERNAL_STYLES

import SwiftUI
import CoreText

// MARK: - Fonts

nonisolated enum ArcadeFonts {
    /// PostScript name of the bundled heading font.
    static let display = "ChakraPetch-Bold"

    private static let registration: Void = {
        guard let url = Bundle.main.url(forResource: "ChakraPetch-Bold", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    /// Registers the heading font once for this process (the app and the widget extension each call
    /// it at launch). Missing file → headings fall back to SF Pro.
    static func register() { _ = registration }
}

// MARK: - Shared tokens in Arcade

extension FFColorToken {
    /// Arcade's light (Daylight) / dark (Arcade) pair, or nil to use Playful Bold's.
    nonisolated var arcade: (light: UInt32, dark: UInt32)? {
        switch self {
        case .bg: return (0xF1EEFF, 0x0B0A1F)
        case .surface: return (0xFFFFFF, 0x14132E)
        case .surfaceAlt: return (0xE7E2FB, 0x1C1A3D)
        case .ink: return (0x14122B, 0xF4F2FF)
        case .inkMuted: return (0x514C80, 0xA9A5D6)
        case .line: return (0xD6D0F0, 0x2E2B5C)
        case .accent: return (0x087068, 0x3CF0E0)
        case .onAccent: return (0xFFFFFF, 0x0B0A1F)
        case .accent2: return (0xB0126E, 0xFF3CAC)
        case .onAccent2: return (0xFFFFFF, 0x0B0A1F)
        // Arcade's accent holds 4.5:1 as text in both appearances, so links use it.
        case .link: return (0x087068, 0x3CF0E0)
        case .typeDistance: return (0x087068, 0x3CF0E0)
        case .onTypeDistance: return (0xFFFFFF, 0x0B0A1F)
        case .typeWeight: return (0x7A5800, 0xFFD23F)
        case .onTypeWeight: return (0xFFFFFF, 0x0B0A1F)
        case .typeDuration: return (0x6D28D9, 0xA07CFF)
        case .onTypeDuration: return (0xFFFFFF, 0x0B0A1F)
        case .typeReps: return (0xB0126E, 0xFF3CAC)
        case .onTypeReps: return (0xFFFFFF, 0x0B0A1F)
        case .progressTrack: return (0xDAD4F5, 0x2A2752)
        case .streak: return (0xB0126E, 0xFF3CAC)
        case .success: return (0x0E6B34, 0x6EF0A0)
        case .danger: return (0xC2183F, 0xFF5C7A)
        case .focus: return (0x6D28D9, 0xFFD23F)
        // Not in Arcade's tokens: the brand yellow becomes `rank`, and the activity heat map steps
        // glow → gradient-mid → accent.
        case .brandYellow: return (0x7A5800, 0xFFD23F)
        case .heat1: return (0xD9CFFF, 0x3A2C8C)
        case .heat2: return (0x7C3AED, 0x8B5CF6)
        case .heat3: return (0x087068, 0x3CF0E0)
        // Arcade panels are flat; the hard shadow isn't drawn.
        case .shadowInk: return nil
        }
    }
}

// MARK: - Arcade-only tokens

extension Color {
    /// Meaningful borders (locked/empty slots, inputs, unselected chips): 3:1 on every ground.
    nonisolated static let ffLineStrong = FFColor.dynamic(0x7A74B3, 0x6E69B0)
    nonisolated static let ffRarityCommon = FFColor.dynamic(0x5E5A8C, 0xA6A3D1)
    nonisolated static let ffRarityRare = FFColor.dynamic(0x0B63C4, 0x4DA8FF)
    nonisolated static let ffRarityEpic = FFColor.dynamic(0x8A2BD6, 0xC77DFF)
    nonisolated static let ffRarityLegendary = FFColor.dynamic(0xA34F00, 0xFF9F1C)
    nonisolated static let ffOnRarity = FFColor.dynamic(0xFFFFFF, 0x0B0A1F)
    /// Centre of the radial fade behind card art. Never put text on it.
    nonisolated static let ffGlow = FFColor.dynamic(0xD9CFFF, 0x3A2C8C)
    nonisolated static let ffGradientStart = FFColor.dynamic(0x0A8A80, 0x3CF0E0)
    nonisolated static let ffGradientMid = FFColor.dynamic(0x7C3AED, 0x8B5CF6)
    nonisolated static let ffGradientEnd = FFColor.dynamic(0xC2177A, 0xFF3CAC)
    nonisolated static let ffOnGradient = FFColor.dynamic(0xFFFFFF, 0x0B0A1F)
    nonisolated static let ffRank = FFColor.dynamic(0x7A5800, 0xFFD23F)

    /// The one gradient (featured card border and LogButton only), at 135°.
    nonisolated static let ffBrandGradient = LinearGradient(
        colors: [.ffGradientStart, .ffGradientMid, .ffGradientEnd],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Type

extension FFTextStyle {
    nonisolated var arcadeSize: CGFloat {
        switch self {
        case .displayHero: return 34
        case .display: return 26
        case .numeral: return 36
        case .title: return 20
        case .headline: return 17
        case .tab: return 15
        case .body, .bodyStrong: return 16
        case .caption: return 13
        case .label: return 12
        }
    }

    nonisolated var arcadeWeight: Font.Weight {
        switch self {
        case .displayHero, .display, .title, .tab, .numeral: return .bold
        case .headline, .bodyStrong: return .semibold
        case .body, .caption: return .regular
        case .label: return .medium
        }
    }

    /// Letter spacing in points at the base size (tokens give it in em).
    nonisolated var arcadeTracking: CGFloat {
        switch self {
        case .displayHero: return 0.01 * 34
        case .display: return 0.02 * 26
        case .title: return 0.02 * 20
        case .tab: return 0.04 * 15
        case .numeral: return -0.01 * 36
        case .label: return 0.08 * 12
        default: return 0
        }
    }

    /// Display and HUD text is uppercase in Arcade.
    nonisolated var arcadeIsUppercase: Bool {
        switch self {
        case .displayHero, .display, .title, .tab, .label: return true
        default: return false
        }
    }

    /// SF Mono for HUD labels, SF Pro for everything else (headings use `arcadeFontName`).
    nonisolated var arcadeDesign: Font.Design {
        self == .label ? .monospaced : .default
    }

    /// Chakra Petch for headings; nil = system font.
    nonisolated var arcadeFontName: String? {
        switch self {
        case .displayHero, .display, .title, .tab: return ArcadeFonts.display
        default: return nil
        }
    }
}

#endif
