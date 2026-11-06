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

    /// 3.2: the grounds are the Playful Bold tokens `bg` and `surface` (docs/design/playful-bold).
    @Test func usesThePlayfulBoldPalette() {
        func hex(_ c: [CGFloat]) -> String {
            String(format: "%02X%02X%02X", Int((c[0] * 255).rounded()), Int((c[1] * 255).rounded()), Int((c[2] * 255).rounded()))
        }
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let light = UITraitCollection(userInterfaceStyle: .light)
        #expect(hex(Self.components(UIColor.appBackground.resolvedColor(with: light))) == "FFD43B")
        #expect(hex(Self.components(UIColor.appBackground.resolvedColor(with: dark))) == "17122E")
        #expect(hex(Self.components(UIColor.appCard.resolvedColor(with: light))) == "FFFFFF")
        #expect(hex(Self.components(UIColor.appCard.resolvedColor(with: dark))) == "262051")
    }
}
