The Stats tab panels: overall counts, neon weekly-volume bars, personal records and a 12-week heatmap in cyan intensity.

**Maps to:** `ProgressTabView` with `OverallProgressCard`, `WeeklyVolumeCard`, `PersonalRecordsCard`, `ActivityHeatmapCard`.

**Consumer provides**
- Weekly totals for 8 weeks in display units, records, 84 daily activity counts.

**Do**
- Bars in the type colour on `surface`; zero weeks show a 2px `progress-track` stub.
- Heatmap: `accent` at 0 / 35 / 60 / 80 / 100% over `progress-track`, with Less → More legend.

**Don't**
- Don't add a calorie chart.
- Don't glow the bars; glow is for card art only.

**Tokens:** `surface`, `type-*`, `accent`, `progress-track`, `line-strong`, `numeral`, `numeral-sm`.
