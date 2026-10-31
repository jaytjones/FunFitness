# ActivityRow

A ledger line for one logged activity: date in mono on the left, entry in serif on the right, hairline under.

**Maps to:** `HomeView` `RecentActivityCard` (last 5) and `ActivityHistorySheet` `ActivityRow` / `SessionRow` (one row per strength session).

**Consumer provides:** relative date, activity name, value with unit, optional surface, optional sets line ("40 lbs × 10").

**Do**
- Date column in `data` + `ink-muted`, fixed width so entries align.
- Entry in Newsreader 17/600 in `ink`; a sub-line in 15 `ink-muted` for sets.
- Join parts with a middle dot: "Run · 0.8 mi · Road".
- Swipe actions keep the system look (Edit, Delete in `danger`).

**Don't**
- Don't add per-type icons or coloured dots. The ledger is text.
- Don't show kcal.

**Tokens:** `ink`, `ink-muted`, `line`, `accent`, `data`, `headline`.
