A list row for one logged activity: type pip, summary line, optional detail, relative date.

**Maps to:** `ActivityRow` and `SessionRow` in ActivityHistorySheet, and HomeView `RecentActivityCard` (last 5).

**Consumer provides**
- `type`, summary ("Run · 0.8 mi · Road"), optional detail ("40 lbs × 10"), date label.

**Do**
- One row per strength session, as History does today.

**Don't**
- Don't show kcal here.

**Tokens:** `surface`, `line`, `type-*`, `ink`, `ink-muted`, `body-strong`, `caption`.
