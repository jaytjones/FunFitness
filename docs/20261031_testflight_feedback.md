# FunFitness — TestFlight Feedback Review (2026-10-31)

All 20 TestFlight submissions to date, pulled with `scripts/feedback` (raw reports:
`docs/feedback/20261031_feedback.md` and `20261112_feedback.md`, screenshots and crash log in `docs/feedback/assets/`; these are
gitignored and stay on Jay's Mac, since they hold tester details). All from JT Jones.

- **New 2026-11-24 (3 items):** FB-0021 and FB-0022 against 3.2 (16), FB-0023 against 3.1 (13).
- **New 2026-11-12 (1 item):** FB-0020, against 3.1 (12).
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
| FB-0020 | FunFitness workouts don't show in the Fitness / Activity app | 3.1 (12) | Bug + UX | S–M | **P1** | Items 1–2 in 3.1 (13); items 3–4 + indoor tracking in 3.2 (14); on-device check next |
| FB-0021 | November challenge shows no progress after distance and strength workouts | 3.2 (16) | Bug (design gap) | S–M | **P1** | ✅ Fixed for 3.2 (18); on-device check next |
| FB-0022 | See previous sets (reps × weight) per exercise; progress-over-time charts | 3.2 (16) | Feature | M | P2 | ✅ Both parts for 3.2 (19); on-device check next |
| FB-0023 | Does the app track treadmill walks? | 3.1 (13) | Question | — | — | ✅ Answered by 3.2 (14)+ Indoor tracking; confirm on 3.2 (16) |

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

## FB-0020 · Workouts don't show in the Fitness / Activity app — P1 · S–M

> **Status (2026-11-15): built for 3.2 (14).** Jay's retest on build 13 still showed nothing in Health. Both
> tries were skipped on purpose, with no message: a treadmill walk had no GPS distance (Save was
> disabled), and a 30-second strength session was under the 1-minute minimum. Fixes: an Outdoor /
> Indoor choice when starting a walk/run (indoor counts distance from steps and saves an indoor workout),
> "Too short to save to Apple Health" on short strength sessions, and skipped saves now log and show the
> Home banner. Item 3 (rename to "Save workouts to Apple Health" + a one-time prompt on the summaries)
> and item 4 (estimated active energy on tracked walks/runs) are built too. Jay confirmed a strength
> session over a minute saves to Health.

> **Status (2026-11-12): cause found (cause 2).** "Save logs to Apple Health" was on, but in Settings →
> Health → FunFitness, write access was off for everything except Active Energy. Health had **no
> FunFitness entries**, so every workout save was declined and dropped without a message. Active Energy
> was probably on because it was added later (3.1 C5): HealthKit asks only once per data type, so that
> later prompt was the only one that asked for it. Jay has turned write access back on.
> The app can't ask again for types that were declined. It has to notice and send the user to Settings.
>
> **Built (2026-11-12, local, not yet on device), items 1 + 2:** saves return `HealthSaveResult` (saved /
> access off / failed) and log errors (`os.Logger`, category "HealthKit"). `HealthAccessNotice` ("access is off
> · Open Settings") shows in the Log sheet (distance), the walk/run summary and Profile when write-back is on but
> declined. The strength summary shows Saving… / Saved / failed. Home shows a dismissible banner after a failed
> save. Manual distance logs gain Walk/Run + optional Duration, and the date is the "Start Time": a duration gives a
> real workout; with no duration it's a plain distance sample. New `ActivityLog.durationSeconds` /
> `distanceKindRaw` (optional; **needs a CloudKit production schema deploy**). Repeat Last keeps both. 7 new tests
> in `ManualDistanceTimingTests`.
>
> **Manual distance logs (Jay, 2026-11-12):** saving them as 60-second walks is wrong. Save the real
> time and distance, and treat the entered date/time as the **start** (standard: Health's "Add Data"
> and Strava's manual entry both ask for start + duration). See "Manual distance logs" below.

> "Why don't fun fitness workouts display in the iOS fitness/activity app?" — 2026-11-07 14:16,
> 3.1 (12), iOS 27.2 (screenshot: the live Walk tracking screen, 2:16 · 0.1 mi)

**What the app does now:** FunFitness can save workouts to Health, and the Fitness app lists
third-party Health workouts. A finished GPS walk/run becomes a Walking/Running workout with a route
(`HealthKitManager.saveTrackedWorkout`), a timed strength session becomes Traditional Strength Training
(`saveStrengthSession`), and a manual distance log becomes a 60-second walk (`saveDistanceWorkout`). The
Watch app records with `HKWorkoutSession`, so Watch workouts always save.

**Likely causes, most likely first:**
1. **Write-back is off by default.** `UserProfile.healthKitWriteBackEnabled = false`, and every save
   checks it (`ActivityWriter` ~L100/L161, `StrengthSessionManager` L159). Turning on Health *import*
   doesn't turn on write-back. The toggle's subtitle, "Write the distance activities you log back to
   Health" (`ProfileView.swift` ~L848), doesn't say it covers tracked workouts and strength sessions,
   so it's easy to miss.
2. **Saves that fail are silent.** All three save functions return nil on any error (for example,
   workout write permission declined in Health). The user is never told, and the app never offers
   to fix it.
3. **Rings don't move, even when the workout is there.** Phone-tracked walks/runs save no active
   energy, so they add nothing to the Move ring. The Fitness app can show the workout without
   changing the rings, which looks like the workout is missing. Strength sessions do include
   estimated kcal.

**Fix:**
- **Turn it on and say so (S):** ask "Save workouts to Apple Health?" the first time someone finishes
  a tracked walk/run or timed strength session (or during Health onboarding), with write-back on as
  the suggested choice. Rename the toggle to "Save workouts to Apple Health", with the subtitle "Walks,
  runs and strength sessions show in Health and Fitness". Existing users keep their current setting.
- **Show the result (S):** on the workout summary, show "Saved to Apple Health" or "Couldn't save to
  Health · Open Settings" depending on whether `healthKitUUID` came back. Check
  `authorizationStatus(for: .workoutType())` to tell a declined permission apart from other errors.
- **Rings credit (M):** add estimated active energy to tracked walks/runs, reusing `CalorieEstimator`
  with body weight, the same way C4/C5 does for strength. Optional, later (L): record phone walks/runs
  with an iPhone `HKWorkoutSession` (iOS 26+) so Health collects energy and heart rate during the workout,
  as the code comment at `HealthKitManager.swift` L156 already suggests.
**Diagnosis (write-back on):**
- On the phone: **Health → Browse → Activity → Workouts → Show All Data.** Are there FunFitness
  entries? Also **Settings → Health → Data Access & Devices → FunFitness:** is Workouts allowed under
  "Allow to Write"?
  - No entries, or Workouts not allowed → the saves fail or are declined (cause 2). The
    saved/failed message fixes the silence, and the summary can link to the permission.
  - Entries in Health but not in Fitness → the saves work, and the gap is how Fitness shows them
    (cause 3: no energy, so no ring credit). Do the M fix.
- In code: add a debug log of the error that `saveTrackedWorkout` / `saveStrengthSession` currently
  ignore, so a failure on device shows its reason.

**Manual distance logs (Jay, 2026-11-12: "should be updated"):**
- **Why they're 60 seconds now:** the Log sheet only asks for distance and a date/time. A Health
  workout needs a start and end, so `saveDistanceWorkout` makes up a one-minute window ending at the
  logged time (`HealthKitManager.swift` L120). It's also always saved as **Walking**, because a
  manual log doesn't record walk vs. run.
- **Fix:** add an optional **Duration** field (and Walk/Run) to distance logs in the Log sheet. The
  date/time becomes the start (label it "Started"), and the Health workout runs from start to start + duration, with the
  distance spread over that time. Also store the duration on the `ActivityLog` (new optional field,
  CloudKit-safe). If there's no duration, don't make up a time window. Save the distance as a plain
  distance sample, not a workout.
- Sizes: **S–M** (Log sheet field, model field, save change, tests). Existing 60-second workouts
  already in Health stay as they are. Editing a log later doesn't update Health (same as today).
- **Tests:** default/migration of the setting, the summary showing saved vs. failed, and the energy sample
  on tracked workouts. On device: finish a walk with write-back on and confirm it appears in Fitness →
  Workouts, and whether the rings change.

**Size: S** for the setting, wording and saved/failed message. **M** if we add calories to walks/runs.

---

## FB-0021 · "Gobble 'Til You Wobble" shows no progress — P1 · S–M

**Issue:** "Why isn't anything being tracked for the gobble 'til you wobble challenge? I've tracked
both distance and strength workouts." (3.2 (16), 2026-11-20)

**Cause:** November's challenge is a `.duration` challenge (10 hours, `Challenge.swift`), and
`ChallengeEngine.progress` only sums logs whose `activityType == challenge.type`. Duration logs are
the separate "Time" activity type; a tracked walk's `ActivityLog.durationSeconds` and a strength
session's `WorkoutSession.durationSeconds` are never counted. So any month with a time challenge
(Feb, Jul, Nov) shows 0 unless the person logs the "Time" type by hand. Same gap, smaller, for rep
challenges (May, Sep, Dec): reps inside weighted sets aren't counted.

**Fix (recommended):** time challenges count *minutes moved from any source*: `.duration` logs
+ `durationSeconds` on distance logs + timed strength sessions (sets in a session counted once,
via the session, not per set). Pure change in `ChallengeEngine` with tests; the card copy
("10 hours of moving") already fits. Decide whether rep challenges should also count reps from
weighted sets (Jay). Badge reconcile already re-runs on change, so November would update
immediately on the next build.

**Done (2026-11-24):** Jay chose yes for rep challenges. `ChallengeEngine.progress` now counts:
Time = Effort Points' minutes (Time logs, tracked routes, manual walk/run durations, timed
strength sessions once, estimates for untimed entries); Reps = Reps logs + reps in weight sets.
`EffortEngine` now uses manual distance durations too (the earlier "Effort Points could use
manual durations" follow-up). ContentView syncs routes and sessions into `AppViewModel` and
re-checks the challenge when they change. Tests in `ChallengeTests` and `EffortEngineTests`.

## FB-0022 · Previous sets per exercise; progress charts — P2 · M

**Issue:** "Is there a way to see recent sets completed with a given workout? … how many reps at
what weight I previously completed … Or even, progress over time charts."

**Today:** Progress shows one personal record per named exercise (`ExerciseProgressCards`) and
muscles worked this week. There's no per-exercise history, and the live strength session doesn't
show last time's sets.

**Fix (proposed, two parts):**
1. **"Last time" in the live strength session** (S): when an exercise is picked, show its most
   recent session's sets ("Last: 3 × 10 @ 50 lb") and prefill weight/reps from it. Highest value
   for the least work.
2. **Exercise detail** (M): tap a PR card → recent sessions list + a Swift Charts line of best set
   (or estimated 1RM) over time. Reuses `ExerciseStats` / `AnalyticsEngine` patterns.

**Part 1 done (2026-11-24):** under the exercise picker in a live strength session, "Last time
(Nov 18): 3 × 10 @ 50 lb, 1 × 8 @ 55 lb" (bodyweight: "3 × 12"). Last time = the most recent
earlier session with that exercise (or the most recent day, for sets logged outside a session);
the session in progress never counts. Picking an exercise fills weight and reps from its latest
set. Pure logic in `ExerciseStats.lastTime` / `grouped`, tested in `ExerciseTests`.

**Part 2 done (2026-11-24):** Progress › Exercise Records rows open the exercise's history:
personal record (with session count and muscles), a "Best Set Over Time" line chart (heaviest
set per session for lifts, most reps for bodyweight; shown from 2 sessions; y-axis starts near
the data so small gains show), and "Recent Sessions" with each session's sets (10, then Show All).
Logic: `ExerciseStats.history` / `Occasion.bestSet` (`lastTime` now builds on `history`). Debug
screenshots: `-seedSampleData -previewTab 1 -previewExercise bench-press` (sample data now has
four bench sessions).

## FB-0023 · Treadmill walks — answered

**Issue:** "Does the app track treadmill walks?" (3.1 (13), 2026-11-15)

**Status:** this is what the Outdoor/Indoor picker in 3.2 (14)+ does (indoor = steps-based
distance, indoor Health workout). 3.2 (16) is the first tester build with it; still needs Jay's
on-device check of an indoor walk.

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
| FB-0015 | Improve the floating action button | D1 | **Closed (2026-11-24):** the 3.2 redesign's log button (and the Arcade / Field Guide versions) replaced it; Jay cancelled the separate refresh |
| FB-0016 | Notes, weather, indoor/outdoor, music | C8 | Notes + indoor/outdoor ✅ 3.1 (8) · weather (M, WeatherKit) and music parked |
| FB-0017 | Workout "score" that isn't calories | C7 | **Design draft** (`20261017_workout_score_design.md`), 4 open questions |
| FB-0018 | Default to last-used activity type | A3 | ✅ 2.4.4 |
| FB-0019 | Reps on by default | A2 | ✅ 2.4.4 |

---

## Suggested order

1. ~~**Build 10:** FB-0002, FB-0001, FB-0004, FB-0003~~ — all done 2026-10-31. Next: commit, bump to build
   10 per `release_checklist.md`, upload, and check the items on device (see each item's status note).
2. **Next (from 2026-11-12):** FB-0020. Cause found: Health write permission was declined. In order: (1) find
   declined write permission + show saved/failed with a Settings link, plus error logging; (2) manual-log
   start + duration; (3) prompt + toggle rename; (4) walk/run calories so phone workouts count toward the rings.
3. **Then:** answer C7's open questions; C3 → C6 with the ~3.3 content move. D1 closed by the 3.2 redesign (2026-11-24).

## Decisions (Jay, 2026-10-31)

- **FB-0004:** use the recommended wording, "You've covered 17.5 miles!", plus the related copy pass.
- **FB-0003:** build the recommended pinned "now tracking" bar above the tab bar.
- **FB-0001:** swipe-to-delete is enough; no Undo.
- **FB-0015 / D1:** postponed until a full UI refresh. The issue is that the `+` button looks bland and
  nondescript; revisit its styling then.
