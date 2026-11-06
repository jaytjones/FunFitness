# FunFitness — Session Summary 2 (2026-11-06)

3.1 is code complete and 3.2 "New Look" (Playful Bold) is built. All unit tests pass on the
iPhone 17 Pro simulator; the Watch app and complications build for the watchOS simulator. Local
commits on `main`, not pushed.

## Commits

| Commit | Change |
|---|---|
| `98fdf8d` | Repo aligned to **build 11** (archived as 10, Xcode renumbered the upload; tag `3.1-11` → `382d9fc`). BuildNumberTests now covers the Watch app (and later its complications). **Sequenced Development Plan rewritten:** status for shipped releases, 3.2 New Look, 3.3 Your Style, 3.4 Social, 3.5 Franchise, backlog, revision history. |
| `baff8a7` | **Watch GPS routes:** `HKWorkoutRouteBuilder` saves the route with the Health workout; a downsampled polyline, moving time and walk/run go to the phone, which saves a tracked entry + `RouteSummary` (map, real Effort Points). `RouteMath` moved to `WatchShared/`. |
| `afee2a6` | **Watch stats + complications:** streak, this week's Effort Points and totals sent with the Watch context; "This Week" section on the Watch; new `FunFitnessWatchWidgetsExtension` (circular, corner, inline, rectangular) reading an App Group snapshot, resetting points at the week boundary. |
| `b36d94b` | **3.2 style foundation:** `Shared/Style.swift` tokens from `playful-bold/tokens.json`; every hard-coded colour and gradient in the app, widgets and Live Activity replaced; share cards always Sunny; DEBUG `-seedSampleData` launch argument (in-memory sample store) for screenshots. |
| `2b0137c` | **3.2 structure:** floating word TabBar (Home · Progress · Badges · You) + 64pt pink LogButton with long-press menu (closes D1); system tab bar at accessibility text sizes; Home greeting → HeroStat → StatTiles → brand-book order; "Compare with"; journey checkpoint celebration; `UserProfile.activeStyleID`. |
| `fd6cccf` | Watch accent pink + brand yellow. |

## Decisions (Jay)

- New numbering: 3.2 New Look, 3.3 Your Style (Arcade + unlocks), 3.4 Social, 3.5 Franchise.
- Playful Bold is the default; the old look is retired. Unlocks: earned + purchased, details TBD
  before 3.3. Style syncs across devices.
- My call (noted in the plan): the foundation step used Playful Bold colours directly instead of a
  throwaway "old look" palette.

## Before the next upload (Jay)

1. **Version:** this upload holds the new look. Suggest **3.2 (12)**: set Marketing Version 3.2 and
   Current Project Version 12 at the project level (all four targets inherit them).
2. **CloudKit deploy:** new field `CD_UserProfile.CD_activeStyleID` (same `-initCloudKitSchema`
   steps as before).
3. **Signing:** in Xcode, check Signing & Capabilities for the new **FunFitnessWatchWidgetsExtension**
   (App Group `group.com.discoverhealthquest.funfitness`) and the Watch app (HealthKit + the same App
   Group, newly added).
4. Archive, untick "Manage Version and Build Number", upload, tag.

## Device checklist

- **Look:** every tab in light and dark; Dynamic Type at the largest sizes (the tab bar switches to
  the system bar at accessibility sizes); the LogButton tap and long-press menu; Repeat last.
- **Home:** HeroStat numbers and punchline per pack ("Compare with"); StatTiles appear only for
  logged types.
- **Journey:** log a walk that passes a checkpoint → the "You reached …!" screen, once.
- **Widgets / Live Activity:** home-screen widgets on yellow; Lock Screen and Dynamic Island during
  a walk and a strength session.
- **Watch:** route recorded on an outdoor walk (Health shows the map; FunFitness shows it in History);
  the "This Week" section; add each complication to a watch face.
- **3.1 exit:** 5K field test, route accuracy and battery on iPhone and Watch.

## Not done / open

- **Fonts:** Fredoka/Nunito (free OFL fonts) aren't bundled; SF Pro Rounded is used. Bundling means
  adding the font files and setting `FFFontFamily`. Your call.
- **Not visually checked:** Progress, Badges, You tabs, the checkpoint celebration and the Watch
  complications (Xcode previews now need the watchOS 27.2 platform: Settings › Components; and
  simulator tapping needs an iOS 27 runtime). Home was checked in light and dark.
- **Judgment calls by the restyle pass worth a look:** ChallengeCard is orange (per
  ChallengeCard.md) and the Ticker inverted; settings icons all use the link colour; the rest banner
  in a strength session is teal; Lock Screen clock at title size so it fits; chart bars have no
  outline (Swift Charts limitation).
