# FunFitness — Session Summary (2026-10-16)

Covers the TestFlight build 3 feedback: the Group A fixes (2.4.4, build 4), then the first 3.1 work —
B1 live tracking (GPS walks/runs, Live Activity, live strength sessions) and C9 distance surface
(version 3.1, build 5). **192 unit tests pass; `main` is pushed.** Build 5 is ready to archive once
the CloudKit schema is deployed (steps below).

---

## 2.4.4 — build 3 feedback, Group A (build 4)

| Commit | Change |
|---|---|
| `0376e71` | Build 3 feedback doc + 10/10 session summary added to the Xcode project. |
| `6587691` 2.4.4 | **A1** streak count no longer overlaps the share icon. **A2** reps on by default, prefilled from the last entry. **A3** general `+` opens on the last-logged type. **A4** typed rep count (1–999) alongside −/+. **A5** hint under Reps: "Bodyweight moves like push-ups or squats". **A6** Recent Activity card on Home (last 5, delete from the ⋯ menu, See all → History); Progress button labeled "History". Build 4. |

Decisions: keep the "Reps" name (hint only); no undo-after-log; B3 (medium widget) stays in 3.1.
Home deletes use the ⋯ menu, not swipe — swipe actions outside a `List` need iOS 27.

## 3.1 — live tracking (B1) and distance surface (C9), build 5

| Commit | Change |
|---|---|
| `77529f5` B1a | **Live GPS walk/run tracking on iPhone.** `WorkoutTracker` (Core Location `liveUpdates(.fitness)` + background session); pure `RouteMath` (GPS filtering, pause-aware distance/time, pace, route downsampling, polyline codec); `TrackWorkoutView` (start → live map/stats → summary → save/discard; Hide keeps tracking). New **`RouteSummary`** model holds the display route; tracked entries are `ActivitySource.tracked`. Optional Health save: a real workout with pauses and GPS route. Health import de-dup now covers tracked runs. Version **3.1, build 5**. |
| `551f00a` B1b | **Live Activity** (Lock Screen + Dynamic Island): live clock, distance, pace, comparison; Pause/Resume/End buttons. End finishes but doesn't save — the summary opens next time the app is in front. New `Shared/` folder compiled into both the app and widget extension. |
| `61eedc0` B1c | **Live strength sessions.** Session clock, Log Set (weight × reps or bodyweight reps — each saved immediately as a normal entry), rest timer with Skip, optional rest-over notification (only if already allowed), summary. Same Live Activity in a strength layout with Log Set (repeats the last set) + End. One live session at a time. |
| `f5b8892` C9 | **Optional distance surface** — Road / Track / Trail / Treadmill in the log and edit sheets; Road / Track / Trail on a GPS run's summary. Shown in history, kept by Repeat Last and Siri, exported (CSV `Surface` column, JSON `surface`, schema 1.3). Health imports stay blank. |

**Decisions (Jay):** keep the iOS 18 deployment target; GPS tracking works without Apple Health;
B1 built in three segments; version 3.1 / build 5 on `main`.

**Future enhancements (in `docs/20261010_3.1_design_decisions.md`):**
- Bump to iOS 26 and use iPhone `HKWorkoutSession` for live Health metrics and Lock Screen data access.
- Save in-progress runs to disk, so a run survives iOS closing the app mid-run.

**Not done on purpose:** strength sessions aren't stored as grouped workouts (C1) or saved to Health
(C5); session time isn't logged as Duration.

## Gotchas learned

- **Xcode's device-interaction tools need an iOS 27 simulator runtime;** only iOS 26.4 is installed, so
  this session's UI was checked with Xcode previews, not taps. Install the iOS 27 runtime (Xcode ›
  Settings › Components) to enable automated tap-through checks.
- Xcode's `RunAllTests` tool reported every test "not run"; run unit tests with
  `xcodebuild test -scheme FunFitness -only-testing:FunFitnessTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- The app defaults to MainActor isolation and the widget extension doesn't, so types in `Shared/`
  must be marked `nonisolated`. `Activity` (ActivityKit) isn't `Sendable` — look activities up by id
  inside `nonisolated` helpers rather than passing one across actors.
- Live Activity previews ignore `activityBackgroundTint`; the Lock Screen view paints its own background.
- The Lock Screen Live Activity has a strict height limit — the strength layout shows the rest
  countdown *instead of* the comparison line to fit.

## Jay's checklist — before uploading build 5

### 1. Deploy the CloudKit schema (required — build 5 adds two things)

New: the `CD_RouteSummary` record type, and a `CD_surfaceRaw` field on `CD_ActivityLog`. Production
only accepts schema that's been deployed, so do this **before** testers get build 5.

1. In Xcode, select the **FunFitness** scheme and your **iPhone** (signed in to iCloud) as the destination.
2. Product › Scheme › Edit Scheme… › Run › Arguments › add `-initCloudKitSchema` (checked).
   Build configuration: **Debug**.
3. Run. Watch the console for "CloudKit schema initialized in the Development environment."
   Then stop the app and **uncheck** `-initCloudKitSchema`.
4. Open [CloudKit Console](https://icloud.developer.apple.com) › container
   `iCloud.com.discoverhealthquest.funfitness` › **Development** › Schema › Record Types. Confirm
   `CD_RouteSummary` exists and `CD_ActivityLog` has `CD_surfaceRaw`.
5. **Deploy Schema Changes…** → review the diff (one new record type, one new field) → Deploy to Production.

### 2. Try the new features on your phone (Debug run is fine)

- **Walk/run:** Home › "Track a Walk or Run" › Start Walk (allow location). Walk a few minutes outside.
  Check time/distance/pace and the route line; Pause/Resume; Hide and reopen from the Home card;
  lock the phone and use the Lock Screen Pause/Resume/End buttons. End from the Lock Screen → open the
  app → the summary appears. Pick a surface, Save. Confirm the entry shows on Home and in History
  ("· Road"), and — if Health saving is on — a Walking workout with a route map appears in Fitness/Health.
- **Strength:** Home › "Start a Strength Session" › Start. Log a weighted set and a bodyweight set; watch the
  rest countdown in-app and on the Lock Screen; tap Log Set on the Lock Screen; Skip rest; End.
  Confirm each set is in History.
- **Group A:** streak card share icon, reps default + typed count, `+` opens on your last type, Reps hint,
  Recent Activity delete, "History" button on Progress.
- **Surface:** log a manual distance with Treadmill; edit it to Trail; export CSV and check the last column.
- Simulator alternative for the walk: `xcrun simctl location booted start --speed=1.6 30.2672,-97.7431 30.2690,-97.7431 30.2690,-97.7410`
  (stop with `xcrun simctl location booted clear`).

### 3. Archive and upload build 5 to TestFlight

1. Make sure the schema deploy (step 1) is done and `-initCloudKitSchema` is **unchecked**.
2. In Xcode, set the destination to **Any iOS Device (arm64)**.
3. Confirm versions: FunFitness and FunFitnessWidgetsExtension targets › General › Identity show
   **Version 3.1, Build 5** (both must match).
4. **Product › Archive** (uses the Release configuration — production push environment). Wait for the
   Organizer window.
5. In Organizer, select the new archive (3.1 (5)) › **Distribute App** › **TestFlight & App Store**
   (or "App Store Connect" › Upload) › keep defaults (automatic signing, upload symbols) › **Upload**.
6. When processing finishes (App Store Connect usually emails within 15–30 minutes):
   [App Store Connect](https://appstoreconnect.apple.com) › FunFitness › **TestFlight** › iOS builds ›
   3.1 (5). Export compliance is answered automatically (`ITSAppUsesNonExemptEncryption = NO`).
7. Add **What to Test** notes (suggested text below), then add the build to your internal testing group.
8. Optional: expire build 4 once build 5 is installed, so testers don't stay on the old one.

Suggested **What to Test**:

> New in 3.1: live tracking.
> • Track a walk or run with GPS: Home › "Track a Walk or Run". Live time, distance, pace and a route
>   map; pause/resume; works with the screen locked. Lock Screen and Dynamic Island show your stats
>   with Pause/Resume/End buttons.
> • Live strength sessions: Home › "Start a Strength Session". Log sets as you go with a rest timer;
>   "Log Set" on the Lock Screen repeats your last set.
> • Pick a surface (road, track, trail, treadmill) for distance entries.
> Also from build 3 feedback: reps on by default, type a rep count, the log sheet remembers your last
> activity type, and a Recent Activity list on Home.
> Please report: GPS distance accuracy vs. other apps, battery use on longer walks, and anything odd
> on the Lock Screen.

### App Store privacy note

Location and routes stay on the device and in the person's own iCloud and Health — the developer
never receives them — so App Privacy answers don't need to change for TestFlight. Revisit before an
App Store release.

## Next

- Field-test build 5 (GPS accuracy, battery, Lock Screen buttons, background behavior).
- Rest of 3.1: B2 heart rate, B3 medium widget, Apple Watch, Journey Mode (pick Texas Triangle vs.
  Appalachian Trail first).
- D1 ("improve the floating action button") still needs clarification.
