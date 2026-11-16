//
//  LocalDataNoticeTests.swift
//  FunFitnessTests
//
//  The "only on this iPhone" notice shows when data isn't backed up to iCloud and there's
//  something to lose; "Not now" hides it for 30 days.
//

import Testing
import Foundation
@testable import FunFitness

@Suite("Local data notice")
@MainActor
struct LocalDataNoticeTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func localOnlyStates() {
        #expect(LocalDataRule.isLocalOnly(.syncDisabled))
        #expect(LocalDataRule.isLocalOnly(.unavailable))
        #expect(LocalDataRule.isLocalOnly(.restricted))
        #expect(!LocalDataRule.isLocalOnly(.available))
        // Still checking: don't show anything yet.
        #expect(!LocalDataRule.isLocalOnly(.unknown))
    }

    @Test func showsOnlyWithDataToLose() {
        #expect(LocalDataRule.shouldShow(state: .unavailable, activityCount: 1, dismissedAt: nil, now: now))
        #expect(!LocalDataRule.shouldShow(state: .unavailable, activityCount: 0, dismissedAt: nil, now: now))
        #expect(!LocalDataRule.shouldShow(state: .available, activityCount: 50, dismissedAt: nil, now: now))
    }

    @Test func notNowSnoozesForThirtyDays() {
        let day: TimeInterval = 24 * 3600
        #expect(!LocalDataRule.shouldShow(state: .syncDisabled, activityCount: 3, dismissedAt: now.addingTimeInterval(-29 * day), now: now))
        #expect(LocalDataRule.shouldShow(state: .syncDisabled, activityCount: 3, dismissedAt: now.addingTimeInterval(-30 * day), now: now))
    }
}
