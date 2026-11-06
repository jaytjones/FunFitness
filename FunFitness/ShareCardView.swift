//
//  ShareCardView.swift
//  FunFitness
//
//  Screenshot-worthy share cards rendered with ImageRenderer: an outlined white card on the
//  Sunny yellow ground (Playful Bold ShareCard), emoji art, no external assets.
//  Always rendered in Sunny (light) colours so posts look the same everywhere.
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

    /// Stable identity for re-rendering when the underlying data changes.
    var cacheKey: String { "\(badge)|\(emoji)|\(headline)|\(subtext)" }

    // MARK: - Factories

    static func milestone(_ milestone: Milestone, pack: ThemePack, pref: UnitPreference) -> ShareCardContent {
        ShareCardContent(
            badge: "MILESTONE UNLOCKED",
            emoji: milestone.getEmoji(for: pack),
            headline: milestone.title(pref: pref),
            subtext: milestone.getComparison(for: pack)
        )
    }

    static func streak(current: Int, longest: Int) -> ShareCardContent {
        ShareCardContent(
            badge: "ON FIRE",
            emoji: current >= 8 ? "🔥🔥" : "🔥",
            headline: "\(current)-Week Streak!",
            subtext: "Personal best: \(longest) week\(longest == 1 ? "" : "s"). Still going strong."
        )
    }

    static func challenge(_ challenge: Challenge) -> ShareCardContent {
        ShareCardContent(
            badge: "CHALLENGE COMPLETE",
            emoji: challenge.emoji,
            headline: challenge.title,
            subtext: challenge.blurb
        )
    }

    static func title(_ title: SillyTitle, badgeCount: Int) -> ShareCardContent {
        ShareCardContent(
            badge: "MY OFFICIAL TITLE",
            emoji: title.rankEmoji,
            headline: title.title,
            subtext: "\(title.rank) Rank · \(badgeCount) badge\(badgeCount == 1 ? "" : "s") earned"
        )
    }
}

/// The rendered card. Fixed size; rasterized at scale 3 by ShareCardRenderer.
struct ShareCard: View {
    let content: ShareCardContent

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                Text(content.badge)
                    .ffFont(.label)
                    .foregroundStyle(Color.ffInkMuted)

                Spacer(minLength: 0)

                Text(content.emoji)
                    .font(.system(size: 96))

                Text(content.headline)
                    .ffFont(.title)
                    .foregroundStyle(Color.ffInk)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                Text(content.subtext)
                    .ffFont(.body)
                    .foregroundStyle(Color.ffInkMuted)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ffCard(padding: FFSpace.s5, radius: FFRadius.lg, fill: .ffSurface)

            HStack(spacing: 6) {
                Text("💪")
                Text("FunFitness")
                    .ffFont(.headline)
            }
            .foregroundStyle(Color.ffInk)
        }
        .padding(EdgeInsets(top: FFSpace.s6, leading: FFSpace.s6, bottom: FFSpace.s5, trailing: FFSpace.s6))
        .frame(width: 360, height: 450)
        .background(Color.ffBg)
        // Share images look the same everywhere: Sunny colours and the base type size, whatever
        // the device's appearance or Dynamic Type setting (the card is a fixed-size image).
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
    }
}

/// A share button that renders `content` to a PNG and offers it via ShareLink.
/// Rendering happens in `.task` so it's ready by the time the user taps.
struct ShareCardButton: View {
    let content: ShareCardContent
    let filename: String
    var tint: Color = .ffLink

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
