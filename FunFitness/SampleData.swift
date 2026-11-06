//
//  SampleData.swift
//  FunFitness
//
//  DEBUG-only sample data for screenshots and visual checks (3.2). Launch a Debug build with
//  `-seedSampleData` to run against an in-memory store holding a profile and two weeks of
//  activity; nothing touches the real store or iCloud. Not compiled into Release builds.
//

#if DEBUG
import Foundation
import SwiftData

enum SampleData {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedSampleData")
    }

    /// An in-memory container filled with a sample profile and activity.
    static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: PersistenceController.schema, configurations: [config])
        seed(container.mainContext)
        return container
    }

    static func seed(_ context: ModelContext, now: Date = Date()) {
        let profile = UserProfile(name: "Jay", fitnessGoal: "Stay Active")
        profile.activeJourneyID = "texas-triangle"
        profile.journeyStartedAt = now.addingTimeInterval(-13 * 86_400)
        context.insert(profile)

        func daysAgo(_ days: Double, hour: Double = 7) -> Date {
            Calendar.current.startOfDay(for: now).addingTimeInterval(-days * 86_400 + hour * 3_600)
        }

        let entries: [ActivityLog] = [
            ActivityLog(type: .distance, value: 5.2, loggedAt: daysAgo(0), surface: .road),
            ActivityLog(type: .weight, value: 61.2, reps: 10, loggedAt: daysAgo(0, hour: 18)),
            ActivityLog(type: .reps, value: 25, loggedAt: daysAgo(1, hour: 18)),
            ActivityLog(type: .distance, value: 3.4, loggedAt: daysAgo(2)),
            ActivityLog(type: .duration, value: 40, loggedAt: daysAgo(3, hour: 12)),
            ActivityLog(type: .distance, value: 8.0, loggedAt: daysAgo(6)),
            ActivityLog(type: .weight, value: 70.3, reps: 8, loggedAt: daysAgo(8, hour: 18)),
            ActivityLog(type: .distance, value: 12.5, loggedAt: daysAgo(10)),
            ActivityLog(type: .distance, value: 6.1, loggedAt: daysAgo(13)),
        ]
        entries[1].exerciseID = "bench-press"
        entries[2].exerciseID = "push-up"
        entries[6].exerciseID = "back-squat"
        for entry in entries { context.insert(entry) }
        try? context.save()
    }
}
#endif
