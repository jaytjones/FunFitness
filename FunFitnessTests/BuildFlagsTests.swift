//
//  BuildFlagsTests.swift
//  FunFitnessTests
//
//  Unreleased styles (Jay, 2026-11-15) and 3.4 Friends (Jay, 2026-11-24) must never reach
//  external testers or the App Store. Tests run in Debug, where the flags are on, so these read
//  the project file to check every configuration's setting directly.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Build flags")
struct BuildFlagsTests {

    /// `SWIFT_ACTIVE_COMPILATION_CONDITIONS` for each named configuration in project.pbxproj.
    private func conditionsByConfiguration() throws -> [(name: String, conditions: String)] {
        let project = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FunFitness.xcodeproj/project.pbxproj")
        let text = try String(contentsOf: project, encoding: .utf8)
        // Each XCBuildConfiguration block lists its settings, then ends with `name = <Config>;`.
        var result: [(name: String, conditions: String)] = []
        var inConfig = false
        var conditions = ""
        for line in text.split(separator: "\n") {
            if line.contains("isa = XCBuildConfiguration;") {
                inConfig = true
                conditions = ""
            } else if inConfig, line.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS") {
                conditions = String(line)
            } else if inConfig, let range = line.range(of: "name = ") {
                result.append((String(line[range.upperBound...].dropLast()), conditions))
                inConfig = false
            }
        }
        return result
    }

    @Test func releaseNeverCompilesUnreleasedStyles() throws {
        let configs = try conditionsByConfiguration()
        let release = configs.filter { $0.name == "Release" }
        #expect(!release.isEmpty)
        for config in release {
            #expect(!config.conditions.contains("INTERNAL_STYLES"), "Release must not set INTERNAL_STYLES")
        }
    }

    @Test func internalAndDebugCompileThem() throws {
        let configs = try conditionsByConfiguration()
        #expect(configs.contains { $0.name == "Internal" && $0.conditions.contains("INTERNAL_STYLES") })
        #expect(configs.contains { $0.name == "Debug" && $0.conditions.contains("INTERNAL_STYLES") })
    }

    @Test(arguments: ["INTERNAL_STYLES", "INTERNAL_SOCIAL"])
    func onlyDebugAndInternalSetTheFlag(_ flag: String) throws {
        let configs = try conditionsByConfiguration()
        #expect(configs.contains { $0.name == "Release" })
        for config in configs where config.name == "Release" {
            #expect(!config.conditions.contains(flag), "Release must not set \(flag)")
        }
        #expect(configs.contains { $0.name == "Internal" && $0.conditions.contains(flag) })
        #expect(configs.contains { $0.name == "Debug" && $0.conditions.contains(flag) })
    }

    @Test func debugTestBuildHasTheSocialFlag() {
        #expect(BuildFlags.internalSocial)
    }

    @Test func debugTestBuildHasTheFlag() {
        // Tests run in Debug; this catches the flag being dropped from Debug by accident.
        #expect(BuildFlags.internalStyles)
    }
}
