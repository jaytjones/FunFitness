The weekly streak panel: weeks count in magenta, best streak and shield count.

**Maps to:** HomeView `StreakCard` (currently an orange gradient).

**Consumer provides**
- `currentStreak` (weeks), `longestStreak`, `shieldsAvailable`, `isActiveThisWeekStreak`, `onActivateShield`.

**Do**
- Always say weeks. "6 weeks · best 9".
- Offer "Use shield" only when the app does today: shields > 0, not active this week, streak > 0.

**Don't**
- Never say days.
- No loss state, red, or shaming copy when a streak ends. A 0 streak just reads "0 weeks" with the best kept.

**Tokens:** `surface`, `streak`, `success`, `ink-muted`, `line-strong`, `numeral`.
