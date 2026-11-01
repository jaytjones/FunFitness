//
//  AdaptiveColorTests.swift
//  FunFitnessTests
//
//  TestFlight FB-0002: the adaptive background colors must resolve off the main thread, because
//  SwiftUI can resolve them on its background render thread.
//

import Testing
import UIKit
@testable import FunFitness

@Suite("Adaptive colors")
struct AdaptiveColorTests {

    private static func components(_ color: UIColor) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }

    // Before the fix this trapped: the provider closures were MainActor-isolated.
    @Test func resolvesOffTheMainThread() async {
        let resolved = await Task.detached {
            let dark = UITraitCollection(userInterfaceStyle: .dark)
            let light = UITraitCollection(userInterfaceStyle: .light)
            return [
                UIColor.appBackground.resolvedColor(with: dark),
                UIColor.appBackground.resolvedColor(with: light),
                UIColor.appCard.resolvedColor(with: dark),
                UIColor.appCard.resolvedColor(with: light),
            ].map(Self.components)
        }.value

        #expect(resolved.count == 4)
        #expect(resolved.allSatisfy { $0[3] == 1 })
    }

    @Test func darkModeUsesTheNavyPalette() {
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let background = Self.components(UIColor.appBackground.resolvedColor(with: dark))
        let card = Self.components(UIColor.appCard.resolvedColor(with: dark))
        #expect(abs(background[0] - 13 / 255) < 0.001 && abs(background[2] - 26 / 255) < 0.001)
        #expect(abs(card[0] - 26 / 255) < 0.001 && abs(card[2] - 46 / 255) < 0.001)
    }
}
