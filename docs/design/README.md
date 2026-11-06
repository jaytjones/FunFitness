# FunFitness design systems

Three competing visual directions, built 2026-10-18 from the repo at `76e7e12` (3.1 build 9). Each folder holds one system:

| Folder | Style | Primary mode | Live previews |
|---|---|---|---|
| `playful-bold/` | Playful Bold | Light (Sunny), dark After Dark | https://claude.ai/artifact/7YG39YgGZqGu9HvcBprDrL |
| `field-guide/` | Field Guide | Light (Daylight), dark Lamplight | https://claude.ai/artifact/VtrA8JAqHvXcE9AWAw6QTY |
| `arcade/` | Arcade | Dark (Arcade), light Daylight | https://claude.ai/artifact/CvzJty7ecr25b8M3wYQWJ8 |

The links are private to April's account until shared.

## Status

- **Playful Bold is the app's style (Jay, 2026-11-06), built in 3.2 "New Look".** Today's old look
  is retired, not kept as a style. Tokens live in `Shared/Style.swift` (from `playful-bold/tokens.json`);
  structural pieces (floating word TabBar + LogButton, HeroStat, StatTile, "Compare with") in
  `FunFitness/PlayfulChrome.swift` and `HomeView.swift`.
- **Arcade, then Field Guide** become unlockable styles in 3.3 (earned + purchased; rules TBD). The
  chosen style syncs (`UserProfile.activeStyleID`).
- Fonts: Fredoka/Nunito aren't bundled yet; SF Pro Rounded is used (the README's fallback).
  Bundling them is one change in `FFFontFamily`.

## Changes since build 9

The app changed after these guides were written. Fold these into whichever style is chosen.
Details: `docs/20261031_testflight_feedback.md`.

- **New component, NowTrackingBar (22nd).** A pinned bar above the tab bar on every tab while a walk/run
  or strength session is running or waiting for review: icon, title, live detail, chevron ("Walk · 1.2 mi ·
  18:42", "Strength · 3 sets · Rest 0:45"). Tap reopens the session. iOS 26.1+ uses the tab bar's bottom
  accessory (system glass, shrinks inline when the tab bar minimizes); earlier iOS uses a material capsule.
  Code: `NowTrackingBar.swift` (`NowTrackingContent`, `NowTrackingRow`). Not specced in any style yet. Spec
  it once a style is picked, next to TabBar and LiveActivity. (FB-0003)
- **Home's Track and Strength cards only show when idle.** While a session runs, the bar replaces them.
- **Live strength sets can be deleted:** swipe left (iOS 27+) or long-press → Delete Set on the session
  screen's set list. Same rules as ActivityRow swipe actions. (FB-0001)
- **Copy:** distance milestones say "You've covered 5 miles!", not "You've run". The medium widget's
  first row is "Distance", not "Run", and its empty state is "Log a walk or run!". (FB-0004; the
  guides above are updated.)
- **The `+` button (LogButton) stays as it is until a style is picked.** Testers find it bland
  (TestFlight FB-0015).

## How to use these files

- `tokens.json` is the source of truth for colors (light and dark values), type, spacing and radius. Generate Swift tokens and asset-catalog colors from it; don't copy hex values by hand.
- `README.md` in each folder is the brand book: voice, color and type rules, iconography, a SwiftUI mapping and "Adapting the app" (what that style changes structurally).
- `components/<Name>.md` covers each of the 21 components: which SwiftUI view it maps to, the data it needs, do/don't and the tokens it uses.
- All three use the same token names and component names, so code written against them can switch styles.
- In code, call the switch **Style**, not Theme. `activeTheme` already means the content pack.

## Components (same 21 in every style)

TabBar, LogButton, HeroStat, StatTile, ProgressMeter, PackPicker, StreakCard, RankCard, ChallengeCard, Ticker, ActivityRow, Button, LogSheet, BadgeTile, Celebration, ShareCard, ProgressCharts, Widget, LiveActivity, SettingsRow, EmptyState.

Sample numbers in the guides are one example user (imperial, Animals pack): 3.4 mi, 1,240 lbs, 1.6 hr, 180 reps, 8 of 42 badges, Silver, 6-week streak.
