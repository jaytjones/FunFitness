# FunFitness design systems

Three competing visual directions, built 2026-10-18 from the repo at `76e7e12` (3.1 build 9). Each folder holds one system:

| Folder | Style | Primary mode | Live previews |
|---|---|---|---|
| `playful-bold/` | Playful Bold | Light (Sunny), dark After Dark | https://claude.ai/artifact/7YG39YgGZqGu9HvcBprDrL |
| `field-guide/` | Field Guide | Light (Daylight), dark Lamplight | https://claude.ai/artifact/VtrA8JAqHvXcE9AWAw6QTY |
| `arcade/` | Arcade | Dark (Arcade), light Daylight | https://claude.ai/artifact/CvzJty7ecr25b8M3wYQWJ8 |

The links are private to April's account until shared.

## Status

- **No default style chosen yet.** Don't build any style until one is picked.
- Still deciding between one style, or switchable styles shipped one at a time.

## How to use these files

- `tokens.json` is the source of truth for colors (light and dark values), type, spacing and radius. Generate Swift tokens and asset-catalog colors from it; don't copy hex values by hand.
- `README.md` in each folder is the brand book: voice, color and type rules, iconography, a SwiftUI mapping and "Adapting the app" (what that style changes structurally).
- `components/<Name>.md` covers each of the 21 components: which SwiftUI view it maps to, the data it needs, do/don't and the tokens it uses.
- All three use the same token names and component names, so code written against them can switch styles.
- In code, call the switch **Style**, not Theme. `activeTheme` already means the content pack.

## Components (same 21 in every style)

TabBar, LogButton, HeroStat, StatTile, ProgressMeter, PackPicker, StreakCard, RankCard, ChallengeCard, Ticker, ActivityRow, Button, LogSheet, BadgeTile, Celebration, ShareCard, ProgressCharts, Widget, LiveActivity, SettingsRow, EmptyState.

Sample numbers in the guides are one example user (imperial, Animals pack): 3.4 mi, 1,240 lbs, 1.6 hr, 180 reps, 8 of 42 badges, Silver, 6-week streak.
