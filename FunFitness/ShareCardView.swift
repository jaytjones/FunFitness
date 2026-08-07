//
//  ShareCardView.swift
//  FunFitness
//
//  Screenshot-worthy share cards rendered with ImageRenderer, built from the
//  app's existing emoji + gradient visual language (no external art assets).
//  Used for milestones, streaks, and silly titles.
//

import SwiftUI

/// Describes what a share card shows. Content-only so it can be built off the
/// main actor and rendered later.
struct ShareCardContent {
    let badge: String        // small uppercase label, e.g. "MILESTONE"
    let emoji: String
    let headline: String
    let subtext: String
    let gradient: [Color]

    /// Stable identity for re-rendering when the underlying data changes.
    var cacheKey: String { "\(badge)|\(emoji)|\(headline)|\(subtext)" }

    // MARK: - Factories

    static func milestone(_ milestone: Milestone, theme: Theme) -> ShareCardContent {
        ShareCardContent(
            badge: "MILESTONE UNLOCKED",
            emoji: milestone.getEmoji(for: theme),
            headline: milestone.title,
            subtext: milestone.getComparison(for: theme),
            gradient: [Color(hex: "#7C3AED"), Color(hex: "#4C1D95")]
        )
    }

    static func streak(current: Int, longest: Int) -> ShareCardContent {
        ShareCardContent(
            badge: "ON FIRE",
            emoji: current >= 8 ? "🔥🔥" : "🔥",
            headline: "\(current)-Week Streak!",
            subtext: "Personal best: \(longest) week\(longest == 1 ? "" : "s"). Still going strong.",
            gradient: [Color(hex: "#EA580C"), Color(hex: "#DC2626")]
        )
    }

    static func title(_ title: SillyTitle, badgeCount: Int) -> ShareCardContent {
        ShareCardContent(
            badge: "MY OFFICIAL TITLE",
            emoji: title.rankEmoji,
            headline: title.title,
            subtext: "\(title.rank) Rank · \(badgeCount) badge\(badgeCount == 1 ? "" : "s") earned",
            gradient: [Color(hex: "#7C3AED"), Color(hex: "#D946EF")]
        )
    }
}

/// The rendered card. Fixed size; rasterized at scale 3 by ShareCardRenderer.
struct ShareCard: View {
    let content: ShareCardContent

    var body: some View {
        VStack(spacing: 20) {
            Text(content.badge)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Text(content.emoji)
                .font(.system(size: 96))

            Text(content.headline)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(content.subtext)
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Spacer()

            HStack(spacing: 6) {
                Text("💪")
                Text("FunFitness")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(32)
        .frame(width: 360, height: 450)
        .background(
            LinearGradient(colors: content.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

/// A share button that renders `content` to a PNG and offers it via ShareLink.
/// Rendering happens in `.task` so it's ready by the time the user taps.
struct ShareCardButton: View {
    let content: ShareCardContent
    let filename: String
    var tint: Color = .white

    @State private var url: URL?

    var body: some View {
        Group {
            if let url {
                ShareLink(item: url, preview: SharePreview(content.headline)) {
                    icon
                }
            } else {
                icon.opacity(0.4)
            }
        }
        .task(id: content.cacheKey) {
            url = ShareCardRenderer.pngURL(for: content, filename: filename)
        }
    }

    private var icon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.subheadline)
            .foregroundStyle(tint)
            .accessibilityLabel("Share")
    }
}

#Preview {
    ShareCard(content: .streak(current: 8, longest: 12))
}
