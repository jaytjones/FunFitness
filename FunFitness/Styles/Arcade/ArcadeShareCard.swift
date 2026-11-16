//
//  ArcadeShareCard.swift
//  FunFitness
//
//  Arcade's share image (3.3): the trading card itself with the wordmark, in the person's current
//  appearance (Arcade in dark, Daylight in light), keeping the comparison sentence. Spec:
//  docs/design/arcade/components/ShareCard.md. The level chip is left off: the renderer doesn't
//  know the badge count. `ShareCard` shows this when Arcade is active.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI
import UIKit

struct ArcadeShareCard: View {
    let content: ShareCardContent

    var body: some View {
        let rarity = content.milestoneId.flatMap(ArcadeRules.rarity(of:))
        let frame = rarity?.color ?? .ffAccent
        let shape = RoundedRectangle(cornerRadius: FFRadius.lg, style: .continuous)
        VStack(spacing: FFSpace.s4) {
            HStack {
                (Text(verbatim: "FUN") + Text(verbatim: "FITNESS").foregroundColor(.ffAccent))
                    .ffFont(.title)
                    .foregroundStyle(Color.ffInk)
                Spacer()
            }
            VStack(spacing: FFSpace.s3) {
                HStack {
                    Text(verbatim: rarity?.word ?? content.badge)
                        .ffFont(.label)
                        .fontWeight(.bold)
                        .foregroundStyle(rarity == nil ? Color.ffOnAccent : Color.ffOnRarity)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(frame, in: RoundedRectangle(cornerRadius: FFRadius.sm))
                    Spacer()
                    if let id = content.milestoneId {
                        Text(verbatim: id)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.ffInkMuted)
                    }
                }
                Text(verbatim: content.emoji)
                    .font(.system(size: 76))
                    .frame(maxWidth: .infinity, minHeight: 130)
                    .background(
                        RadialGradient(colors: [.ffGlow, .ffSurfaceAlt], center: .center, startRadius: 0, endRadius: 100),
                        in: RoundedRectangle(cornerRadius: FFRadius.md)
                    )
                Text(verbatim: content.headline)
                    .ffFont(.display)
                    .foregroundStyle(Color.ffInk)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                // The comparison is the joke people share (ShareCard.md).
                Text(verbatim: content.subtext)
                    .ffFont(.body)
                    .foregroundStyle(Color.ffInkMuted)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(FFSpace.s4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ffSurface, in: shape)
            .overlay(shape.strokeBorder(frame, lineWidth: 3))
        }
        .padding(FFSpace.s5)
        .frame(width: 360, height: 450)
        .background(Color.ffBg)
        .environment(\.colorScheme, Self.currentScheme)
        .environment(\.dynamicTypeSize, .large)
    }

    /// The appearance the app is showing, so the image matches the screen (ShareCard.md).
    static var currentScheme: ColorScheme {
        let style = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.traitCollection.userInterfaceStyle }
            .first ?? .light
        return style == .dark ? .dark : .light
    }
}

/// A visible Share control for Arcade (label, or icon-only where space is tight). Renders the share
/// image in the background; until it's ready the control shows but is disabled.
struct ArcadeShareButton: View {
    let content: ShareCardContent
    let filename: String
    var showsLabel = true

    @State private var url: URL?

    var body: some View {
        Group {
            if let url {
                ShareLink(item: url, preview: SharePreview(content.headline)) { face }
            } else {
                face.opacity(0.4)
            }
        }
        .buttonStyle(.plain)
        .task(id: content.cacheKey) {
            url = ShareCardRenderer.pngURL(for: content, filename: filename)
        }
        .accessibilityLabel(Text(verbatim: "Share"))
    }

    private var face: some View {
        HStack(spacing: 4) {
            Image(systemName: "square.and.arrow.up")
            if showsLabel {
                Text(verbatim: "Share")
            }
        }
        .ffFont(.label)
        .fontWeight(.bold)
        .foregroundStyle(Color.ffAccent)
        .padding(.horizontal, showsLabel ? FFSpace.s2 : 6)
        .padding(.vertical, FFSpace.s1)
        .overlay(RoundedRectangle(cornerRadius: FFRadius.sm).strokeBorder(Color.ffLineStrong, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

#endif
