# BadgeTile

A badge as a catalogued specimen: catalogue number, line drawing, milestone title, pack comparison, observed date. Locked ones are dashed outlines reading "Not yet observed".

**Maps to:** `AchievementsView` `AchievementCard` and `HomeView` `AchievementPreview` (`UnlockedAchievement`, `ComparisonEngine` milestones). Catalogue numbers follow milestone order: D1 = No. 01 through D10 = No. 15, W1 = No. 16 through W6 = No. 26, T1 = No. 27 through T8 = No. 34, R1 = No. 35 through R8 = No. 42.

**Consumer provides:** milestone id (for the number), title in the user's units, pack comparison + emoji/figure, unlock date or the lock hint.

**Do**
- Unlocked: `surface` fill, `line` hairline, "Observed Oct 3, 2026" in `data` + `accent-2`.
- Locked: dashed `ink-muted` outline, no fill, an empty frame with a diagonal, the hint "Reach 5 mi to unlock" in `data`.
- Pack figures: line drawings when the system has them; otherwise the pack's emoji centred in the frame (today's art).

**Don't**
- Don't grey out or blur a drawing to mean locked. Locked specimens have no drawing yet.
- Don't print the comparison for a locked badge; it spoils the reveal.

**Tokens:** `surface`, `line`, `ink`, `ink-muted`, `accent-2`, `headline`, `caption`, `label`, `data`.
