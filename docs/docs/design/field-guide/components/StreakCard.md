# StreakCard

The weekly streak as a tally: big count in `streak`, a hand-drawn tally of weeks, a shield outline when one is available.

**Maps to:** `HomeView` `StreakCard` and its shield explanation (`StreakEngine`, `StreakRecord`). Streaks count WEEKS, never days.

**Consumer provides:** current streak (weeks), best streak, shields available.

**Do**
- Count in `numeral` + `streak`; word "weeks" in `body`.
- Draw tallies in groups of five with a strike, in `streak`; cap the drawing at 10 and show "+N" past that.
- Say what the shield does in the caption, as the app's sheet does.

**Don't**
- Don't use a flame emoji in the chrome. The app's 🔥 stays in widgets only if the owner wants it.
- Don't say "days".

**Tokens:** `streak`, `ink`, `ink-muted`, `line`, `numeral`, `caption`, `label`.
