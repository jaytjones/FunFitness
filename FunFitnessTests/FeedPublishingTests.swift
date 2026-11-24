//
//  FeedPublishingTests.swift
//  FunFitnessTests
//
//  3.4 step 4: what reaches the Friends feed (recent unlocks only, each once, streak milestones
//  every 4 weeks) and how feed items and notifications read.
//

#if INTERNAL_SOCIAL
import Testing
import Foundation
import CloudKit
@testable import FunFitness

@Suite("Friends feed (3.4)")
@MainActor
struct FeedPublishingTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let sam = PersonID(appleUserID: "apple-sam")

    @Test func onlyRecentUnlocksAndStreakMilestonesArePublished() {
        let input = FeedPublishing.Input(
            badges: [(id: "D2", date: now - 3600), (id: "D1", date: now - 30 * 86_400)],
            challenges: [(id: "gobble-wobble", year: 2026, date: now - 86_400)],
            currentStreak: 8, now: now
        )
        let keys = FeedPublishing.toPublish(input, alreadyPublished: []).map(\.0.key)
        #expect(keys == ["badge-D2", "challenge-gobble-wobble-2026", "streak-8"])
        #expect(FeedPublishing.toPublish(input, alreadyPublished: Set(keys)).isEmpty)
    }

    @Test func offMilestoneStreaksAreNotAnnounced() {
        let input = FeedPublishing.Input(badges: [], challenges: [], currentStreak: 6, now: now)
        #expect(FeedPublishing.toPublish(input, alreadyPublished: []).isEmpty)
    }

    @Test func brokenStreaksCanBeAnnouncedAgain() {
        let published: Set = ["badge-D2", "streak-4", "streak-8"]
        #expect(FeedPublishing.forgetBrokenStreaks(published, currentStreak: 5) == ["badge-D2", "streak-4"])
        #expect(FeedPublishing.forgetBrokenStreaks(published, currentStreak: 1) == ["badge-D2"])
    }

    @Test func feedLinesReadNaturally() {
        let badge = FeedEvent(author: sam, kind: .badgeUnlocked(milestoneID: "D2"), date: now)
        #expect(FeedText.line(for: badge, name: "Sam", badgeTitle: "You've covered 5 miles!", challengeTitle: nil)
                == "Sam unlocked “You've covered 5 miles!” 🏅")
        #expect(FeedText.line(for: badge, name: "Sam", badgeTitle: nil, challengeTitle: nil) == "Sam unlocked a new badge 🏅")
        let streak = FeedEvent(author: sam, kind: .streakMilestone(weeks: 8), date: now)
        #expect(FeedText.line(for: streak, name: "Sam", badgeTitle: nil, challengeTitle: nil) == "Sam hit a 8-week streak 🔥")
    }

    @Test func newsLinesPutHighFivesFirstAndSkipOldOnes() {
        let me = PersonID(appleUserID: "apple-me")
        let lines = FeedText.newsLines(
            highFives: [HighFive(from: sam, to: me, eventKey: nil, date: now),
                        HighFive(from: sam, to: me, eventKey: "badge-D1", date: now - 7200)],
            events: [FeedEvent(author: sam, kind: .streakMilestone(weeks: 4), date: now)],
            names: [sam: "Sam"], since: now - 3600
        )
        #expect(lines == ["🙌 Sam high-fived you!", "Sam hit a 4-week streak 🔥"])
    }

    @Test func feedRecordsRoundTrip() {
        for kind: FeedEvent.Kind in [.badgeUnlocked(milestoneID: "D2"), .challengeCompleted(challengeID: "x", year: 2026),
                                      .streakMilestone(weeks: 12)] {
            let record = CKRecord(recordType: SocialRecords.eventType)
            SocialRecords.apply(kind, date: now, to: record)
            #expect(SocialRecords.feedEvent(from: record, author: sam) == FeedEvent(author: sam, kind: kind, date: now))
        }
        let five = HighFive(from: sam, to: PersonID(appleUserID: "apple-me"), eventKey: nil, date: now)
        let record = CKRecord(recordType: SocialRecords.highFiveType)
        SocialRecords.apply(five, to: record)
        #expect(SocialRecords.highFive(from: record) == five)
    }
}
#endif
