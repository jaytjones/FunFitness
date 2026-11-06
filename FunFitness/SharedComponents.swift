//
//  SharedComponents.swift
//  FunFitness
//
//  Shared UI utilities used across multiple views.
//

import SwiftUI

// MARK: - Color from hex string

extension Color {
    nonisolated init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Adaptive semantic colors

// The dynamic providers are `nonisolated`: UIKit resolves them on whatever thread is drawing,
// including SwiftUI's background render thread. With the target's default MainActor isolation,
// a plain closure here was inferred @MainActor and trapped when resolved off the main thread
// (TestFlight FB-0002, crash in 3.1 (9)).
// 3.2: these are the Style tokens `bg` and `surface` (Shared/Style.swift); the names stay so
// older call sites and AdaptiveColorTests keep working. Prefer `Color.ffBg` / `.ffSurface`.
extension UIColor {
    /// Screen ground (`bg`): Sunny yellow / After Dark grape.
    nonisolated static let appBackground = FFColor.uiColor(0xFFD43B, 0x17122E)

    /// Card face (`surface`): white / lifted grape.
    nonisolated static let appCard = FFColor.uiColor(0xFFFFFF, 0x262051)
}

extension Color {
    /// Screen ground. Same as `Color.ffBg`.
    static var appBackground: Color { Color(UIColor.appBackground) }

    /// Card face. Same as `Color.ffSurface`.
    static var appCard: Color { Color(UIColor.appCard) }
}

// MARK: - Per-activity-type card presentation (v2.2)
// View-layer copy/colors for the Home StatCard and Progress TrackingCard, kept beside the other
// SwiftUI helpers. The switches are exhaustive so a new ActivityType must supply a card style here.

extension ActivityType {
    /// Card title on Home / Progress.
    var cardTitle: String {
        switch self {
        case .distance: return "Distance Tracking"
        case .weight:   return "Weight Tracking"
        case .duration: return "Duration Tracking"
        case .reps:     return "Reps Tracking"
        }
    }

    /// Supporting line under the card title.
    var cardSubtitle: String {
        switch self {
        case .distance: return "Running & Walking"
        case .weight:   return "Strength Training"
        case .duration: return "Yoga, Cycling & More"
        case .reps:     return "Push-ups, Sit-ups & More"
        }
    }

    /// The type's identity fill (tag, meter, tile, chart bars). Style token `type-*`. (3.2)
    var ffFill: Color {
        switch self {
        case .distance: return .ffTypeDistance
        case .weight:   return .ffTypeWeight
        case .duration: return .ffTypeDuration
        case .reps:     return .ffTypeReps
        }
    }

    /// Text and glyphs on `ffFill`. Style token `on-type-*`.
    var ffOnFill: Color {
        switch self {
        case .distance: return .ffOnTypeDistance
        case .weight:   return .ffOnTypeWeight
        case .duration: return .ffOnTypeDuration
        case .reps:     return .ffOnTypeReps
        }
    }

    /// SF Symbol for the type's icon chip (Playful Bold iconography).
    var symbolName: String {
        switch self {
        case .distance: return "figure.run"
        case .weight:   return "dumbbell"
        case .duration: return "timer"
        case .reps:     return "arrow.triangle.2.circlepath"
        }
    }

    /// Uppercase tag text ("DISTANCE", "WEIGHT LIFTED").
    var tagText: String {
        switch self {
        case .distance: return "Distance"
        case .weight:   return "Weight lifted"
        case .duration: return "Duration"
        case .reps:     return "Reps"
        }
    }
}

// MARK: - Progress bar style used on tracking cards

/// Kept for existing call sites; draws the Playful Bold ProgressMeter (`FFMeterStyle`).
struct FitnessProgressStyle: ProgressViewStyle {
    var tint: Color = .ffAccent

    func makeBody(configuration: Configuration) -> some View {
        FFMeterStyle(fill: tint).makeBody(configuration: configuration)
    }
}

// MARK: - Unified selection chip (replaces GoalChip / ThemeChip)

/// Playful Bold chip: the selection is brand yellow (text on-accent); others sit on surface-alt.
struct SelectionChip: View {
    let title: String
    let isSelected: Bool
    var selectedBackground: Color = .ffBrandYellow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .ffFont(isSelected ? .bodyStrong : .body)
                .foregroundStyle(isSelected ? Color.ffOnAccent : Color.ffInkMuted)
                .padding(.horizontal, FFSpace.s4)
                .padding(.vertical, FFSpace.s2)
                .background(isSelected ? selectedBackground : Color.ffSurfaceAlt, in: .capsule)
                .overlay(Capsule().strokeBorder(Color.ffLine, lineWidth: FFStroke.control))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Flow layout for wrapping chip rows

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY),
                proposal: .unspecified
            )
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Surface Picker (3.1)

/// Optional distance-surface chips. Tapping the selected chip clears it (surface not set).
struct SurfacePicker: View {
    @Binding var selection: DistanceSurface?
    var options: [DistanceSurface] = DistanceSurface.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Surface (optional)")
                .ffFont(.headline)
                .foregroundStyle(Color.ffInk)
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { surface in
                    SelectionChip(
                        title: surface.displayName,
                        isSelected: selection == surface,
                        action: { selection = selection == surface ? nil : surface }
                    )
                }
            }
        }
        .accessibilityIdentifier("surfacePicker")
    }
}
