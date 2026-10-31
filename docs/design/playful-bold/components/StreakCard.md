# StreakCard

The weekly streak: a flame, the count in weeks, best run and shields left.

**Maps to:** the "Weekly Streak" card on `HomeView` (`StreakEngine`, streak shields).

**Consumer provides:** current streak (weeks), best, shields available, share action.

**Rules**
- Streaks are weekly. Always write "weeks", never "days".
- The share button sits in reserved trailing space (`padding-right` 64pt), so the number can never run under it. This fixes TestFlight item A1; check it at the largest Dynamic Type size.
- Tap the shield line to explain shields: "A streak shield protects your streak for one missed week."
- A broken streak shows "Start a new streak this week" with the best kept. No sad states, no red.

**Tokens:** `streak` (flame), `brand-yellow` (flame core), `surface`, `numeral`, `caption`, `ink-muted`.
