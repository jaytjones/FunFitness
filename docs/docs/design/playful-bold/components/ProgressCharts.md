# ProgressCharts

Outlined bar chart for weekly volume and a rounded-cell heatmap for the last 12 weeks, both in cards.

**Maps to:** `ProgressView` Weekly Volume (Swift Charts, last 8 weeks) and "Activity — Last 12 Weeks" heatmap. Personal Records use StatTile-style rows.

**Consumer provides:** 8 weekly totals in the user's unit, 84 daily counts mapped to 4 steps.

**Rules**
- Bars use the selected type's color with a 2.5px outline and rounded tops; zero weeks are a thin `progress-track` stub, not empty space.
- Label the first and last weeks and one in the middle; never every week.
- Heatmap steps: 0 `progress-track`, 1 `heat-1`, 2 `heat-2`, 3+ `heat-3`, each cell outlined so steps differ by more than hue.
- Charts carry an accessibility label that reads the values.
- Example data: weekly distance 0, 0, 0.5, 0.8, 0, 0.6, 0.7, 0.8 mi (sums to the 3.4 mi total).

**Tokens:** `type-*`, `progress-track`, `heat-1..3`, `line`, `caption`, `ink-muted`.
