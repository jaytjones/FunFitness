# FunFitness — Session Summary (2026-11-06)

Four features for **3.1 (11)**: C7 Effort Points, C3/C6 named exercises and muscle groups, Journey
Mode, and the Apple Watch app. All unit tests pass on the iPhone 17 Pro simulator, and a Release
device build (unsigned) of the app with the embedded Watch app succeeds. Everything is committed on
`main` locally; nothing is pushed.

`scripts/feedback` found no new TestFlight feedback (run twice). Jay's build 10 feedback may not
have reached App Store Connect yet, so re-run it later.

---

## Commits

| Commit | Change |
|---|---|
| `f420904` | **C7 Effort Points:** `EffortEngine` + Home `EffortPointsCard` with a "How your score works" sheet. |
| `29e5295` | **C3 named exercises + C6 muscles:** `Exercises.json` (45), `CustomExercise`, exercise picker, Progress cards, export 1.5. |
| `f4a455d` | **Journey Mode:** Texas Triangle + Appalachian Trail, Home card, map, picker. |
| `ddf44b9` | **Apple Watch app:** outdoor walk/run + quick log, `WatchConnector` on the phone. |

## What shipped

- **C7 Effort Points** = minutes × intensity, with a weekly target of 150.
  - Intensity is the heart-rate zone of the average heart rate when Health has one and the profile has a date of birth.
  - Otherwise it's MET ÷ 2: walk 1.75, run 4.9, strength 1.75, Duration entries 2 points per minute.
  - Minutes come from route moving time, timed strength sessions, and Duration entries.
  - Entries with no time are estimated: 12 min/km as a walk, 2 min per strength set. The card says when estimates are included.
  - Shown on a Home card only. It doesn't count toward badges and nothing new is stored.
- **C3 named exercises:**
  - The bundled catalog is JSON, the first content moved out of Swift. The theme-pack comparison copy still moves around 3.3.
  - People can add their own exercises (with muscle groups), and they sync through iCloud.
  - An exercise is **required** for every new Weight/Reps set, in both the log sheet and the live session. It's prefilled from the last one. Repeat Last, Siri and the Live Activity's Log Set reuse it.
  - Older entries stay generic and can be given an exercise from Edit.
- **C6:** two new Progress cards. "Muscles Worked This Week" shows sets per muscle group as chips; "Exercise Records" shows the heaviest weight (then most reps) per exercise. A body heat map is a future enhancement.
- **Journey Mode:**
  - Pick the Texas Triangle (714 mi, 12 stops) or the Appalachian Trail (2,197.4 mi, 17 stops).
  - Progress counts distance logged **since the journey started**, not lifetime totals.
  - The detail screen has a map with a "you are here" marker. Each checkpoint's fun fact unlocks when you reach it.
  - Switching or ending a journey asks first.
- **Apple Watch app** (`FunFitnessWatch Watch App`, watchOS 11+, embedded in the iPhone app, same version and build):
  - Outdoor Walk/Run tracking (time, distance, heart rate, pause/resume), saved to Apple Health and sent to the phone, so it counts even with Health import off and never counts twice.
  - Quick Log for Lift, Bodyweight and Duration entries; the phone saves them.
  - The phone sends the exercise list and units to the Watch.

## Decisions (Jay)

- The design style choice is deferred again.
- C7: 150 points a week, shown on a Home card.
- Journeys: ship both, with a picker.
- C3: custom exercises that sync; an exercise is required; muscle groups as chips on Progress, heat map later; only the exercise catalog moves to JSON now.

## Before uploading build 11 (Jay)

1. **CloudKit schema deploy:** run a Debug build on a signed-in device with `-initCloudKitSchema` (enable it in the scheme, then turn it off again). Then **Deploy Schema Changes** to Production. New in this build:
   - Record type `CD_CustomExercise`
   - `CD_ActivityLog.CD_exerciseID`
   - `CD_UserProfile.CD_activeJourneyID` and `CD_UserProfile.CD_journeyStartedAt`
2. **Watch signing:** open the project in Xcode and select the `FunFitnessWatch Watch App` target → Signing & Capabilities. Automatic signing will register `com.jaytjones.FunFitness.watchkitapp` with HealthKit. Check that the HealthKit capability is shown.
3. **Fact-check** the Journey checkpoint distances and facts in `FunFitness/Journeys.json`, the same way as the 2.3 copy.
4. Set the build number to 11 (project level; it covers the app, widget and Watch app), archive, upload, and tag `3.1-11`.

## Device checklist

- **Effort Points:** log a walk, a timed strength session and a Duration entry, then check the Home card total and the ⓘ sheet.
- **Exercises:** the log sheet won't save Weight/Reps until an exercise is chosen. Also check:
  - adding a custom exercise, and that it appears on a second device;
  - the live session shows "Bench Press · 135 lbs × 10";
  - the Progress chips and records.
- **Journey:** start each journey, log a walk, and check the card, the map marker and the fact unlocking; then switch journeys and end one.
- **Watch:**
  - install it via the Watch app on the iPhone;
  - quick-log a lift and check it appears on the phone (also with the phone app closed);
  - track a short outdoor walk and check it's in Health and counted once in FunFitness, with Health import both on and off.

## Not built yet

- A celebration when a journey checkpoint is passed (`JourneyEngine.newlyReached` is ready for it).
- A Watch complication.
- GPS routes for Watch walks/runs (`HKWorkoutRouteBuilder`).
- Totals and milestones on the Watch.
- C7 reference-unit framing.
- The C6 body heat map.
- D1 / design style.

## Gotchas

- Xcode's watchOS "App" template made a watch-only container target. The project file was rewritten
  by hand: the container was removed, and the Watch app is embedded in FunFitness under "Embed Watch
  Content", with `WKCompanionAppBundleIdentifier`. The Watch app's `Info.plist` (for
  `WKBackgroundModes`) lives in `FunFitnessWatchSupport/`, outside the synced folder.
- `WatchShared/` is a synced folder compiled into the iPhone app **and** the Watch app (like
  `Shared/` for the widget). Keep its types `nonisolated` and free of iOS-only frameworks.
- `WatchConnector` holds the view model weakly. Tests must keep the `AppViewModel` alive, as with
  `StrengthSessionManager`.
