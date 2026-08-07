//
//  LogActivityIntent.swift
//  FunFitness
//
//  Siri Shortcut ("log my run") that repeats the most recent activity without
//  opening the app. Runs against the same on-disk SwiftData store the app uses,
//  reusing ActivityWriter so logging behaves identically everywhere.
//

import AppIntents
import SwiftData
import WidgetKit

struct LogLastActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Log My Last Activity"
    static var description = IntentDescription("Logs a repeat of your most recent FunFitness activity.")

    // Log quietly in the background; no need to bring the app forward.
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let schema = Schema([
            UserProfile.self,
            ActivityLog.self,
            UnlockedAchievement.self,
            StreakRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let activities = (try? context.fetch(FetchDescriptor<ActivityLog>())) ?? []
        guard let last = activities.max(by: { $0.loggedAt < $1.loggedAt }) else {
            return .result(dialog: "You haven't logged anything yet. Open FunFitness to get started!")
        }

        let unlockedIds = Set(
            ((try? context.fetch(FetchDescriptor<UnlockedAchievement>())) ?? []).map(\.milestoneId)
        )

        ActivityWriter.log(
            type: last.activityType,
            value: last.value,
            reps: last.reps,
            date: Date(),
            existingActivities: activities,
            unlockedIds: unlockedIds,
            context: context
        )
        WidgetCenter.shared.reloadAllTimelines()

        let pref = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first?.unitPref ?? .imperial
        let summary: String
        switch last.activityType {
        case .distance: summary = UnitConverter.distanceString(last.value, pref: pref)
        case .weight:   summary = UnitConverter.weightString(last.value, reps: last.reps, pref: pref)
        }

        return .result(dialog: "Logged \(summary). Nice work!")
    }
}

struct FunFitnessShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogLastActivityIntent(),
            phrases: [
                "Log my run in \(.applicationName)",
                "Log my last activity in \(.applicationName)",
                "Repeat my workout in \(.applicationName)",
            ],
            shortTitle: "Log Last Activity",
            systemImageName: "arrow.counterclockwise.circle.fill"
        )
    }
}
