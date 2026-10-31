# RankCard

The silly title and rank, with progress to the next rank counted in badges.

**Maps to:** the title card on `HomeView` (`SillyTitleEngine`: Unranked → Diamond).

**Consumer provides:** title, rank name, badges unlocked, badges needed for the next tier (from the tier table: 1, 2, 4, 8, 12, 16, 20).

**Rules**
- The title is the headline; the rank is the small label. People remember "Elite Elephant Wrangler", not "Silver".
- Medal ring fill follows the rank: `progress-track` for Iron–Silver, `brand-yellow` for Gold, `surface` for Platinum, `accent-2` for Diamond.
- At Diamond, drop the meter and say "Top rank. Every badge from here is bragging rights."

**Tokens:** `surface`, `accent-2` (ribbon), `headline`, `label`, ProgressMeter slim.
