# FunFitness — Session Summary (2026-11-15)

Found out why Jay's retest on 3.1 (13) still put nothing in Apple Health, fixed it, finished the rest
of FB-0020, and set the next upload to **3.2 (14)**. All unit tests pass on the iPhone 17 Pro
simulator. None of the new UI has been run on a device yet.

## Why workouts still didn't reach Health (FB-0020)

Health access and both Profile switches were on. Both of Jay's tries were skipped on purpose, and the
app said nothing:

- **Treadmill walk:** GPS didn't move, so the walk had 0 distance. Save was disabled, and the Health
  save stops early with no distance.
- **30-second strength session:** sessions under a minute are never saved, and the summary only
  showed a status once a save started.

Jay later confirmed that a strength session over a minute saves to Health.

## Commits

| Commit | Change |
|---|---|
| `2827056` | Outdoor / Indoor tracking (indoor distance from steps); "too short" strength message; skipped saves log and show the banner. |
| `6bedd7a` | FB-0020 items 3–4: setting renamed, one-time Health prompt, calories on tracked walks/runs; Watch write types; streak tests. |
| `0f2fc4a` | 3.2: keep SF Pro Rounded (Fredoka/Nunito dropped). Docs and tokens only. |
| this commit | Build 14: version **3.2 (14)**, checklist, FB-0020 status, this summary. |

## What changed

**Outdoor / Indoor tracking** (`WorkoutTracker`, `TrackWorkoutView`)
- The start screen has an Outdoor / Indoor picker under Walk / Run and remembers the last choice
  (`AppStorage` key `trackerIndoor`). Jay chose this over guessing from GPS.
- Indoor doesn't use GPS. Distance comes from `CMPedometer`, and paused time isn't counted
  (`StepDistance`, which is pure and tested). At Finish the step counter is asked once for its full
  total, because live updates stop while the app is suspended (there's no location session keeping it
  awake).
- The indoor live screen shows a treadmill icon instead of the map. The summary says "Indoor —
  distance counted from your steps" and preselects Treadmill as the surface. Health gets an indoor
  Walking/Running workout with no route.
- Motion & Fitness off or unavailable → the live screen says so. The new
  `NSMotionUsageDescription` is set in the app target's build settings.
- Outdoor with no GPS distance → the summary suggests choosing Indoor.

**Health saves that can't run say why**
- `HealthKitManager.skipped(_:reason:)` logs the reason and sets the Home failed-save banner. It's
  used when there's no distance (tracked or manual) or the end isn't after the start (strength).
- Strength sessions under a minute show "Too short to save to Apple Health (under 1 minute)". Jay
  kept the 1-minute minimum.

**FB-0020 item 3: the setting and a one-time prompt**
- "Save logs to Apple Health" is now **"Save workouts to Apple Health"**, with the subtitle "Walks,
  runs and strength sessions show up in Health and Fitness".
- `HealthSavePrompt` (in `HealthAccessNotice.swift`) appears on the walk/run summary (before Save)
  and the strength summary while the setting is off. It's asked once per device (`AppStorage`
  key `healthSavePromptAnswered`).
- Turn On turns the setting on and requests access. On a walk or run, Save then writes to Health. A
  strength session is saved right away (`StrengthSessionManager.healthSavingTurnedOn()`).

**FB-0020 item 4: calories on tracked walks/runs**
- Estimated active energy is about 0.5 kcal per kg per km walking and 1.0 running
  (`CalorieEstimator.kcal(distanceMeters:kind:weightKg:)`). It's saved with the workout, so it counts
  toward the Move ring. Indoor walks get it too.
- Weight comes from the profile, else Health's latest body weight (without prompting). With neither,
  no calories are saved. Calories only go to Health and aren't shown in the app.

**Watch:** it now asks to write `distanceWalkingRunning` and `activeEnergyBurned` as well as
workouts and routes. Before, Watch workouts could reach Health with no distance or calories, and
without a distance they never reached the phone. Expect one Health prompt on the Watch for the two
new types.

**3.2 font:** after a side-by-side sample, Jay kept SF Pro Rounded. Fredoka/Nunito are dropped from
the design docs and tokens. `FFFontFamily` stays as the hook for a future style.

**Tests:** +9. `IndoorDistanceTests` (6) and `TrackedCaloriesTests` (3). The `StreakEngine` tests
are now anchored to calendar weeks. They failed on Sundays with a Sunday-first calendar, which was a
test bug, not an app bug.

## Decisions (Jay)

- An explicit Outdoor / Indoor choice when starting, not auto-detection.
- Indoor distance comes from the step counter (not entered by hand, not time only).
- Keep the 1-minute minimum for strength saves, and explain it.
- Playful Bold keeps SF Pro Rounded.
- Next upload is **3.2 (14)**. Testers have had the new look since build 12.

## Before uploading (Jay)

1. No CloudKit schema change in this build.
2. Archive → Organizer should show **3.2 (14)**. Untick "Manage Version and Build Number", upload,
   then `git tag 3.2-14 && git push origin 3.2-14`.
3. In App Store Connect, 3.2 is a new version in TestFlight. Add What to Test and testers.

## Device checklist (3.2 (14))

- **Indoor walk** on a treadmill: the Motion & Fitness prompt appears, distance goes up while
  walking, Save works, and it shows in Health and Fitness as an indoor walk with calories. Lock the
  screen partway through and check the final distance is still right.
- **Outdoor walk:** the map and route work as before, and calories show in Health.
- **Prompt:** turn "Save workouts to Apple Health" off, delete and reinstall (or use a fresh device)
  so the prompt hasn't been answered. Finish a walk → Turn On → Save, and it should be in Health.
  Then end a strength session over a minute, and it should save.
- **Short strength session** (<1 min) with saving on → "Too short to save to Apple Health".
- **Watch walk:** allow the two new write types. The walk keeps its distance and calories in Health
  and appears on the phone.

## Not done / open

- The 3.2 contrast / Dynamic Type check on a device, in light and dark (the last 3.2 exit item).
- The 5K field test (3.1).
- Possible follow-up: `EffortEngine` could use manual durations (it still treats untimed distance as
  a walk).
- 3.3 unlock rules (earned vs purchased) are still to be decided.
