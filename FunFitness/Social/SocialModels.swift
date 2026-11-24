//
//  SocialModels.swift
//  FunFitness
//
//  3.4 "Bring Your Friends": the values every social backend shares (Jay, 2026-11-24). Apple-only
//  for now (Sign in with Apple + CloudKit), but nothing here knows about CloudKit, so a cross-
//  platform backend later replaces only the `SocialService` implementation.
//  Design and limitations: docs/20261124_3.4_design_decisions.md.
//
//  UNRELEASED — compiled only with INTERNAL_SOCIAL (Debug + Internal builds, never Release).
//

#if INTERNAL_SOCIAL
import Foundation
import CryptoKit

/// Who someone is in Friends: the SHA-256 of their Sign in with Apple user ID. Never the iCloud
/// user record ID, which can't leave Apple; a future backend sees the same Apple ID in its tokens
/// and can derive the same value, so accounts carry over.
nonisolated struct PersonID: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }

    init(appleUserID: String) {
        rawValue = SHA256.hash(data: Data(appleUserID.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    var description: String { rawValue }
}

/// What friends may see. Everything starts off (Jay, 2026-11-24): a new profile shares nothing
/// beyond its name, avatar and style until the person turns something on.
nonisolated struct SharingSettings: Equatable, Codable, Sendable {
    /// Badge and monthly-challenge unlocks appear in friends' feeds.
    var shareUnlocks = false
    /// Streak milestones appear in friends' feeds.
    var shareStreak = false
    /// Weekly Effort Points, needed for duels and the friends leaderboard.
    var shareWeeklyEffort = false

    static let nothingShared = SharingSettings()
}

/// The public face of a person: a chosen name and emoji, never their Apple ID email.
nonisolated struct SocialProfile: Identifiable, Equatable, Codable, Sendable {
    let id: PersonID
    var displayName: String
    var avatarEmoji: String
    /// The person's style (`StyleID` raw value), so a friend's card can wear it.
    var styleID: String
    var sharing: SharingSettings = .nothingShared

    static let displayNameLimit = 30

    /// Trimmed and capped; nil when nothing usable is left.
    static func cleanedName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(displayNameLimit))
    }
}

/// A one-time way to become friends: shared as a link or shown as a short code (Jay: both).
nonisolated struct FriendInvite: Identifiable, Equatable, Codable, Sendable {
    let code: String
    let from: PersonID
    let createdAt: Date
    let expiresAt: Date
    var id: String { code }

    static let lifetime: TimeInterval = 7 * 86_400
    /// Readable aloud and typeable: no 0/O, 1/I/L.
    static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    static let codeLength = 6

    func isExpired(at date: Date) -> Bool { date >= expiresAt }

    /// The link form of the invite. The scheme opens the app; a web landing page can come later.
    var link: URL? { URL(string: "funfitness://friend/\(code)") }

    static func makeCode<G: RandomNumberGenerator>(using generator: inout G) -> String {
        String((0..<codeLength).map { _ in alphabet.randomElement(using: &generator)! })
    }

    /// Accepts "abc-234", " ABC234 " or a funfitness://friend/ link; nil if it can't be a code.
    static func normalizedCode(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: text), url.scheme == "funfitness", url.host() == "friend" {
            text = url.lastPathComponent
        }
        let code = text.uppercased().filter { $0 != "-" && $0 != " " }
        guard code.count == codeLength, code.allSatisfy(alphabet.contains) else { return nil }
        return code
    }
}

/// Two people who accepted each other. Blocking hides each from the other in both directions.
nonisolated struct Friendship: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let people: Set<PersonID>
    let since: Date
    var blockedBy: PersonID?

    var isBlocked: Bool { blockedBy != nil }

    func includes(_ person: PersonID) -> Bool { people.contains(person) }

    func other(than person: PersonID) -> PersonID? { people.first { $0 != person } }
}

/// Something a friend did, shown in the feed if their sharing allows it. Its `key` names what
/// happened ("badge-D2"), so publishing the same unlock again replaces it instead of duplicating.
nonisolated struct FeedEvent: Identifiable, Equatable, Codable, Sendable {
    enum Kind: Equatable, Codable, Sendable {
        /// A milestone badge (`Milestone.id`).
        case badgeUnlocked(milestoneID: String)
        /// A monthly challenge (`Challenge.id`) in a given year.
        case challengeCompleted(challengeID: String, year: Int)
        /// A streak reaching this many weeks.
        case streakMilestone(weeks: Int)

        /// Stable per person: one feed item per badge, per challenge year, per streak length.
        var key: String {
            switch self {
            case .badgeUnlocked(let id): "badge-\(id)"
            case .challengeCompleted(let id, let year): "challenge-\(id)-\(year)"
            case .streakMilestone(let weeks): "streak-\(weeks)"
            }
        }

        /// Whether these sharing settings allow publishing this kind.
        func isShared(by sharing: SharingSettings) -> Bool {
            switch self {
            case .badgeUnlocked, .challengeCompleted: sharing.shareUnlocks
            case .streakMilestone: sharing.shareStreak
            }
        }
    }

    let author: PersonID
    let kind: Kind
    let date: Date

    var key: String { kind.key }
    /// Unique across friends (two friends can unlock the same badge).
    var id: String { "\(author.rawValue)/\(key)" }

    /// How long items stay in the feed.
    static let feedWindow: TimeInterval = 30 * 86_400
    /// Unlocks newer than this are published when sharing is (or gets) turned on.
    static let publishWindow: TimeInterval = 7 * 86_400
    /// Streak milestones worth announcing: every 4 weeks.
    static func isStreakMilestone(_ weeks: Int) -> Bool { weeks >= 4 && weeks % 4 == 0 }
}

/// One per sender, recipient and feed item, so a friend can't be spammed.
nonisolated struct HighFive: Identifiable, Equatable, Codable, Sendable {
    let from: PersonID
    let to: PersonID
    /// The recipient's feed item it answers (`FeedEvent.key`), or nil for a general high five.
    let eventKey: String?
    let date: Date

    var id: String { "\(from.rawValue)/\(to.rawValue)/\(eventKey ?? "general")" }
}

/// A weekly head-to-head, scored in Effort Points so walking, lifting and yoga compete fairly
/// (Jay, 2026-11-24). Each side posts only its own total; both phones work out the same result.
nonisolated struct Duel: Identifiable, Equatable, Codable, Sendable {
    enum Status: Equatable, Codable, Sendable {
        case pending, active, declined
    }

    let id: UUID
    let challenger: PersonID
    let opponent: PersonID
    /// Start of the calendar week the duel covers.
    let weekStart: Date
    var status: Status
    /// Each side's posted Effort Points for the week. Unverified: they come from that person's app.
    var points: [PersonID: Double] = [:]

    var people: Set<PersonID> { [challenger, opponent] }
}

// MARK: - Rules

nonisolated enum DuelEngine {
    enum Outcome: Equatable, Sendable {
        case waiting
        case inProgress(leader: PersonID?)
        case won(by: PersonID)
        case tie
    }

    /// The duel's state at `now`. Before its week ends it's in progress (leader = more points so
    /// far, nil when level); after, the higher total wins. A side that never posted counts as 0.
    static func outcome(of duel: Duel, now: Date, calendar: Calendar = .current) -> Outcome {
        guard duel.status == .active else { return .waiting }
        let mine = duel.points[duel.challenger] ?? 0
        let theirs = duel.points[duel.opponent] ?? 0
        let leader: PersonID? = mine == theirs ? nil : (mine > theirs ? duel.challenger : duel.opponent)
        guard let week = calendar.dateInterval(of: .weekOfYear, for: duel.weekStart), now >= week.end else {
            return .inProgress(leader: leader)
        }
        return leader.map { .won(by: $0) } ?? .tie
    }
}

/// Friends-only leaderboard of this week's Effort Points (never global). People who don't share
/// their weekly effort aren't listed.
nonisolated enum FriendsLeaderboard {
    struct Row: Equatable, Sendable {
        let person: PersonID
        let points: Double
        let rank: Int
    }

    /// Highest first; equal points share a rank ("1, 2, 2, 4"), then name order keeps it stable.
    static func rows(points: [PersonID: Double], names: [PersonID: String]) -> [Row] {
        let sorted = points.sorted { lhs, rhs in
            lhs.value != rhs.value
                ? lhs.value > rhs.value
                : (names[lhs.key] ?? lhs.key.rawValue) < (names[rhs.key] ?? rhs.key.rawValue)
        }
        var rows: [Row] = []
        for (index, entry) in sorted.enumerated() {
            let rank = index > 0 && sorted[index - 1].value == entry.value ? rows[index - 1].rank : index + 1
            rows.append(Row(person: entry.key, points: entry.value, rank: rank))
        }
        return rows
    }
}
#endif
