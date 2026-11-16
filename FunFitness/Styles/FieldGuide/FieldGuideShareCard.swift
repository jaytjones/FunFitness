//
//  FieldGuideShareCard.swift
//  FunFitness
//
//  Field Guide's share image (3.3): a single plate page, 360 × 450 — masthead, stamp, title, the
//  plate tipped in on the page, its caption. Rendered in the appearance the person is in. No
//  weight, calories, location, QR code or URL. Spec: docs/design/field-guide/components/ShareCard.md.
//
//  UNRELEASED — compiled only with INTERNAL_STYLES; text is verbatim (see ArcadeHome.swift).
//

#if INTERNAL_STYLES

import SwiftUI

struct FieldGuideShareCard: View {
    let content: ShareCardContent

    var body: some View {
        let number = content.milestoneId.flatMap(FieldGuideRules.specimenNumber)
        VStack(alignment: .leading, spacing: FFSpace.s3) {
            VStack(spacing: FFSpace.s1) {
                HStack {
                    Text(verbatim: "FunFitness Field Guide")
                    Spacer()
                    Text(verbatim: number.map { String(format: "No. %02d", $0) } ?? content.badge)
                }
                .ffFont(.label)
                .foregroundStyle(Color.ffInk)
                Rectangle().fill(Color.ffInk).frame(height: 2)
            }
            HStack(alignment: .top) {
                Text(verbatim: content.headline)
                    .ffFont(.display)
                    .foregroundStyle(Color.ffInk)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: FFSpace.s2)
                Text(verbatim: "New entry\nrecorded")
                    .ffFont(.label)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.ffAccent2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(Rectangle().strokeBorder(Color.ffAccent2, lineWidth: 2))
                    .rotationEffect(.degrees(-8))
            }
            // The plate sits on `bg` inside the `surface` page, so it reads as tipped in.
            Text(verbatim: content.emoji)
                .font(.system(size: 72))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ffBg)
                .overlay(Rectangle().strokeBorder(Color.ffInk, lineWidth: 1.6))
            Text(verbatim: (number.map { String(format: "Fig. %02d. ", $0) } ?? "") + content.subtext)
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
                .minimumScaleFactor(0.8)
        }
        .padding(FFSpace.s5)
        .frame(width: 360, height: 450)
        .background(Color.ffSurface)
        .environment(\.colorScheme, ArcadeShareCard.currentScheme)
        .environment(\.dynamicTypeSize, .large)
    }
}

#endif
