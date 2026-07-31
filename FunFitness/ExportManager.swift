//
//  ExportManager.swift
//  FunFitness
//
//  Generates CSV and JSON exports of activity data.
//  All values are expressed in the user's preferred display units.
//

import Foundation

struct ExportManager {

    // MARK: - CSV

    static func generateCSV(activities: [ActivityLog], pref: UnitPreference) -> String {
        var rows = ["Type,Value,Unit,Reps,Date,Notes"]
        let formatter = ISO8601DateFormatter()

        for activity in activities.sorted(by: { $0.loggedAt < $1.loggedAt }) {
            let type = activity.activityType == .distance ? "distance" : "weight"
            let (value, unit): (String, String)

            if activity.activityType == .distance {
                value = String(format: "%.2f", UnitConverter.fromKm(activity.value, to: pref))
                unit  = pref.distanceUnit
            } else {
                value = String(format: "%.2f", UnitConverter.fromKg(activity.value, to: pref))
                unit  = pref.weightUnit
            }

            let reps  = activity.reps.map { String($0) } ?? ""
            let date  = formatter.string(from: activity.loggedAt)
            let notes = (activity.notes ?? "")
                .replacingOccurrences(of: ",", with: ";")
                .replacingOccurrences(of: "\n", with: " ")

            rows.append("\(type),\(value),\(unit),\(reps),\(date),\(notes)")
        }

        return rows.joined(separator: "\n")
    }

    // MARK: - JSON

    static func generateJSON(activities: [ActivityLog]) -> String {
        let formatter = ISO8601DateFormatter()

        let activityDicts: [[String: Any]] = activities
            .sorted(by: { $0.loggedAt < $1.loggedAt })
            .map { activity in
                var dict: [String: Any] = [
                    "type":      activity.activityType == .distance ? "distance" : "weight",
                    "valueSI":   activity.value,
                    "unit":      activity.activityType == .distance ? "km" : "kg",
                    "loggedAt":  formatter.string(from: activity.loggedAt)
                ]
                if let reps  = activity.reps  { dict["reps"]  = reps  }
                if let notes = activity.notes { dict["notes"] = notes }
                return dict
            }

        let root: [String: Any] = [
            "schemaVersion": "1.2",
            "activities": activityDicts
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ),
        let string = String(data: data, encoding: .utf8) else { return "{}" }

        return string
    }

    // MARK: - Temp file helpers for ShareLink

    static func csvFileURL(activities: [ActivityLog], pref: UnitPreference) -> URL? {
        let csv = generateCSV(activities: activities, pref: pref)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("funfitness_export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func jsonFileURL(activities: [ActivityLog]) -> URL? {
        let json = generateJSON(activities: activities)
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent("funfitness_export.json")
        try? json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
