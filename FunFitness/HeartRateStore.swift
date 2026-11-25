//
//  HeartRateStore.swift
//  FunFitness
//
//  Heart rate read from Apple Health for tracked walks and runs, kept on this device only (App
//  Review Guideline 5.1.3(ii): apps may not store personal health information in iCloud). It used
//  to live in `ActivityLog.avgHeartRate` / `maxHeartRate`, which sync through the person's iCloud;
//  those fields now stay nil (a deployed CloudKit field can't be removed) and `migrate` moves any
//  old values here. Apple Health keeps the full readings, so nothing is lost.
//
//  A small JSON file in Application Support, excluded from iCloud backups. Another of the person's
//  devices doesn't see these values; there, Effort Points use the activity's standard intensity.
//

import Foundation
import Observation

@MainActor
@Observable
final class HeartRateStore {
    struct Reading: Codable, Equatable {
        var average: Double?
        var maximum: Double?
    }

    static let shared = HeartRateStore(fileURL: HeartRateStore.defaultFileURL)

    private var readings: [UUID: Reading]
    private let fileURL: URL?

    /// `fileURL` nil keeps everything in memory (tests).
    init(fileURL: URL?) {
        self.fileURL = fileURL
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([UUID: Reading].self, from: data) {
            readings = decoded
        } else {
            readings = [:]
        }
    }

    func reading(for activityID: UUID) -> Reading? { readings[activityID] }

    func set(average: Double?, maximum: Double?, for activityID: UUID) {
        if average == nil && maximum == nil {
            readings[activityID] = nil
        } else {
            readings[activityID] = Reading(average: average, maximum: maximum)
        }
        persist()
    }

    func removeAll() {
        readings = [:]
        persist()
    }

    /// Moves heart rate out of the synced fields into this store, then clears those fields so the
    /// values leave iCloud too. Returns how many entries moved (save the context if > 0). Runs at
    /// launch and whenever logs change, so values arriving from an older build are moved as well.
    @discardableResult
    func migrate(_ activities: [ActivityLog]) -> Int {
        var moved = 0
        for activity in activities where activity.avgHeartRate != nil || activity.maxHeartRate != nil {
            if readings[activity.id] == nil {
                readings[activity.id] = Reading(average: activity.avgHeartRate, maximum: activity.maxHeartRate)
            }
            activity.avgHeartRate = nil
            activity.maxHeartRate = nil
            moved += 1
        }
        if moved > 0 { persist() }
        return moved
    }

    private func persist() {
        guard var url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(readings).write(to: url, options: .atomic)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
        } catch {
            // Not fatal: the readings are still in Apple Health.
        }
    }

    private static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("HeartRates.json")
    }
}

@MainActor
extension ActivityLog {
    /// Average heart rate (bpm) recorded during this walk/run, from this device's store.
    var heartRateAverage: Double? { HeartRateStore.shared.reading(for: id)?.average }
    var heartRateMaximum: Double? { HeartRateStore.shared.reading(for: id)?.maximum }

    /// Records heart rate on this device only (never in the synced fields).
    func setHeartRate(average: Double?, maximum: Double?) {
        HeartRateStore.shared.set(average: average, maximum: maximum, for: id)
    }
}
