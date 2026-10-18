//
//  HeartRateMath.swift
//  FunFitness
//
//  Pure heart-rate summary for a tracked walk/run (3.1 B2, feedback "use heart rate"). The app
//  doesn't record heart rate itself on iOS 18; after a run it reads whatever an Apple Watch or
//  other sensor saved to Health in that window, and this reduces those samples to avg/max.
//

import Foundation

/// One heart-rate reading from Health, in beats per minute.
nonisolated struct HeartRateSample: Equatable, Sendable {
    let bpm: Double
    let date: Date
}

/// Average and maximum heart rate over a workout's moving time.
nonisolated struct HeartRateSummary: Equatable, Sendable {
    let average: Double
    let maximum: Double

    /// "132" — whole beats per minute, as Health shows them.
    var averageText: String { "\(Int(average.rounded()))" }
    var maximumText: String { "\(Int(maximum.rounded()))" }
}

nonisolated enum HeartRateMath {

    /// Readings outside this range are sensor noise, not a heart rate.
    static let plausibleBPM: ClosedRange<Double> = 30...240

    /// Summarizes the samples taken between `start` and `end`, skipping paused stretches.
    /// nil when no plausible sample falls in the moving time — e.g. no Watch was worn.
    /// The average is a plain mean: Watch workout readings come at a steady rate, so weighting
    /// by time changes little.
    static func summary(
        samples: [HeartRateSample],
        start: Date,
        end: Date,
        pauses: [DateInterval] = []
    ) -> HeartRateSummary? {
        let moving = samples.filter { sample in
            sample.date >= start && sample.date <= end
                && plausibleBPM.contains(sample.bpm)
                && !pauses.contains { $0.contains(sample.date) }
        }
        guard let maximum = moving.map(\.bpm).max() else { return nil }
        let average = moving.reduce(0) { $0 + $1.bpm } / Double(moving.count)
        return HeartRateSummary(average: average, maximum: maximum)
    }
}
