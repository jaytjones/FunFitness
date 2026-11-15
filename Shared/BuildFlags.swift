//
//  BuildFlags.swift
//  FunFitness
//
//  Compile-time switches, readable at runtime. `INTERNAL_STYLES` is set only in the Debug and
//  Internal configurations (project-level build settings), never in Release, so unreleased styles
//  are compiled out of every TestFlight/App Store build testers get. Jay-only (3.3 plan).
//

import Foundation

nonisolated enum BuildFlags {
    /// True in Debug and Internal builds: unreleased styles are compiled in (and still shown only
    /// to the owner's iCloud account).
    static let internalStyles: Bool = {
        #if INTERNAL_STYLES
        return true
        #else
        return false
        #endif
    }()
}
