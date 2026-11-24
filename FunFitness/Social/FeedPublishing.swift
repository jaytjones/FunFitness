//
//  FeedPublishing.swift
//  FunFitness
//
//  What goes into the Friends feed (3.4 step 4) and how it reads. Pure, so it's unit-tested:
//  which recent unlocks to publish, when a streak milestone can be announced again, and the
//  one-line text used in the feed and in notifications.
//
//  UNRELEASED — compiled only with INTERNAL_SOCIAL (Debug + Internal builds, never Release).
//

#if INTERNAL_SOCIAL
import Foundation

nonisolated enum FeedPublishing {
    /// The person's unlocks as the app knows them.
    struct Input: Equatable, Sendable {
        var badges: [(id: String, date: Date)]
        var challenges: [(id: String, year: Int, date: Date)]
        var currentStreak: Int
        var now: Date = Date()

        static func == (lhs: Input, rhs: Input) -> Bool {
            lhs.badges.map(\.id) == rhs.badges.map(\.id)
                && lhs.challenges.map { "\($0.id)#\($0.year)" } == rhs.challenges.map { "\($0.id)#\($0.year)" }
                && lhs.currentStreak == rhs.currentStreak
        }
    }

    /// Unlocks from the last week, plus the streak if it's sitting on a milestone, minus anything
    /// already published. Older unlocks are left out, so turning sharing on doesn't flood friends.
    static func toPublish(_ input: Input, alreadyPublished: Set<String>) -> [(FeedEvent.Kind, Date)] {
        let cutoff = input.now - FeedEvent.publishWindow
        var result: [(FeedEvent.Kind, Date)] = input.badges
            .filter { $0.date >= cutoff }
            .map { (.badgeUnlocked(milestoneID: $0.id), $0.date) }
        result += input.challenges
            .filter { $0.date >= cutoff }
            .map { (.challengeCompleted(challengeID: $0.id, year: $0.year), $0.date) }
        if FeedEvent.isStreakMilestone(input.currentStreak) {
            result.append((.streakMilestone(weeks: input.currentStreak), input.now))
        }
        return result.filter { !alreadyPublished.contains($0.0.key) }
    }

    /// A streak that dropped back below a milestone can announce that milestone again later.
    static func forgetBrokenStreaks(_ published: Set<String>, currentStreak: Int) -> Set<String> {
        published.filter { key in
            guard key.hasPrefix("streak-"), let weeks = Int(key.dropFirst("streak-".count)) else { return true }
            return weeks <= currentStreak
        }
    }
}

nonisolated enum FeedText {
    /// "Sam unlocked “You've covered 5 miles!”", "Sam finished Gobble 'Til You Wobble",
    /// "Sam hit a 8-week streak". `badgeTitle` is the milestone's title when known.
    static func line(for event: FeedEvent, name: String, badgeTitle: String?, challengeTitle: String?) -> String {
        switch event.kind {
        case .badgeUnlocked:
            return badgeTitle.map { "\(name) unlocked “\($0)” 🏅" } ?? "\(name) unlocked a new badge 🏅"
        case .challengeCompleted:
            return challengeTitle.map { "\(name) finished \($0) 🏆" } ?? "\(name) finished a monthly challenge 🏆"
        case .streakMilestone(let weeks):
            return "\(name) hit a \(weeks)-week streak 🔥"
        }
    }

    /// Notification lines for anything newer than `since`: high fives first, then friends' news.
    static func newsLines(highFives: [HighFive], events: [FeedEvent], names: [PersonID: String], since: Date) -> [String] {
        let fives = highFives.filter { $0.date > since }.compactMap { five in
            names[five.from].map { "🙌 \($0) high-fived you!" }
        }
        let news = events.filter { $0.date > since }.compactMap { event in
            names[event.author].map { line(for: event, name: $0, badgeTitle: nil, challengeTitle: nil) }
        }
        return fives + news
    }
}
#endif
