# ProgressCharts

The Progress tab drawn as ink linework: overall figures, a stem chart for weekly volume, a stippled heatmap, records as a ruled table, per-type trackers.

**Maps to:** `ProgressTabView`: `OverallProgressCard`, `TrackingCard` (per type, next milestone), `WeeklyVolumeCard` (last 8 weeks), `PersonalRecordsCard`, `ActivityHeatmapCard` (last 12 weeks, Less to More). `MotivationalCard` becomes a single caption line if kept.

**Consumer provides:** totals, weekly series (per type, user's unit), PRs, a 12 × 7 grid of daily counts, per-type next milestone + fraction.

**Do**
- Weekly volume: stems in `ink` ending in a dot filled with the type colour; zero weeks get an open circle on the axis. Value labels over each stem in `data`.
- Heatmap: hairline cells in `line`, activity as 1 or 3 stipple dots in `ink`. Legend "Less / More" reads the same way.
- Charts carry an `aria-label` listing the values.
- Number figures "Fig. A", "Fig. B" in the label.

**Don't**
- Don't use filled colour bars or a colour ramp for the heatmap; density is shown by dot count so it works in both themes and in greyscale.
- Don't chart calories.

**Tokens:** `ink`, `ink-muted`, `line`, `type-*`, `progress-track`, `bg`, `numeral`, `data`, `label`.
