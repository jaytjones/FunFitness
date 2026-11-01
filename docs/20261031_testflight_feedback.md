# FunFitness — TestFlight Feedback Review (2026-10-31)

All 19 TestFlight submissions to date, pulled with `scripts/feedback` (raw report:
`docs/feedback/20261031_feedback.md`, screenshots and crash log in `docs/feedback/assets/`; these are
gitignored and stay on Jay's Mac, since they hold tester details). All from JT Jones.

- **New since the build 3 review (4 items):** FB-0001 to FB-0004, against 3.1 (6) and 3.1 (9).
  Each one below has the issue, its cause in the code, a fix, and a size estimate.
- **Already reviewed (15 items):** FB-0005 to FB-0019 are the 2026-10-10 to 10-13 feedback covered in
  `20261013_testflight_feedback_build3.md` (App Store Connect calls that build "1.0 (4)"). They're
  mapped to that doc's IDs with current status at the end of this doc.

**Size:** **S** = under half a day · **M** = 1–2 days · **L** = several days or needs design first.
Estimates include tests.

---

## Summary

| # | Feedback | Build | Type | Size | Priority | Status |
|---|---|---|---|---|---|---|
| FB-0002 | Crash during a live strength session | 3.1 (9) | Crash | S | **P0** | ✅ Fixed for build 10 |
| FB-0001 | Deleted set still shows in the live session; removing a set is hard | 3.1 (9) | Bug + UX | M | **P1** | ✅ Fixed for build 10 |
| FB-0004 | Milestone says "You've run" even for walks | 3.1 (6) | Copy | S | P2 | ✅ Fixed for build 10 |
| FB-0003 | Live walk banner looks like every other card; should be pinned | 3.1 (6) | UX | M | P2 | ✅ Built for build 10, needs on-device check |

**Also for build 10 (not tester feedback):** the build was broken by `docs/design/` being added to the app
target in `1c07e66` (duplicate `.md` names in the bundle). All docs were removed from the app's Copy Bundle
Resources, so they no longer ship inside the app.

Older items still open: **C3** named exercises (L), **C6** muscle groups (M), **C7** workout score
(M, design draft waiting on answers), **C8** weather/music (parked), **D1** "improve the floating action
button" (postponed to a full UI refresh; see Decisions).

---

## FB-0002 · Crash during a live strength session — P0 · S

> **Status (2026-10-31): fixed for build 10.** `UIColor.appBackground` / `appCard` are now `nonisolated static let`
> providers that `Color.appBackground` / `appCard` wrap. `AdaptiveColorTests` resolves both colors off the main thread.

> "Crash occured in the middle of the live strength session" — 2026-10-31 14:49, 3.1 (9), iOS 27.2 beta

**What the crash log shows** (`assets/FB-0002.crash`): `EXC_BREAKPOINT` on a background render
thread (thread 5) inside `closure #1 in static Color.appBackground.getter`
(`SharedComponents.swift:42`). Swift's concurrency runtime stopped the app on purpose because main-actor
code ran off the main thread.

**Cause:** The app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so the closures passed
to `UIColor { traits in … }` in `appBackground` and `appCard` are inferred as `@MainActor`. UIKit
calls these closures from whatever thread is resolving the color. Here that was SwiftUI's
background render thread, and the main-actor check traps. Nothing about the strength session itself
caused it. The session screen just redraws a lot (clock, rest timer, Live Activity), so it's the
most likely place for the background render to happen. It could happen on any screen that uses these
colors (most of them), and more often on iOS 27.2.

**Fix:**
- Mark the two color providers `nonisolated`, e.g. move the closure into a
  `nonisolated static func` (or `nonisolated(unsafe)` let), so it can run on any thread. The closures
  only read `traits` and build a `UIColor`, so they're safe off the main thread.
- Search for other `UIColor { … }`, `UIImage` providers, and other UIKit callbacks that UIKit
  may call off the main thread. Right now only these two exist.
- **Test:** a unit test that resolves both colors in a `Task.detached` (off the main actor) for light
  and dark traits. Before the fix it traps; after, it passes. Also run a strength session on device
  for several minutes while switching light/dark and locking/unlocking.

**Size: S** (1–2 hours including the test).

---

## FB-0001 · Deleted set still shows in the live session — P1 · M

> **Status (2026-10-31): fixed for build 10.** `StrengthSessionManager.syncWithStore()` rebuilds the live
> set list from the saved logs. ActivityWriter's delete / deleteSession / removeFromSession / ungroupSession
> and History's `applyEdit` call it. If the stored session was removed, the next set starts a new one. The
> session screen's set rows have swipe-to-delete (iOS 27+, via `swipeActionsContainer()`) plus a long-press
> "Delete Set" menu and a VoiceOver action, which also covers iOS 18–26. No Undo. 6 new tests.

> "I deleted an erroneously added set from the activity, but it is still visible in my live strength
> session. A) it should be easier to remove a set from the live strength activity, and B) that set
> should be deleted from everywhere, including the live session" — 2026-10-31 14:00, 3.1 (9)

The screenshot shows the session detail in History after the delete (1 set, 135 lbs × 20), while the
live session screen still listed the deleted set.

**Cause (B, the bug):** `StrengthSessionManager` keeps its own in-memory copy of the sets
(`StrengthSession.sets`, an array of `StrengthSet` whose `id` matches the saved
`ActivityLog.id`). Deleting a log goes through `ActivityWriter.delete` / `deleteSession` /
`removeFromSession`, which update SwiftData but never tell the manager. So the live screen, its
set count and total, the "Repeat last set" button, the Live Activity, and the end-of-session
summary all still include the deleted set. "Repeat last set" could re-log a set you just deleted.

**Fix:**
- **B, keep the live session in sync:** add `StrengthSession.removeSet(id:)` and a
  `StrengthSessionManager.setRemoved(id:)` that updates the session and refreshes the Live
  Activity (rest timer stays as is). Call it from `ActivityWriter.delete`, `deleteSession` (for each
  set in that session), and `removeFromSession`. Edits to a set's weight/reps in History should
  update the live copy the same way (`setEdited`).
- **A, delete from the live screen:** add swipe-to-delete (or a ⋯ / context menu "Delete Set") on
  rows in the "This session" list in `StrengthSessionView.setList`. It calls `ActivityWriter.delete`,
  which updates the live copy via the hook above. Show "Set N" numbers as positions after the delete.
  No Undo (Jay, 2026-10-31).
- **Edge cases:** deleting the only set → session shows "No sets yet", and the stored
  `WorkoutSession` is removed or left empty (match how History handles an empty session today).
  Deleting during rest → keep the timer. Milestones already earned stay earned (same as deleting
  any log).
- **Tests:** `StrengthSession.removeSet` (unit), and in the serialized `StrengthSessionManagerTests`
  suite: log 2 sets → delete one via `ActivityWriter.delete` → `session.setCount == 1`,
  `lastSet` is the remaining one, and `repeatLastSet` re-logs the right set.

**Size: M**, about 1 day (B alone is S; A is the swipe action plus edge cases and tests).

---

## FB-0004 · Milestone says "You've run" for walks — P2 · S

> **Status (2026-10-31): fixed for build 10.** Distance milestones read "You've covered 17.5 miles!" / "…km!".
> Widget: medium row label "Run" → "Distance" (walking icon); empty-state text "Log your first run!" →
> "Log a walk or run!" (shorter than first proposed, to fit the widget). Siri: added "Log my walk in
> FunFitness" next to "Log my run". The comparison text is unchanged.

> "This says 'run' - should be generalized to capture walks as well." — 2026-10-17, 3.1 (6)
> (screenshot: "You've run 17.5 miles! That's a mountain lion's longest night of prowling for prey!")

**Cause:** Distance milestones are cumulative across walks, runs and Health imports, but the title
is hard-coded in `ComparisonEngine.swift:41–42` ("You've run \(amount) miles!" / km).

**Fix (confirmed by Jay, 2026-10-31):** Use neutral wording: **"You've covered 17.5 miles!"**. The same wording appears in a few other places, so it's worth one
quick pass:
- `FunFitnessWidgetData.swift:42/55/69` "Log your first run!" → "Log your first walk or run!"
- Widget "Run" label (`FunFitnessWidgets.swift` ~L162) → "Distance" (or "Walk/Run")
- Leave the Siri phrase "Log my run" (it's a voice trigger), but consider adding "Log my walk".
- Milestone comparison text that mentions running (e.g. D4 "the legendary run from Marathon")
  describes the comparison, not the person, so leave it.
- Update `Localizable.xcstrings` and any tests that check the title text.

**Size: S** (about an hour).

---

## FB-0003 · Live walk banner should stand out / be pinned — P2 · M

> **Status (2026-10-31): built for build 10.** New `NowTrackingBar.swift`: a pinned bar on every tab while a
> walk/run or strength session is running or waiting for review, e.g. "📍 Walk · 1.2 mi · 18:42" or
> "⏱ Strength · 3 sets · Rest 0:45". Tap to reopen. iOS 26.1+ uses `tabViewBottomAccessory(isEnabled:)` (Liquid
> Glass; shrinks inline when the tab bar minimizes). Earlier iOS pins it with `safeAreaInset`. Home now shows
> the Track / Strength cards only when idle. Checked with Xcode previews (dark, light, AX3) and 4 unit tests
> for the bar text. **Not yet tried on a running app**: the simulator automation tools need an iOS 27 simulator.

> "Live walk tracking needs to be differentiated from the other cells on the page. Maybe a
> persistent, UI element that is near the top of the page or sticky to the bottom of the page -
> can use design best practices to determine where. Can also use dynamic island...?"
> — 2026-10-17, 3.1 (6)

**What happens now:** While a walk is recording, Home shows "Tracking your walk · 0.0 mi so far ·
Open" as a regular card partway down the scroll (`HomeView.swift` ~L440–L490), styled like the
Strength Session and Repeat Last cards around it. You have to scroll to find it, and it isn't on
the other tabs. The Dynamic Island / Live Activity part is **already done** (B1b, plus distance in
the compact island since `ff977f0`).

**Fix (chosen by Jay, 2026-10-31):** a compact **pinned "now tracking" bar just above the tab bar**, on every
tab, while a walk/run or strength session is active, like the Music/Podcasts mini-player.
- Content: icon + "Walk · 1.2 mi · 18:42" (live), tap to open the tracking screen; for strength,
  "Strength · 3 sets · Rest 0:45".
- Implementation: a `safeAreaInset(edge: .bottom)` on the root `TabView` content (works on iOS 18),
  or iOS 26's tab bar bottom accessory behind an availability check for the native Liquid Glass look.
  Reuse the existing title/subtitle logic from the Home card.
- Remove the Home card while the bar is showing, or keep only the idle "Track a Walk or Run" / "Start"
  version.
- Check VoiceOver order, Dynamic Type at large sizes, and that it doesn't cover the last row of
  scroll content.

**Size: M** (1–2 days). A cheaper option (**S**): move the active card to the top of Home with a
distinct "live" style (pulsing dot, accent border). That makes it stand out but not persistent.

---

## Older feedback (FB-0005 to FB-0019) — status

Details are in `20261013_testflight_feedback_build3.md`.

| FB | Feedback | Doc ID | Status |
|---|---|---|---|
| FB-0005 | Type a rep count; add sets; named exercises | A4, C2, C3 | A4 ✅ 2.4.4 · C2 ✅ 3.1 (7) · **C3 open (L)**, planned ~3.3 with bundled JSON |
| FB-0006 | Road / track / trail / treadmill | C9 | ✅ 3.1 |
| FB-0007 | Medium widget lacks context | B3 | ✅ 3.1 (7) |
| FB-0008 | Live walk/run tracking; easier live logging | B1 | ✅ 3.1 (GPS, Live Activity, live strength) |
| FB-0009 | Sessions / workouts | C1 | ✅ 3.1 (7) |
| FB-0010 | What is "Reps" for? | A5 | ✅ 2.4.4 (hint added) |
| FB-0011 | Save workouts to Health; calories; muscle groups | C5, C4, C6 | C4/C5 ✅ 3.1 (8) · **C6 open (M)**, needs C3 first |
| FB-0012 | Streak count overlaps share icon | A1 | ✅ 2.4.4 |
| FB-0013 | Activity list hard to find | A6 | ✅ 2.4.4 (Recent Activity on Home, History label) |
| FB-0014 | Time each session; estimate calories | C4 | ✅ 3.1 (8) |
| FB-0015 | Improve the floating action button | D1 | **Postponed** to a full UI refresh: the button looks bland and nondescript |
| FB-0016 | Notes, weather, indoor/outdoor, music | C8 | Notes + indoor/outdoor ✅ 3.1 (8) · weather (M, WeatherKit) and music parked |
| FB-0017 | Workout "score" that isn't calories | C7 | **Design draft** (`20261017_workout_score_design.md`), 4 open questions |
| FB-0018 | Default to last-used activity type | A3 | ✅ 2.4.4 |
| FB-0019 | Reps on by default | A2 | ✅ 2.4.4 |

---

## Suggested order

1. ~~**Build 10:** FB-0002, FB-0001, FB-0004, FB-0003~~ — all done 2026-10-31. Next: commit, bump to build
   10 per `release_checklist.md`, upload, and check the items on device (see each item's status note).
2. **Then:** answer C7's open questions; C3 → C6 with the ~3.3 content move. D1 waits for a UI refresh.

## Decisions (Jay, 2026-10-31)

- **FB-0004:** use the recommended wording, "You've covered 17.5 miles!", plus the related copy pass.
- **FB-0003:** build the recommended pinned "now tracking" bar above the tab bar.
- **FB-0001:** swipe-to-delete is enough; no Undo.
- **FB-0015 / D1:** postponed until a full UI refresh. The issue is that the `+` button looks bland and
  nondescript; revisit its styling then.
