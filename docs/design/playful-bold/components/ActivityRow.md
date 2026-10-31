# ActivityRow

A list row for one log or one strength session: type chip, title, detail, date.

**Maps to:** Recent Activity on `HomeView` (last 5) and rows in `ActivityHistorySheet` (one row per `WorkoutSession`).

**Consumer provides:** type, title ("Strength · 3 sets · 1,200 lbs"), detail (surface, "40 lbs × 10", Indoor/Outdoor), optional note pill ("Auto-grouped"), relative date.

**Rules**
- Rows sit inside one outlined list card, separated by a dashed `progress-track` rule, not separate cards.
- The type chip is a 44pt rounded square in the type color with a line glyph; no emoji in the chip.
- Swipe to delete on Home; tap a session row to open its detail.
- Calories never appear in rows.

**Tokens:** `surface`, `line`, `type-*`, `on-type-*`, `body-strong`, `caption`, `ink-muted`, `radius-sm`.
