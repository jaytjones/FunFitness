# FunFitness Phase 1.3 Session Summary
**Date:** 2026-07-31  
**Phase:** 1.3 — "The Habit Loop"

---

## Overview

Phase 1.3 delivered weekly activity streaks with shield protection, a silly-title rank system, granular local notifications, and a WidgetKit home screen widget. All 60 tests pass (57 unit + 3 UI). Both the main app and the widget extension build cleanly.

---

## New Files

| File | Purpose |
|------|---------|
| `StreakEngine.swift` | Pure streak computation: `WeekKey` (ISO year+week, `Sendable/Codable/Comparable`), `StreakResult`, `@MainActor StreakEngine` with `compute()`, shield encode/decode, `activateShield()` |
| `StreakRecord.swift` | `@Model` persisting current streak, longest streak, shields available, and JSON-encoded shielded week keys |
| `SillyTitleEngine.swift` | 8-tier title + rank system (Unranked → Diamond) derived from achievement unlock count |
| `NotificationManager.swift` | `@MainActor` singleton managing 4 notification categories: streak-at-risk, milestone nudge, weekly recap, comparison of the day |
| `FunFitnessWidget/FunFitnessWidget.swift` | WidgetKit widget with small (2×2, streak count) and medium (4×2, streak + progress bars + silly title) layouts |
| `FunFitnessWidget/FunFitnessWidgetData.swift` | `WidgetDataKey` constants and `WidgetSnapshot.load()` — shared data layer via App Group `UserDefaults` |

> **Widget target note:** The `FunFitnessWidgetExtension` target was created manually in Xcode (File › New › Target › Widget Extension). Xcode also generated `AppIntent.swift`, `FunFitnessWidgetBundle.swift`, `FunFitnessWidgetControl.swift`, `FunFitnessWidgetLiveActivity.swift`, and `Info.plist` as template stubs. The bundle and live activity stubs are left in place for Phase 1.4.

---

## Modified Files

### `AppViewModel.swift`
- Added streak state: `currentStreak`, `longestStreak`, `isActiveThisWeekStreak`, `shieldsAvailable`
- Added `pendingShieldActivation: Bool` — flag HomeView sets to request shield activation from ContentView
- Added `sillyTitle: SillyTitle` computed property via `SillyTitleEngine`

### `UserProfile.swift`
- Added 4 notification preference booleans: `notifyStreakAtRisk`, `notifyMilestoneNudge`, `notifyWeeklyRecap`, `notifyComparisonOfDay` — all default `false` (opt-in)
- No migration needed: new optional columns added to an existing `@Model`; SwiftData back-fills defaults on read

### `FunFitnessApp.swift`
- Added `StreakRecord.self` to the `Schema` — requires a lightweight SwiftData migration on first launch after upgrade

### `HomeView.swift`
- Added `StreakCard` — fire-gradient (orange/red) when streak > 0, dark gradient when streak = 0; shows streak count, longest streak, and a "Use Shield" button (visible when shields available, streak > 0, and current week inactive)
- Added `SillyTitleBanner` — displays rank emoji, title, rank name, and badge count
- Shield confirm `Alert` bridges to ContentView via `viewModel.pendingShieldActivation`

### `ProfileView.swift`
- Added `NotificationSettingsSection` — detects authorization status on appear; shows a permission-request button when not authorized; shows 4 `Toggle` rows (one per notification category) when authorized
- Added `NotificationToggleRow` component

### `ContentView.swift`
- Added `@Query private var streakRecords: [StreakRecord]`
- Added `updateStreak()` — recalculates streak from scratch on every activity change; syncs result to `viewModel` and `StreakRecord`
- Added `activateStreakShield()` — calls `StreakEngine.activateShield(record:)` and re-runs `updateStreak()`
- Added `scheduleNotificationsIfNeeded()` — checks all 4 per-category profile flags; schedules or cancels accordingly after every activity change
- Added `writeWidgetData()` — writes 9 keys to App Group `UserDefaults` and calls `WidgetCenter.shared.reloadAllTimelines()`
- Added `onChange(of: viewModel.pendingShieldActivation)` to process shield requests from HomeView
- Added `import WidgetKit` and `import UserNotifications`

### `FunFitnessTests.swift`
- Added `import Foundation` (required for `Calendar`/`Date` in new test suites)
- New `@Suite("StreakEngine")` — 7 tests
- New `@Suite("SillyTitleEngine")` — 4 tests

---

## Streak Engine Design

### WeekKey
A `Hashable, Comparable, Codable, Sendable` struct identifying a calendar week by ISO `yearForWeekOfYear` + `weekOfYear`. Using `yearForWeekOfYear` (not `.year`) is what makes the streak math correct across the year boundary (e.g., Dec 31 in ISO week 1 of the following year).

```
WeekKey(year: 2026, week: 52) < WeekKey(year: 2027, week: 1)  // correct
```

### Compute Algorithm
`StreakEngine.compute()` is intentionally **recomputed from scratch** on every activity change rather than maintained incrementally. This handles backdated entries, edits, and deletions without any stale-state bugs. The performance cost is negligible for the expected data size (thousands of activities at most).

Walk direction: backwards from the current week. If the current week has activity (or is shielded), start counting from there. If not, check the previous week — if that's active, the streak is still alive (user just hasn't logged yet this week).

### Streak Shields
- One shield available at a time; regenerates once per calendar month
- Activation inserts the current `WeekKey` into a JSON-encoded array stored in `StreakRecord.shieldedWeekKeysJSON`
- Shielded weeks are treated identically to active weeks during streak computation
- `StreakEngine.activateShield(record:)` / `encodeShieldedWeeks(_:)` / `shieldedWeeks(from:)` are the only points that touch the JSON — `StreakRecord` itself never holds `Set<WeekKey>` to avoid Swift 6 main-actor conformance warnings on `@Model` computed properties

### Swift 6 Concurrency Note
`StreakEngine` is marked `@MainActor` because `StreakEngine.compute()` accesses `ActivityLog` properties (`loggedAt`) and `ActivityLog` is a `@Model` class (implicitly `@MainActor`). `WeekKey` is marked `Sendable` to allow it to cross actor boundaries without warnings. `Set<WeekKey>` is kept out of `@Model` computed properties — decoded only inside `@MainActor` functions — to avoid the "main actor-isolated conformance cannot be used in nonisolated context" warning that fires when `@Model` classes own `Set<CustomHashable>` properties.

---

## Notification Design

| Category | Identifier | Trigger | Fires when |
|---|---|---|---|
| Streak At Risk | `STREAK_AT_RISK` | Calendar: Thursday 7 PM | Toggle on + no activity logged this week + streak > 0 |
| Milestone Nudge | `MILESTONE_NUDGE_distance` / `_weight` | Time interval: 2 hours | Toggle on + progress ≥ 90% toward next milestone |
| Weekly Recap | `WEEKLY_RECAP` | Calendar: Sunday 8 PM, repeating | Toggle on |
| Comparison of Day | `COMPARISON_DAY` | Calendar: 9 AM daily, repeating | Toggle on |

All notifications are **opt-in** — no notification is ever scheduled for a category whose toggle is off. `scheduleNotificationsIfNeeded()` also explicitly cancels any pending request when a toggle is turned off, so disabling a toggle takes effect immediately without waiting for the scheduled fire time.

---

## Widget Design

### Data Flow
```
ActivityLog insert/edit/delete
    → ContentView.writeWidgetData()
        → UserDefaults(suiteName: "group.com.discoverhealthquest.funfitness")
            → WidgetCenter.shared.reloadAllTimelines()
                → FunFitnessProvider.getTimeline()
                    → WidgetSnapshot.load()
```

The widget reloads within seconds of any activity change. The 30-minute `TimelineProvider` refresh is a fallback for edge cases (e.g., app backgrounded without triggering an explicit reload).

### App Group
Both `FunFitness` and `FunFitnessWidgetExtension` targets carry the `com.apple.security.application-groups` entitlement with value `group.com.discoverhealthquest.funfitness`. This was added via the `AddEntitlement` MCP tool after the widget target was created.

### Widget Layouts

| Family | Content |
|---|---|
| `.systemSmall` | Streak count (large), fire/grey gradient, active-this-week checkmark |
| `.systemMedium` | Left: streak count (gradient); Right: silly title + run progress bar + lift progress bar |

---

## Silly Title Tiers

| Min unlocked | Title | Rank |
|---|---|---|
| 0 | Future Legend | Unranked 🎯 |
| 1 | Rookie Reps | Starter 🌱 |
| 2 | Aspiring Animal Accumulator | Iron ⚙️ |
| 4 | Certified Hippo Hoister | Bronze 🥉 |
| 8 | Elite Elephant Wrangler | Silver 🥈 |
| 12 | Legendary Giraffe Stacker | Gold 🥇 |
| 16 | Mythical Whale Chaser | Platinum 🌟 |
| 20 | Grand Poobah of Perpetual Motion | Diamond 💎 |

---

## Test Results

| Suite | Tests | Result |
|---|---|---|
| ComparisonEngineTests | 19 | All passed |
| UnitConverterTests | 13 | All passed |
| AppViewModelTests | 14 | All passed |
| StreakEngineTests | 7 | All passed |
| SillyTitleEngineTests | 4 | All passed |
| FunFitnessUITests | 3 | All passed |
| **Total** | **60** | **60 passed, 0 failed** |

New in 1.3: 11 unit tests (7 streak + 4 titles). Running total: 29 (1.1) → 46 (1.2) → 60 (1.3).

---

## Exit Criteria — All Met

| Criterion | Status |
|---|---|
| Streak math survives timezone changes and DST | ✅ Uses `yearForWeekOfYear` ISO components throughout |
| Shields work | ✅ Activate from HomeView; JSON-persisted; monthly regeneration |
| Notifications never fire for opted-out users | ✅ Per-category booleans; explicit cancel on toggle-off |
| Widget updates within minutes of a logged activity | ✅ `WidgetCenter.shared.reloadAllTimelines()` on every write |

---

## Deferred to Phase 1.4+

- `FunFitnessWidgetLiveActivity.swift` — Live Activity for active workout tracking (1.4)
- `FunFitnessWidgetControl.swift` — Control Center widget (1.4)
- Streak persistence across app deletion — not in scope; will be addressed if/when CloudKit sync ships (2.1)
- Notification permission prompt timing — currently shown on demand in ProfileView; could be moved to onboarding flow in a future pass

---

## Next: Phase 1.4 — "It Logs Itself"

Per the plan: HealthKit read integration (auto-import walks/runs/strength), HealthKit write-back, one-tap repeat of last activity, Siri Shortcut ("log my run"), and illustrated share cards for milestones/streaks/titles.

**Prerequisite:** The units infrastructure (1.2) is complete, so HealthKit's SI return values (meters, kilograms) will map cleanly to the existing storage convention without any conversion layering debt.
