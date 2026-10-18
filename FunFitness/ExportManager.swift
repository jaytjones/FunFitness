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
        // New columns are appended last (3.1: Surface, then Session) so existing positions don't move.
        var rows = ["Type,Value,Unit,Reps,Date,Notes,Surface,Session"]
        let formatter = ISO8601DateFormatter()

        for activity in activities.sorted(by: { $0.loggedAt < $1.loggedAt }) {
            let kind  = activity.activityType
            let type  = kind.exportName
            let value = String(format: "%.2f", UnitConverter.fromSI(activity.value, type: kind, to: pref))
            let unit  = UnitConverter.displayUnit(for: kind, pref: pref)

            let reps  = activity.reps.map { String($0) } ?? ""
            let date  = formatter.string(from: activity.loggedAt)
            let notes = (activity.notes ?? "")
                .replacingOccurrences(of: ",", with: ";")
                .replacingOccurrences(of: "\n", with: " ")

            let surface = activity.surface?.rawValue ?? ""
            // Sets from one workout share a session id. (3.1 C1)
            let session = activity.sessionID?.uuidString ?? ""

            rows.append("\(type),\(value),\(unit),\(reps),\(date),\(notes),\(surface),\(session)")
        }

        return rows.joined(separator: "\n")
    }

    // MARK: - JSON

    static func generateJSON(activities: [ActivityLog]) -> String {
        let formatter = ISO8601DateFormatter()

        let activityDicts: [[String: Any]] = activities
            .sorted(by: { $0.loggedAt < $1.loggedAt })
            .map { activity in
                let kind = activity.activityType
                var dict: [String: Any] = [
                    "type":      kind.exportName,
                    "valueSI":   activity.value,
                    "unit":      UnitConverter.siUnit(for: kind),
                    "loggedAt":  formatter.string(from: activity.loggedAt)
                ]
                if let reps  = activity.reps  { dict["reps"]  = reps  }
                if let notes = activity.notes { dict["notes"] = notes }
                if let surface = activity.surface { dict["surface"] = surface.rawValue }
                if let sessionID = activity.sessionID { dict["sessionID"] = sessionID.uuidString }
                return dict
            }

        let root: [String: Any] = [
            "schemaVersion": "1.4",   // 1.3 (3.1): optional "surface"; 1.4 (3.1): optional "sessionID"
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
