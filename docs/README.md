# FunFitness — iOS Fitness Tracker

**Release 2.4** · SwiftUI + SwiftData + CloudKit · iOS 18+ · iPhone

Turns workout totals into absurd, shareable real-world comparisons ("6,614 lbs is 2 hippos 🦛").

---

## Features

### Logging
- **Four activity types:** distance, weight (with optional reps), duration, and reps.
- Log sheet with backdating and notes; edit or delete from Activity History.
- **Repeat Last** on Home, and a **Siri / Shortcuts** intent ("log my run").
- **Apple Health:** imports walking, running, hiking, and cycling workouts (with de-duplication
  against manual entries), and can write manually logged distance back to Health. Distance only;
  Health has no "weight lifted" metric.
- **Metric or imperial.** Everything is stored in SI units (km, kg, minutes, reps) and converted for
  display.

### Milestones & comparisons
- **42 milestones:** 15 distance (1 mi → the Appalachian Trail's 2,190 mi), 11 weight, 8 duration,
  8 reps. Titles follow the user's units.
- **5 theme packs** (Animals, Cities, Landmarks, Food, Dinosaurs), each with copy for every
  milestone. Comparisons were fact-checked against sources in `20261010_fact_check.md`.
- **Celebration screen** with confetti, haptics, reduce-motion support, and an illustrated share
  card. One screen per activity type per event, including for Apple Health imports.
- **Home "Right Now…" ticker** restates each total as a count of real-world objects from the active
  pack (`ReferenceUnit`), with no upper limit.

### Habit loop
- Weekly **streaks** with monthly **streak shields**.
- **Silly titles** (Unranked → Diamond) based on the original 38 milestones.
- **Monthly challenges** with year-specific badges.
- **Seasonal comparisons** (Halloween, Thanksgiving, Winter Holidays).
- Opt-in **notifications:** streak at risk, milestone nudge (once per milestone), weekly recap,
  comparison of the day.

### Progress & data
- Swift Charts: weekly volume per type, personal records, 12-week activity heatmap.
- **iCloud sync** across devices via SwiftData + CloudKit (private database), with an opt-out toggle.
- CSV and JSON export.
- **Home screen widget** (small and medium): streak, title, and progress.

---

## Project structure

| Path | Contents |
|---|---|
| `FunFitness/` | App target. Sources are flat in one synchronized folder. |
| `FunFitnessWidgets/` | Widget extension (`FunFitnessWidgetsExtension`). Reads the snapshot the app writes to the App Group. |
| `FunFitnessTests/` | Unit tests (Swift Testing), 161 tests. |
| `FunFitnessUITests/` | UI tests (XCTest). |
| `docs/` | Plans, session summaries, and the fact-check. |

Key types:

| Type | Role |
|---|---|
| `AppViewModel` | `@Observable` state: cached per-type totals, reconcile, celebrations. |
| `ComparisonEngine` | Milestone definitions and per-pack copy. |
| `ReferenceUnit` / `ReferenceUnitEngine` | Real-world units and `bestFit` for the ticker. |
| `AchievementReconciler` | Keeps badge rows in line with totals; dedupes and protects against partial-sync revocation. |
| `ActivityWriter` | The one path for inserting a logged activity (log sheet, Repeat Last, Siri). |
| `HealthKitManager` / `HealthKitImporter` / `HealthKitSync` | Apple Health read, dedupe, and write-back. |
| `PersistenceController` | Shared CloudKit-backed `ModelContainer`, plus the schema init helper. |
| `StreakEngine`, `ChallengeEngine`, `AnalyticsEngine`, `SeasonalEngine`, `SillyTitleEngine` | Pure, date-explicit engines. |

---

## Rules worth knowing

- **Never renumber or remove a milestone id, and never raise a threshold.** Users who earned the
  badge would lose it (`thresholdsNeverRise` test). Lowering is safe.
- **New `@Model` types must be CloudKit-legal:** a default on every stored property, no unique
  constraints, no relationships.
- **The CloudKit Production schema only accepts additions.** After adding models or fields:
  1. Run a Debug build on a signed-in device with the launch argument `-initCloudKitSchema`.
  2. Check the new record types in the CloudKit Console (Development).
  3. Deploy Schema Changes to Production.
- **Pack copy must not contain units** ("56 km"), since metric and imperial users both read it
  (`comparisonCopyHasNoHardcodedUnits` test).
- After editing an activity in place, call `AppViewModel.refreshTotals()`.

---

## Requirements

- iOS 18.0+ deployment target, Xcode 27 (iOS 27 SDK), Swift 6 language mode (app and widget; the test targets are still Swift 5)
- Apple Developer Program membership (iCloud, Push, HealthKit, App Groups)

## Before App Store submission

- [x] App icon
- [x] Light mode
- [ ] App Store Connect privacy nutrition label (mirror `PrivacyInfo.xcprivacy`)
- [ ] Store listing: screenshots, description, keywords, support URL
- [ ] `accessibilityIdentifier` coverage for UI automation tests
