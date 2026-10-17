# FunFitness — TestFlight Feedback, Build 3 (2026-10-13)

TestFlight feedback from JT Jones, submitted 2026-10-10 to 2026-10-13 against build 3 (2.4). Every item from the
screenshots is listed below, grouped by when it makes sense to handle it. Each item lists the
original feedback, what the app does today, and a suggested action.

Groups:
- **A — Immediate (2.4.x / build 4):** small, low-risk fixes to ship before 3.1 work starts.
- **B — Fits 3.1:** overlaps with the 3.1 "On Your Wrist, On the Map" plan
  (`20261010_3.1_design_decisions.md`).
- **C — Later (3.2+ "Workouts" epic):** larger feature and data-model work, mostly about sessions/workouts.
- **D — Needs clarification:** feedback that's too vague to act on yet.

---

## Summary

| # | Feedback | Group | Size |
|---|---|---|---|
| A1 | Weekly streak count overlaps the share icon | A | S |
| A2 | Reps toggle should be on by default (Weight) | A | S |
| A3 | Log sheet should default to the last-used activity type | A | S |
| A4 | Allow typing a rep count directly, not just +/− | A | S |
| A5 | Unclear what the standalone "Reps" type is for | A | S |
| A6 | Activity list is hard to find (viewing + deleting entries) | A → C | S / M |
| B1 | Live tracking of walks/runs | B | L |
| B2 | Use heart rate | B | M |
| B3 | Medium widget lacks context (stats or % toward goal) | B | S–M |
| C1 | Sessions/workouts that group sets & reps | C | L |
| C2 | Sets, not just rep counts | C | M |
| C3 | Named exercises (bench press, upright row) | C | M–L |
| C4 | Time each session; estimate calories from time | C | M |
| C5 | Save workouts to Apple Health with a calorie count | C | M |
| C6 | Track recently used muscle groups (like Peloton) | C | M |
| C7 | Workout "score" that isn't just calories (documented) | C | M |
| C8 | Extra workout context: notes, weather, timestamps, indoor/outdoor, music | C | M |
| C9 | Distance surface: road / track / trail / treadmill | C → B | S–M |
| D1 | "Improve the floating action button" | D | ? |

---

## A — Immediate (2.4.x / build 4)

> **Status (2026-10-16): A1–A6 done in 2.4.4 / build 4.** Decisions: A5 keeps the "Reps" name and
> adds a hint; A6 adds a Recent Activity card on Home (last 5, delete from each row's ⋯ menu, "See
> all" opens History) and labels Progress's button "History". Undo-after-log was dropped. B3
> stays in 3.1.

### A1. Weekly streak count overlaps the share icon
> "Weekly streak week count overlaps with share icon" — 2026-10-12

- **What happens now:** On the Home streak card, the big streak number and "week" label sit in the
  top-right corner, and the share button is placed in an overlay in that same corner
  (`HomeView.swift` ~L163–L214). The screenshot shows the "1" and the share glyph drawn on top of each other.
- **Action:** Reserve trailing space for the share button or move it, the way the badge card already
  does ("Reserve trailing space for the share button", ~L297). Check at the largest Dynamic Type size.
- **Test:** Screenshot at default and accessibility text sizes.

### A2. Reps toggle should be on by default
> "'reps' should be toggled on by default" — 2026-10-13 (screenshot: Weight tab)

- **What happens now:** `includeReps = false` (`LogActivitySheet.swift:23`), and it resets to false on every type
  change (`:50`). `repsCount` starts at 1.
- **Action:** Default `includeReps` to `true` for rep-using types. Consider starting `repsCount` from the
  last logged weight entry (Repeat Last already knows it, e.g. "135 lbs × 12") rather than 1.
- **Watch for:** Existing tests that assume reps are nil by default.

### A3. Default the log sheet to the last-used activity type
> "Activity logging should default to last action in session (logging weight vs distance)" — 2026-10-12

- **What happens now:** `LogActivitySheet` takes `initialType: ActivityType = .distance`, so the
  general `+` button always opens on Distance.
- **Action:** When no type is passed, open on the most recent log's type. Store it in
  `@AppStorage` or derive it from the latest `ActivityLog`. Per-card `+` buttons keep
  their explicit type.

### A4. Type a rep count directly
> "Would be nice to input a rep count directly; not just use the + and − buttons." — 2026-10-10

- **What happens now:** Reps use a stepper-style control (− 6 reps +), starting at 1.
- **Action:** Make the count a tappable number pad field, keeping +/− for small changes. Clamp to a
  sensible range and validate.

### A5. Unclear what the standalone "Reps" type is for
> "Unsure what this 'reps' is needed for." — 2026-10-12 (screenshot: Reps tab, empty field)

- **What happens now:** The fourth segment, "Reps" (`ActivityType.reps`), is a bodyweight count
  (push-ups, squats) with no exercise name. The field label just says "Reps".
- **Action (immediate):** Add a one-line hint under the field, e.g. "Bodyweight moves like push-ups or
  squats". Consider renaming the segment ("Bodyweight"?).
- **Action (later):** Named exercises (C3) mostly solve this, since "20 × Push-ups" explains itself.

### A6. Activity list is hard to find
> "Need to make it clearer how to find an activity list. For visibility as well as deleting an
> erroneous entry. Should it be on a different screen (or multiple screens?)" — 2026-10-12

- **What happens now:** History is only reachable from the unlabeled clock icon at the top-left of Progress
  (`ProgressView.swift:100` → `ActivityHistorySheet`).
- **Action (immediate):** Make it easier to find without restructuring:
  - Add a "Recent Activity" section to Home (last 3–5 entries, swipe to delete, "See all" link).
  - Give the Progress toolbar button a label or tooltip ("History").
  - Show "Undo" briefly after logging, so mistakes get fixed right away.
- **Action (later, with C1):** Once sessions exist, the activity list probably becomes its own screen or
  tab (session list → session detail → edit/delete entries).

---

## B — Fits 3.1

### B1. Live tracking of walks and runs

> **Status (2026-10-16): B1 done in 3.1 (B1a–B1c).** **B1a done** — live GPS walk/run tracking on iPhone
> (time, distance, pace, route map, pause/resume, hide-and-keep-tracking, save with route, optional
> Health workout + route). **B1b done** — Lock Screen / Dynamic Island Live Activity (live clock,
> distance, pace, comparison line; Pause/Resume/End buttons; End waits in the app for review).
> **B1c done** — live strength sessions: session clock, Log Set (weight × reps or bodyweight reps,
> each saved immediately as a normal entry), rest timer with Skip and an optional rest-over
> notification, summary; the same Live Activity shows sets, last set, rest countdown, and Log
> Set / End. Sessions live in memory only; stored sessions remain C1. Decisions: keep
> iOS 18 (iOS 26 `HKWorkoutSession` noted as a future enhancement), tracking works without Health,
> version 3.1 / build 5.

> "Include a way to track live a walking/running activity. Brainstorm a way to add easier live
> logging for other activities." — 2026-10-10

- **Already planned in 3.1:** GPS recording on iPhone, Watch workouts, and a Live Activity
  (design decisions §2, §3, §5).
- **New:** "easier live logging for other activities." Ideas: a live strength mode with
  a running timer, a "log set" button, and rest timer, shown in the same Live Activity. This leads into C1.

### B2. Heart rate
> "Also, opportunity to use heart rate?" — 2026-10-12

- During 3.1 tracked workouts, `HKLiveWorkoutBuilder` (Watch) / `HKWorkoutSession` collect heart rate
  automatically. Showing average/max HR on a finished workout is a small addition once routes exist.
- Needs HealthKit read permission for heart rate, so update the permission request and
  `PrivacyInfo`/usage strings.
- Could feed a non-calorie score (C7), e.g. time in heart-rate zones.

### B3. Medium widget lacks context
> "Medium widget size doesn't give context for run or lift, either tracked stats, or percentage
> towards goal could actually add value there" — 2026-10-10

- **What happens now:** The widget supports `.systemSmall` and `.systemMedium`
  (`FunFitnessWidgets.swift:166`), and the medium size doesn't show run/lift details.
- **Action:** Add distance and weight totals, each with a progress bar to the next milestone (the data is
  already on Progress), and possibly the current monthly challenge %. This could be an immediate fix if the
  widget snapshot already carries the totals. Otherwise do it when the 3.1 Live Activity work touches the
  extension.

---

## C — Later (3.2+ "Workouts" epic)

Most of this group is one feature: **sessions/workouts**. Today every log is a separate `ActivityLog`.
The items below all depend on a parent "workout" that groups entries.

### C1. Sessions / workouts
> "Should be able to create 'sessions', so sets and reps from one instance are captured. Similar to
> discrete 'workouts' in Apple Fitness." — 2026-10-12

- **Data model sketch (CloudKit-legal, additive):** a `WorkoutSession` model (id, start, end, kind,
  notes, healthKitWorkoutUUID). `ActivityLog` gains an optional `sessionID: UUID?` (no relationship,
  matching the `RouteSummary` pattern). Old logs keep `sessionID == nil`.
- **UX question:** Start a session explicitly ("Start workout"), or group logs automatically when they're
  close together in time? Could do both: automatic grouping with an explicit start/stop.

### C2. Sets
> "Would also be nice to add sets (not just rep counts)" — 2026-10-10

- Each set is one log inside a session (weight × reps). Alternatively, a quick "3 × 10 @ 135" entry can
  expand into three logs. Total weight lifted stays as it is today.

### C3. Named exercises
> "Should be able to add specific activities (bench press, upright row) and not just generic reps and
> weights" — 2026-10-10

- A bundled exercise catalog (name, muscle groups, equipment) plus user-defined exercises. Store
  `exerciseID: String?` on `ActivityLog` (additive). This fits the deferred bundled-JSON content
  approach (see the content-JSON migration note, targeted ~3.3).
- Enables per-exercise personal records ("Bench press PR: 185 lbs").

### C4. Time each session; estimate calories
> "Each session's length should be timed as well. Good for reference and comparison, but there may
> be a metric/basic calculation to determine calories burned based on time spent." — 2026-10-12

- Session start/end gives the duration. Calories can be estimated with METs:
  `kcal ≈ MET × body weight (kg) × hours`. That requires body weight, which can be read from HealthKit or entered in the profile.
- Prefer HealthKit's own energy estimate when the workout comes from the Watch.

### C5. Save workouts to Apple Health
> "Having full 'workouts' or 'sessions' would help facilitate saving to apple health. How can we
> assign a proper calorie burn count?" — 2026-10-12

- **What happens now:** "Save logs to Apple Health" only writes distance activities.
- With sessions: write an `HKWorkout` (`.traditionalStrengthTraining` etc.) with
  start/end and estimated active energy (C4). This reuses the 3.1 `HKWorkoutBuilder` work, which is why
  it should come after 3.1.

### C6. Recently used muscle groups
> "Should we track muscle groups used recently, like the Peloton app does?" — 2026-10-12

- Depends on C3 (exercises tagged with muscle groups). Could show as a body heat map or a "muscles
  worked this week" chip row on Progress. Fun angle: muscle groups as reference-unit comparisons.

### C7. Workout "score" that isn't just calories
> "Should there be some sort of workout 'score'? Probably related to calories is the best bet, but a
> reminder that we don't necessarily want calories being top of mind — another score metric might
> make sense. It'll need to be documented." — 2026-10-12

- Matches the app's tone (fun, not diet-focused). Options to evaluate:
  - Effort points from duration × intensity (MET) and not shown as kcal.
  - Heart-rate zone minutes (B2), like Active Zone Minutes.
  - Volume-based for strength (weight × reps), normalized across activity types.
- **Requirement from the feedback:** the formula must be written down. Show users a short "How your score
  works" explanation and keep a design doc in `docs/`.

### C8. Extra workout context fields
> "If/when adding 'workouts', add additional fields for context. Freeform notes, maybe weather?
> Timestamps? Indoor/outdoor (for runs?) Capture music played (maybe/maybe not)" — 2026-10-12

- **Easy:** notes, start/end timestamps (from C1), indoor/outdoor flag.
- **Medium:** weather via WeatherKit, which adds a capability and an Apple Developer service.
- **Unclear value / privacy-sensitive:** music played. MusicKit "recently played" is possible but
  limited, so park it.

### C9. Distance surface: road, track, trail, treadmill
> "Would be good to track distance on road vs track vs trail vs treadmill" — 2026-10-10

- An additive `surface: String?` on `ActivityLog` with a small picker in the log sheet. Treadmill
  overlaps with the "indoor" flag in C8. HealthKit imports could prefill it from `HKMetadataKeyIndoorWorkout`.
- Small enough to do alongside 3.1 GPS (outdoor runs know they're outdoors), so it may move to B.

---

## D — Needs clarification

### D1. "Improve the floating action button"
> "Improve the floating action button" — 2026-10-12

- The `+` button sits in the top-right of each tab. What should change: size, position (bottom, near the tab
  bar), a long-press menu with quick types, or Liquid Glass styling? **Jay to clarify.** A long-press menu
  ("Log distance / weight / duration / reps / Repeat last") would also support A3.

---

## Suggested order

1. **Build 4 (2.4.4):** A1, A2, A3, A4, A5, plus the cheap parts of A6 (Recent Activity on Home, labeled
   history button). Check whether B3 is cheap enough to include.
2. **3.1:** as planned, plus B2 (heart rate on tracked workouts), B3 if not done earlier, and C9 for GPS runs.
3. **3.2 "Workouts":** C1 → C2 → C3 → C4 → C5, then C6–C8. Write a design-decisions doc for the session
   model and score (C7) before building.

## Open questions for Jay

- A5: Keep the standalone "Reps" type, rename it, or fold it into named exercises later?
- A6: Is Recent Activity on Home enough for now, or should history become its own tab?
- C1: Explicit "Start workout" vs. automatic grouping?
- C7: Which score direction: effort points, zone minutes, or volume?
- D1: What should change about the `+` button?
