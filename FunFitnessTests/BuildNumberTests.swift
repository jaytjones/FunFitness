//
//  BuildNumberTests.swift
//  FunFitnessTests
//
//  The app and its widget extension must ship the same version and build number, or App Store
//  Connect rejects the upload. Both now inherit them from the project-level build settings
//  (MARKETING_VERSION / CURRENT_PROJECT_VERSION); this checks the built bundles so a target-level
//  override can't sneak back in. See docs/release_checklist.md.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Build numbers")
struct BuildNumberTests {

    private func versions(of bundle: Bundle) -> (version: String?, build: String?) {
        (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
         bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    }

    @Test func widgetMatchesTheApp() throws {
        // Unit tests run inside the app, so Bundle.main is FunFitness.app.
        let app = versions(of: .main)
        let pluginsURL = try #require(Bundle.main.builtInPlugInsURL)
        let widgetURL = pluginsURL.appendingPathComponent("FunFitnessWidgetsExtension.appex")
        let widget = versions(of: try #require(Bundle(url: widgetURL)))

        #expect(app.version != nil && app.build != nil)
        #expect(widget.version == app.version)
        #expect(widget.build == app.build)
    }

    @Test func watchAppMatchesTheApp() throws {
        // The Watch app is embedded in FunFitness.app/Watch and must match too (3.1).
        let app = versions(of: .main)
        let watchURL = Bundle.main.bundleURL.appendingPathComponent("Watch/FunFitnessWatch Watch App.app")
        let watch = versions(of: try #require(Bundle(url: watchURL)))

        #expect(watch.version == app.version)
        #expect(watch.build == app.build)
    }

    @Test func buildNumberIsAWholeNumber() throws {
        // App Store Connect compares builds numerically; keep it a plain integer (e.g. "9").
        let build = try #require(versions(of: .main).build)
        #expect(Int(build) != nil)
    }
}
