//
//  NotificationManager.swift
//  FunFitness
//

import Foundation
import UserNotifications

enum NotificationCategory: String {
    case streakAtRisk   = "STREAK_AT_RISK"
    case milestoneNudge = "MILESTONE_NUDGE"
    case weeklyRecap    = "WEEKLY_RECAP"
    case comparisonDay  = "COMPARISON_DAY"
}

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        guard settings.authorizationStatus == .notDetermined else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings()
        return status.authorizationStatus == .authorized
    }

    // MARK: - Streak At Risk

    // Schedules a nudge for Thursday 7 PM of the current week if the user hasn't
    // logged anything this week yet. Replaces any existing pending nudge.
    func scheduleStreakAtRisk(streakCount: Int) {
        cancel(.streakAtRisk)
        guard streakCount > 0 else { return }

        var comps = DateComponents()
        comps.weekday = 5   // Thursday (Sun=1)
        comps.hour = 19
        comps.minute = 0

        let body = streakCount == 1
            ? "Log something today to keep your streak alive! 🔥"
            : "Your \(streakCount)-week streak is at risk — log today to save it! 🔥"

        let content = UNMutableNotificationContent()
        content.title = "Streak Check-In"
        content.body  = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakAtRisk.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationCategory.streakAtRisk.rawValue,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Milestone Nudge

    // Fires once if remaining ≤ 10% of the milestone's range.
    func scheduleMilestoneNudge(type: ActivityType, milestoneTitle: String, remaining: String) {
        let id = "\(NotificationCategory.milestoneNudge.rawValue)_\(type.rawValue)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Almost There!"
        content.body  = "Only \(remaining) away from: \(milestoneTitle) 🎯"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.milestoneNudge.rawValue

        // Fire in 2 hours (gives time to log after opening app).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7200, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Weekly Recap

    // Fires every Sunday at 8 PM.
    func scheduleWeeklyRecap(streakCount: Int, weeklyActivityCount: Int) {
        cancel(.weeklyRecap)

        var comps = DateComponents()
        comps.weekday = 1   // Sunday
        comps.hour = 20
        comps.minute = 0

        let body: String
        if weeklyActivityCount == 0 {
            body = "This week is still yours — log something before midnight! 💪"
        } else {
            let streak = streakCount > 0 ? " \(streakCount)-week streak!" : ""
            body = "\(weeklyActivityCount) workout\(weeklyActivityCount == 1 ? "" : "s") logged this week.\(streak) 🎉"
        }

        let content = UNMutableNotificationContent()
        content.title = "Weekly Recap"
        content.body  = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.weeklyRecap.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationCategory.weeklyRecap.rawValue,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Comparison of the Day

    // Schedules one daily comparison notification at 9 AM. Rotates through a
    // curated list of fun facts.
    func scheduleComparisonOfDay(facts: [String]) {
        cancel(.comparisonDay)
        guard !facts.isEmpty else { return }

        // Pick a fact based on day-of-year for deterministic rotation.
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let fact = facts[(dayOfYear - 1) % facts.count]

        var comps = DateComponents()
        comps.hour   = 9
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Today's Comparison"
        content.body  = fact
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.comparisonDay.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationCategory.comparisonDay.rawValue,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel helpers

    func cancel(_ category: NotificationCategory) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [category.rawValue]
        )
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - Comparison facts for daily notification

extension NotificationManager {
    static let dailyComparisonFacts: [String] = [
        "Did you know? A blue whale's heart weighs ~400 lbs. You might have already lifted one! 🐳",
        "A giraffe's neck is 6 feet long. Stack enough runs and you could walk past 270 of them! 🦒",
        "A monarch butterfly travels up to 100 miles a day. What's your daily goal? 🦋",
        "The Great Wall of China is about 13,000 miles long. You've got time. 🏯",
        "A grizzly bear can weigh 800 lbs. How many sessions to hoist one? 🐻",
        "Wildebeest migrate 500+ miles annually. Your feet could too. 🦬",
        "The Eiffel Tower is 1,083 feet tall. That's a lot of vertical miles. 🗼",
        "A hippo weighs ~3,300 lbs. Log enough lifts and you'll have raised one! 🦛",
        "The Golden Gate Bridge span is 4,200 feet. Run it twice and you've got a mile. 🌉",
        "A bottlenose dolphin swims 75 miles a day. Can you match it this week? 🐬",
    ]
}
