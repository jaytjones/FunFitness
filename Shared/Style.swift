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
import Synchronization

/// The visual Styles the app can show. Raw values are persisted (`UserProfile.activeStyleID`),
/// so never rename them.
nonisolated enum StyleID: String, CaseIterable, Sendable {
    case playfulBold = "playful-bold"
    #if INTERNAL_STYLES
    // Unreleased (Jay-only until launch): see Styles/Arcade/ArcadeStyle.swift.
    case arcade = "arcade"
    #endif

    static let `default`: StyleID = .playfulBold

    var displayName: String {
        switch self {
        case .playfulBold: return "Playful Bold"
        #if INTERNAL_STYLES
        case .arcade: return "Arcade"
        #endif
        }
    }

    /// Shown to everyone. An unreleased Style is compiled only into Debug/Internal builds
    /// (`INTERNAL_STYLES`) and, even there, shown only to the owner. Launching one = flipping this
    /// and removing its `#if`. (3.3 plan)
    var isReleased: Bool {
        switch self {
        case .playfulBold: return true
        #if INTERNAL_STYLES
        case .arcade: return false
        #endif
        }
    }

    /// Weeks of longest-ever streak that unlock this Style: Arcade 4, Field Guide 8, each later
    /// Style 4 more (Jay, 2026-11-15). nil = always free (Playful Bold).
    var streakWeeksToUnlock: Int? {
        switch self {
        case .playfulBold: return nil
        #if INTERNAL_STYLES
        case .arcade: return 4
        #endif
        }
    }

    /// The Style to show for a synced `activeStyleID`. Falls back to the default when the value is
    /// one this build doesn't have (e.g. a Style picked in Jay's Internal build and synced to a
    /// device running a Release build), or when `isAvailable` says this person can't use it.
    /// Callers must never write the result back: the synced choice has to survive until this
    /// device gets that Style. (3.3 plan)
    static func resolve(_ rawValue: String, isAvailable: (StyleID) -> Bool = { _ in true }) -> StyleID {
        guard let style = StyleID(rawValue: rawValue), isAvailable(style) else { return .default }
        return style
    }
}

// MARK: - Active Style

/// The Style being drawn right now. Tokens read it when they resolve (on any thread, including
/// SwiftUI's render thread), so it's a lock-protected value rather than view state. The app sets it
/// from the synced, access-checked choice (`ContentView`); widgets set it from the App Group.
/// Changing it only takes effect on screen after a redraw, so the app rebuilds its root view.
nonisolated enum StyleRuntime {
    private static let storage = Mutex(StyleID.default)

    static var current: StyleID { storage.withLock { $0 } }

    static func set(_ style: StyleID) { storage.withLock { $0 = style } }

    /// App Group key the app writes and widgets read (an already-resolved `StyleID.rawValue`).
    static let appGroupKey = "activeStyleID"
    static let appGroupSuite = "group.com.discoverhealthquest.funfitness"

    /// Widgets and the Live Activity: use the Style the app last showed. The app has already
    /// checked access; a Style this build doesn't have (e.g. Release widget) falls back.
    static func loadFromAppGroup() {
        let raw = UserDefaults(suiteName: appGroupSuite)?.string(forKey: appGroupKey) ?? ""
        set(StyleID.resolve(raw))
    }

    /// The app, after the Style it shows changes.
    static func saveToAppGroup(_ style: StyleID) {
        UserDefaults(suiteName: appGroupSuite)?.set(style.rawValue, forKey: appGroupKey)
    }
}

// MARK: - Color tokens

/// Every color token, by its tokens.json name. Each Style gives each token a light/dark pair;
/// Playful Bold's are below, others live with their Style (e.g. Styles/Arcade).
nonisolated enum FFColorToken: CaseIterable, Sendable {
    case bg, surface, surfaceAlt, ink, inkMuted, line, shadowInk
    case brandYellow, accent, onAccent, accent2, onAccent2, link
    case typeDistance, onTypeDistance, typeWeight, onTypeWeight
    case typeDuration, onTypeDuration, typeReps, onTypeReps
    case progressTrack, streak, success, danger, focus, heat1, heat2, heat3

    /// Playful Bold: Sunny (light) / After Dark (dark).
    var playfulBold: (light: UInt32, dark: UInt32) {
        switch self {
        case .bg: return (0xFFD43B, 0x17122E)
        case .surface: return (0xFFFFFF, 0x262051)
        case .surfaceAlt: return (0xFFF4C7, 0x1F1A42)
        case .ink: return (0x1E1640, 0xFFF8E1)
        case .inkMuted: return (0x4A4170, 0xC9C2EA)
        case .line: return (0x1E1640, 0x08060F)
        case .shadowInk: return (0x1E1640, 0x08060F)
        case .brandYellow: return (0xFFD43B, 0xFFD43B)
        case .accent: return (0xFF5C8A, 0xFF6E98)
        case .onAccent: return (0x1E1640, 0x1E1640)
        case .accent2: return (0x6C3CE9, 0x8B66FF)
        case .onAccent2: return (0xFFFFFF, 0x10082A)
        // Not a tokens.json name: `accent` is never a text color, so links use `accent-2` in Sunny
        // and `brand-yellow` in After Dark (the README's "links on surface (light only)" and
        // "brand-yellow … greeting, focus" rules).
        case .link: return (0x6C3CE9, 0xFFD43B)
        case .typeDistance: return (0xFF5C8A, 0xFF6E98)
        case .onTypeDistance: return (0x1E1640, 0x1E1640)
        case .typeWeight: return (0x6C3CE9, 0x8B66FF)
        case .onTypeWeight: return (0xFFFFFF, 0x10082A)
        case .typeDuration: return (0x14C8B4, 0x2ED8C3)
        case .onTypeDuration: return (0x1E1640, 0x1E1640)
        case .typeReps: return (0xFF9F43, 0xFFAD5C)
        case .onTypeReps: return (0x1E1640, 0x1E1640)
        case .progressTrack: return (0xEFEAFF, 0x3A3270)
        case .streak: return (0xFF6B35, 0xFF8A50)
        case .success: return (0x157A43, 0x5BD38A)
        case .danger: return (0xB4232A, 0xFF7B7B)
        case .focus: return (0x1E1640, 0xFFD43B)
        case .heat1: return (0xFFE58A, 0x4A3A8C)
        case .heat2: return (0xFFB3C8, 0x8A4A9C)
        case .heat3: return (0xFF5C8A, 0xFF6E98)
        }
    }

    /// This token's pair in a Style. A Style that doesn't define a token uses Playful Bold's.
    func pair(in style: StyleID) -> (light: UInt32, dark: UInt32) {
        switch style {
        case .playfulBold: return playfulBold
        #if INTERNAL_STYLES
        case .arcade: return arcade ?? playfulBold
        #endif
        }
    }
}

nonisolated enum FFColor {
    /// A token that follows the active Style and the light/dark appearance.
    static func token(_ token: FFColorToken) -> Color {
        Color(uiToken(token))
    }

    static func uiToken(_ token: FFColorToken) -> UIColor {
        UIColor { traits in
            let pair = token.pair(in: StyleRuntime.current)
            return rgb(traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
        }
    }

    /// A fixed light/dark pair, the same in every Style.
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
    nonisolated static let ffBg = FFColor.token(.bg)
    nonisolated static let ffSurface = FFColor.token(.surface)
    nonisolated static let ffSurfaceAlt = FFColor.token(.surfaceAlt)
    nonisolated static let ffInk = FFColor.token(.ink)
    nonisolated static let ffInkMuted = FFColor.token(.inkMuted)
    nonisolated static let ffLine = FFColor.token(.line)
    nonisolated static let ffShadowInk = FFColor.token(.shadowInk)

    // Brand and actions
    nonisolated static let ffBrandYellow = FFColor.token(.brandYellow)
    nonisolated static let ffAccent = FFColor.token(.accent)
    nonisolated static let ffOnAccent = FFColor.token(.onAccent)
    nonisolated static let ffAccent2 = FFColor.token(.accent2)
    nonisolated static let ffOnAccent2 = FFColor.token(.onAccent2)
    /// Text links and tinted glyphs on bg/surface (see `FFColorToken.link`).
    nonisolated static let ffLink = FFColor.token(.link)

    // Activity types
    nonisolated static let ffTypeDistance = FFColor.token(.typeDistance)
    nonisolated static let ffOnTypeDistance = FFColor.token(.onTypeDistance)
    nonisolated static let ffTypeWeight = FFColor.token(.typeWeight)
    nonisolated static let ffOnTypeWeight = FFColor.token(.onTypeWeight)
    nonisolated static let ffTypeDuration = FFColor.token(.typeDuration)
    nonisolated static let ffOnTypeDuration = FFColor.token(.onTypeDuration)
    nonisolated static let ffTypeReps = FFColor.token(.typeReps)
    nonisolated static let ffOnTypeReps = FFColor.token(.onTypeReps)

    // States and data
    nonisolated static let ffProgressTrack = FFColor.token(.progressTrack)
    nonisolated static let ffStreak = FFColor.token(.streak)
    nonisolated static let ffSuccess = FFColor.token(.success)
    nonisolated static let ffDanger = FFColor.token(.danger)
    nonisolated static let ffFocus = FFColor.token(.focus)
    nonisolated static let ffHeat1 = FFColor.token(.heat1)
    nonisolated static let ffHeat2 = FFColor.token(.heat2)
    nonisolated static let ffHeat3 = FFColor.token(.heat3)
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

// Radius, stroke and shadow follow the active Style (read when a view is built; the app rebuilds
// its root view when the Style changes).

nonisolated enum FFRadius {
    static var sm: CGFloat { styleMetric(playfulBold: 12, arcade: 6) }
    static var md: CGFloat { styleMetric(playfulBold: 20, arcade: 12) }
    static var lg: CGFloat { styleMetric(playfulBold: 32, arcade: 18) }
    // radius-pill: use `.capsule`.
}

nonisolated enum FFStroke {
    static var card: CGFloat { styleMetric(playfulBold: 3, arcade: 1.5) }
    static var control: CGFloat { styleMetric(playfulBold: 2.5, arcade: 1.5) }
}

nonisolated enum FFShadow {
    /// shadow-pop: hard 6pt down-right, no blur. Arcade panels are flat (0).
    static var pop: CGFloat { styleMetric(playfulBold: 6, arcade: 0) }
    /// shadow-press: what's left while pressed (the element moves 4pt).
    static var press: CGFloat { styleMetric(playfulBold: 2, arcade: 0) }
}

/// A metric for the active Style. The Arcade value is ignored (and not compiled in) in Release.
nonisolated private func styleMetric(playfulBold: CGFloat, arcade: CGFloat) -> CGFloat {
    #if INTERNAL_STYLES
    if StyleRuntime.current == .arcade { return arcade }
    #endif
    return playfulBold
}

// MARK: - Type

/// The type scale from tokens.json, set in SF Pro Rounded. Playful Bold keeps the system font
/// (Jay, 2026-11-15: Fredoka/Nunito dropped); `FFFontFamily` stays as the hook for a future style.
nonisolated enum FFTextStyle: Sendable {
    case displayHero, display, numeral, title, headline
    case body, bodyStrong, caption, label
    /// Tab labels: `headline` at 16pt (TabBar.md).
    case tab

    var size: CGFloat {
        #if INTERNAL_STYLES
        if StyleRuntime.current == .arcade { return arcadeSize }
        #endif
        switch self {
        case .displayHero: return 88
        case .display, .numeral: return 40
        case .title: return 28
        case .headline: return 20
        case .tab: return 16
        case .body, .bodyStrong: return 17
        case .caption: return 14
        case .label: return 13
        }
    }

    var weight: Font.Weight {
        #if INTERNAL_STYLES
        if StyleRuntime.current == .arcade { return arcadeWeight }
        #endif
        switch self {
        case .displayHero, .display, .numeral: return .bold
        case .title, .headline, .body, .tab: return .semibold
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
        case .tab: return .callout
        case .body, .bodyStrong: return .body
        case .caption: return .footnote
        case .label: return .caption
        }
    }

    var isDisplay: Bool {
        switch self {
        case .displayHero, .display, .numeral, .title, .headline, .tab: return true
        default: return false
        }
    }

    /// Letter spacing in points at the base size.
    var tracking: CGFloat {
        #if INTERNAL_STYLES
        if StyleRuntime.current == .arcade { return arcadeTracking }
        #endif
        switch self {
        case .displayHero: return -0.02 * 88
        case .display: return -0.01 * 40
        case .label: return 0.08 * 13
        default: return 0
        }
    }

    /// Shown in capitals (the source text stays sentence case for VoiceOver).
    var isUppercase: Bool {
        #if INTERNAL_STYLES
        if StyleRuntime.current == .arcade { return arcadeIsUppercase }
        #endif
        return self == .label
    }

    /// System font design for the active Style.
    var design: Font.Design {
        #if INTERNAL_STYLES
        if StyleRuntime.current == .arcade { return arcadeDesign }
        #endif
        return .rounded
    }
}

/// Bundled font names for a style that uses custom fonts. nil = SF Pro Rounded, which is
/// Playful Bold's font by decision (2026-11-15).
nonisolated enum FFFontFamily {
    static let display: String? = nil
    static let body: String? = nil
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
            .textCase(style.isUppercase ? .uppercase : nil)
    }

    private var font: Font {
        #if INTERNAL_STYLES
        // Chakra Petch Bold is a single static weight, so no extra weight is applied.
        if StyleRuntime.current == .arcade, let name = style.arcadeFontName {
            return .custom(name, fixedSize: size)
        }
        #endif
        if let family = style.isDisplay ? FFFontFamily.display : FFFontFamily.body {
            return .custom(family, size: size).weight(style.weight)
        }
        return .system(size: size, weight: style.weight, design: style.design)
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
            // Hard offset shadow: a solid copy of the shape behind, no blur (none in flat Styles).
            .background(shape.fill(FFShadow.pop > 0 ? Color.ffShadowInk : .clear).offset(x: FFShadow.pop, y: FFShadow.pop))
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
