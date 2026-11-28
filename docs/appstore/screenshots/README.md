# App Store screenshots

Upload `iphone/` (iPhone 6.9", 1320 × 2868) and `watch/` (Apple Watch Ultra 3, 422 × 514) in file order.
`raw/` holds the uncaptioned captures the captioned set is made from. `iphone-6.5/` is the same set at
1284 × 2778, for the 6.5" slot if App Store Connect asks for it.

Apple's rules (checked 2026-11-27): 6.9" accepts 1320 × 2868, 1290 × 2796 or 1260 × 2736; 6.5" accepts
1284 × 2778 or 1242 × 2688; Watch Ultra 3 is 422 × 514. **No alpha channel**: simulator Watch captures
have one, so run `scripts/screenshots/flatten.swift <in.png> <out.png>` on them.

## iPhone 6.9" (upload all 6)

| File | Caption | Launch arguments |
|---|---|---|
| iphone/01-home.png | Your workouts, in hippos | — |
| iphone/02-celebration.png | Hit milestones you'll want to share | `-previewCelebration W2` |
| iphone/03-track-walk.png | Track walks and runs, indoors or out | `-previewTracker walk` |
| iphone/04-strength-session.png | Lift smarter: see last time's sets | `-previewStrength YES` |
| iphone/05-progress.png | Watch your progress add up | `-previewTab 1 -previewScroll 0.55` |
| iphone/06-streak.png | Keep your streak alive | `-previewScroll 0.3` (status bar patched, see below) |

Spare raws: `raw/extra-exercise-history.png` (`-previewExercise bench-press`) and `raw/extra-badges.png`
(`-previewTab 2`).

## Apple Watch Ultra 3 (upload all 3, no captions)

| File | Shows | Launch arguments |
|---|---|---|
| watch/01-home.png | This week's points, streak, Track | `-seedSampleData` |
| watch/02-walk.png | A walk under way | `-seedSampleData -previewWorkout walk` |
| watch/03-quick-log.png | Quick-log a lift | `-seedSampleData -previewQuickLog lift` |

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
