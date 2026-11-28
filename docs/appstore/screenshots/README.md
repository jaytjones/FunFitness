# App Store screenshots

App Store Connect slots (checked 2026-11-27; each filename ends in its pixel size):

| Slot | Folder | Size |
|---|---|---|
| **iPhone with Dynamic Island (medium display)**, the required one | `iphone-medium/` | 1206 × 2622 |
| iPhone with Dynamic Island (large display), optional | `iphone/` | 1320 × 2868 |
| iPhone with Face ID (large display), optional | `iphone-6.5/` | 1284 × 2778 |
| Apple Watch Ultra 3 | `watch/` | 422 × 514 |

Upload in file order. Slots left empty are filled by App Store Connect scaling a neighbouring size.
`iphone-medium/` is `iphone/` scaled with `sips -z 2622 1206`. iPhone Duo (1398 × 2034 outer, 2007 × 2853 inner)
is optional now and becomes required in April 2027 for apps built with the iOS 27.1 SDK or later.
`raw/` holds the uncaptioned captures. **No alpha channel** allowed: simulator Watch captures have one, so run
`scripts/screenshots/flatten.swift <in.png> <out.png>` on them.

## iPhone 6.9" (upload all 6)

| File | Caption | Launch arguments |
|---|---|---|
| iphone/01-home-1320x2868.png | Your workouts, in hippos | — |
| iphone/02-celebration-1320x2868.png | Hit milestones you'll want to share | `-previewCelebration W2` |
| iphone/03-track-walk-1320x2868.png | Track walks and runs, indoors or out | `-previewTracker walk` |
| iphone/04-strength-session-1320x2868.png | Lift smarter: see last time's sets | `-previewStrength YES` |
| iphone/05-progress-1320x2868.png | Watch your progress add up | `-previewTab 1 -previewScroll 0.55` |
| iphone/06-streak-1320x2868.png | Keep your streak alive | `-previewScroll 0.3` (status bar patched, see below) |

Spare raws: `raw/extra-exercise-history.png` (`-previewExercise bench-press`) and `raw/extra-badges.png`
(`-previewTab 2`).

## Apple Watch Ultra 3 (upload all 3, no captions)

| File | Shows | Launch arguments |
|---|---|---|
| watch/01-home-422x514.png | This week's points, streak, Track | `-seedSampleData` |
| watch/02-walk-422x514.png | A walk under way | `-seedSampleData -previewWorkout walk` |
| watch/03-quick-log-422x514.png | Quick-log a lift | `-seedSampleData -previewQuickLog lift` |

## How they were made (2026-11-27)

- Debug build with the internal flags off, so the Release feature set (four tabs, Playful Bold, no Friends):
  `xcodebuild … -derivedDataPath /tmp/ffshots SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG build`.
- iPhone 17 Pro Max simulator; every launch adds `-seedSampleData -localDataNoticeDismissedAt <unix time>`;
  status bar: `simctl status_bar … override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularBars 4
  --batteryState discharging --batteryLevel 100`. The first launch after an install sometimes shows onboarding;
  relaunch.
- The walk follows MapKit walking directions through Central Park (needs network), with
  `simctl privacy … grant location` and `simctl location … set 40.7669,-73.9790`.
- All the `-preview…` arguments are `#if DEBUG` only.
- Captions: `scripts/screenshots/compose.swift` (SF Pro Rounded Heavy on brand yellow, ink border and hard
  shadow). `swiftc -O compose.swift -o compose`, then
  `compose <raw.png> "<caption>" <out.png> [statusBarSource.png]`; `W=1284 H=2778 compose …` for the 6.5" set. `\n` in a caption forces a line break
  (04 uses `Lift smarter:\nsee last time's sets`). Pass `raw/01-home.png` as the fourth argument for a
  scrolled shot: it pastes a clean status bar over content that scrolled under it.
