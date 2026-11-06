//
//  Style.swift
//  FunFitness (Shared/: compiled into the app and the widget extension)
//
//  Design tokens for the app's visual Style (3.2 "New Look"). Values come from
//  docs/design/playful-bold/tokens.json, the source of truth; edit them there first. "Style" is
//  the look of the app; "Theme" (`activeTheme`) is the comparison content pack — don't mix them.
//
//  Playful Bold is the only Style in 3.2 (Jay, 2026-11-06). Arcade and Field Guide use the same
//  token names (3.3), so views written against these keep working when more Styles arrive.
//
//  Color providers are `nonisolated`: UIKit resolves dynamic colors on whatever thread is
//  drawing, including SwiftUI's render thread (TestFlight FB-0002).
//

import SwiftUI
import UIKit

/// The visual Styles the app can show. Raw values are persisted (`UserProfile.activeStyleID`),
/// so never rename them.
nonisolated enum StyleID: String, CaseIterable, Sendable {
    case playfulBold = "playful-bold"

    static let `default`: StyleID = .playfulBold

    var displayName: String {
        switch self {
        case .playfulBold: return "Playful Bold"
        }
    }
}

// MARK: - Color tokens

nonisolated enum FFColor {
    /// A light/dark pair as one dynamic color (Sunny / After Dark).
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor(light, dark))
    }

    static func uiColor(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { traits in
            rgb(traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    // Grounds and text
    nonisolated static let ffBg = FFColor.dynamic(0xFFD43B, 0x17122E)
    nonisolated static let ffSurface = FFColor.dynamic(0xFFFFFF, 0x262051)
    nonisolated static let ffSurfaceAlt = FFColor.dynamic(0xFFF4C7, 0x1F1A42)
    nonisolated static let ffInk = FFColor.dynamic(0x1E1640, 0xFFF8E1)
    nonisolated static let ffInkMuted = FFColor.dynamic(0x4A4170, 0xC9C2EA)
    nonisolated static let ffLine = FFColor.dynamic(0x1E1640, 0x08060F)
    nonisolated static let ffShadowInk = FFColor.dynamic(0x1E1640, 0x08060F)

    // Brand and actions
    nonisolated static let ffBrandYellow = FFColor.dynamic(0xFFD43B, 0xFFD43B)
    nonisolated static let ffAccent = FFColor.dynamic(0xFF5C8A, 0xFF6E98)
    nonisolated static let ffOnAccent = FFColor.dynamic(0x1E1640, 0x1E1640)
    nonisolated static let ffAccent2 = FFColor.dynamic(0x6C3CE9, 0x8B66FF)
    nonisolated static let ffOnAccent2 = FFColor.dynamic(0xFFFFFF, 0x10082A)
    /// Text links and tinted glyphs on bg/surface. Not a tokens.json name: `accent` is never a
    /// text color, so links use `accent-2` in Sunny and `brand-yellow` in After Dark (the README's
    /// "links on surface (light only)" and "brand-yellow … greeting, focus" rules).
    nonisolated static let ffLink = FFColor.dynamic(0x6C3CE9, 0xFFD43B)

    // Activity types
    nonisolated static let ffTypeDistance = FFColor.dynamic(0xFF5C8A, 0xFF6E98)
    nonisolated static let ffOnTypeDistance = FFColor.dynamic(0x1E1640, 0x1E1640)
    nonisolated static let ffTypeWeight = FFColor.dynamic(0x6C3CE9, 0x8B66FF)
    nonisolated static let ffOnTypeWeight = FFColor.dynamic(0xFFFFFF, 0x10082A)
    nonisolated static let ffTypeDuration = FFColor.dynamic(0x14C8B4, 0x2ED8C3)
    nonisolated static let ffOnTypeDuration = FFColor.dynamic(0x1E1640, 0x1E1640)
    nonisolated static let ffTypeReps = FFColor.dynamic(0xFF9F43, 0xFFAD5C)
    nonisolated static let ffOnTypeReps = FFColor.dynamic(0x1E1640, 0x1E1640)

    // States and data
    nonisolated static let ffProgressTrack = FFColor.dynamic(0xEFEAFF, 0x3A3270)
    nonisolated static let ffStreak = FFColor.dynamic(0xFF6B35, 0xFF8A50)
    nonisolated static let ffSuccess = FFColor.dynamic(0x157A43, 0x5BD38A)
    nonisolated static let ffDanger = FFColor.dynamic(0xB4232A, 0xFF7B7B)
    nonisolated static let ffFocus = FFColor.dynamic(0x1E1640, 0xFFD43B)
    nonisolated static let ffHeat1 = FFColor.dynamic(0xFFE58A, 0x4A3A8C)
    nonisolated static let ffHeat2 = FFColor.dynamic(0xFFB3C8, 0x8A4A9C)
    nonisolated static let ffHeat3 = FFColor.dynamic(0xFF5C8A, 0xFF6E98)
}

// MARK: - Spacing, radius, stroke, shadow

nonisolated enum FFSpace {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let s12: CGFloat = 48
}

nonisolated enum FFRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 20
    static let lg: CGFloat = 32
    // radius-pill: use `.capsule`.
}

nonisolated enum FFStroke {
    static let card: CGFloat = 3
    static let control: CGFloat = 2.5
}

nonisolated enum FFShadow {
    /// shadow-pop: hard 6pt down-right, no blur.
    static let pop: CGFloat = 6
    /// shadow-press: what's left while pressed (the element moves 4pt).
    static let press: CGFloat = 2
}

// MARK: - Type

/// The type scale from tokens.json. Display styles use Fredoka, text styles Nunito; both fall back
/// to SF Pro Rounded, which is what ships until the fonts are bundled (see `FFFontFamily`).
nonisolated enum FFTextStyle: Sendable {
    case displayHero, display, numeral, title, headline
    case body, bodyStrong, caption, label

    var size: CGFloat {
        switch self {
        case .displayHero: return 88
        case .display, .numeral: return 40
        case .title: return 28
        case .headline: return 20
        case .body, .bodyStrong: return 17
        case .caption: return 14
        case .label: return 13
        }
    }

    var weight: Font.Weight {
        switch self {
        case .displayHero, .display, .numeral: return .bold
        case .title, .headline, .body: return .semibold
        case .bodyStrong, .label: return .heavy
        case .caption: return .bold
        }
    }

    /// The Dynamic Type style it scales with.
    var relativeTo: Font.TextStyle {
        switch self {
        case .displayHero, .display, .numeral: return .largeTitle
        case .title: return .title
        case .headline: return .title3
        case .body, .bodyStrong: return .body
        case .caption: return .footnote
        case .label: return .caption
        }
    }

    var isDisplay: Bool {
        switch self {
        case .displayHero, .display, .numeral, .title, .headline: return true
        default: return false
        }
    }

    /// Letter spacing in points at the base size.
    var tracking: CGFloat {
        switch self {
        case .displayHero: return -0.02 * 88
        case .display: return -0.01 * 40
        case .label: return 0.08 * 13
        default: return 0
        }
    }
}

/// Bundled font names, once the Fredoka/Nunito files are added to the app (OFL fonts). Until then
/// these are nil and the rounded system font is used, as the README's fallback allows.
nonisolated enum FFFontFamily {
    static let display: String? = nil   // e.g. "Fredoka"
    static let body: String? = nil      // e.g. "Nunito"
}

private struct FFFontModifier: ViewModifier {
    let style: FFTextStyle
    @ScaledMetric private var size: CGFloat

    init(_ style: FFTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(font)
            .tracking(style.tracking * size / style.size)
            .monospacedDigit()
            .textCase(style == .label ? .uppercase : nil)
    }

    private var font: Font {
        if let family = style.isDisplay ? FFFontFamily.display : FFFontFamily.body {
            return .custom(family, size: size).weight(style.weight)
        }
        return .system(size: size, weight: style.weight, design: .rounded)
    }
}

extension View {
    /// Applies a Playful Bold text style, scaled with Dynamic Type.
    func ffFont(_ style: FFTextStyle) -> some View {
        modifier(FFFontModifier(style))
    }
}

// MARK: - Surfaces

private struct FFCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var fill: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
            // Hard offset shadow: a solid copy of the shape behind, no blur.
            .background(shape.fill(Color.ffShadowInk).offset(x: FFShadow.pop, y: FFShadow.pop))
    }
}

extension View {
    /// A Playful Bold card: surface fill, 3pt ink outline, hard 6pt shadow.
    func ffCard(padding: CGFloat = FFSpace.s6, radius: CGFloat = FFRadius.lg, fill: Color = .ffSurface) -> some View {
        modifier(FFCardModifier(padding: padding, radius: radius, fill: fill))
    }

    /// A recessed well inside a card (text fields, steppers): surface-alt, control outline.
    func ffWell(radius: CGFloat = FFRadius.md) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(Color.ffSurfaceAlt, in: shape)
            .overlay(shape.strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
    }
}

// MARK: - Buttons

/// Pill button with a hard shadow that presses down on touch. `.primary` is the accent action
/// ("Log It"); `.secondary` is a surface button; `.destructive` is danger text on surface.
struct FFButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        FFButtonBody(configuration: configuration, kind: kind)
    }
}

private struct FFButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: FFButtonStyle.Kind
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pressed = configuration.isPressed && isEnabled
        let offset = pressed ? FFShadow.pop - FFShadow.press : 0
        configuration.label
            .ffFont(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, FFSpace.s5)
            .background(background, in: .capsule)
            .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.card))
            .background(
                Capsule().fill(Color.ffShadowInk)
                    .offset(x: isEnabled ? FFShadow.pop - offset : 0, y: isEnabled ? FFShadow.pop - offset : 0)
                    .opacity(isEnabled ? 1 : 0)
            )
            .offset(x: offset, y: offset)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
            .contentShape(.capsule)
    }

    private var background: Color {
        switch kind {
        case .primary: return .ffAccent
        case .secondary, .destructive: return .ffSurface
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .ffOnAccent
        case .secondary: return .ffInk
        case .destructive: return .ffDanger
        }
    }
}

extension ButtonStyle where Self == FFButtonStyle {
    static var ffPrimary: FFButtonStyle { FFButtonStyle(kind: .primary) }
    static var ffSecondary: FFButtonStyle { FFButtonStyle(kind: .secondary) }
    static var ffDestructive: FFButtonStyle { FFButtonStyle(kind: .destructive) }
}

// MARK: - Meter and tag

/// ProgressMeter: an outlined pill track with a colored fill.
struct FFMeterStyle: ProgressViewStyle {
    var fill: Color = .ffAccent
    var height: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        let fraction = min(1, max(0, configuration.fractionCompleted ?? 0))
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ffProgressTrack)
                Capsule()
                    .fill(fill)
                    .frame(width: max(fraction > 0 ? height : 0, geometry.size.width * fraction))
                    .animation(.easeInOut(duration: 0.6), value: fraction)
            }
            .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
        }
        .frame(height: height)
    }
}

/// An uppercase tag tilted -2°, on a type or accent fill.
struct FFTag: View {
    let text: String
    var fill: Color = .ffAccent
    var foreground: Color = .ffOnAccent

    var body: some View {
        Text(text)
            .ffFont(.label)
            .foregroundStyle(foreground)
            .padding(.horizontal, FFSpace.s3)
            .padding(.vertical, FFSpace.s1)
            .background(fill, in: .capsule)
            .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
            .rotationEffect(.degrees(-2))
    }
}
