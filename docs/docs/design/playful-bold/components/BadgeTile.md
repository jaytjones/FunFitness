# BadgeTile

A two-up grid tile for one milestone badge: illustrated when unlocked, a dashed outline with a lock when not.

**Maps to:** `AchievementsView` (Unlocked / Locked sections, 42 milestones) and "Recent Achievements" on Home.

**Consumer provides:** milestone title in the user's units, pack art (emoji today, illustration later), unlock date or the "Reach … to unlock" line.

**Rules**
- Unlocked: white face, shadow, art in a 64pt circle. Tap opens the comparison sentence and Share.
- Locked: no fill, dashed outline, no shadow, lock glyph. Never show the locked comparison; it's the surprise.
- Section header shows "8 of 42 unlocked". Ordering: by type, then threshold.

**Tokens:** `surface`, `line`, `shadow-pop`, `radius-md`, `surface-alt`, `headline` at 17pt, `caption`.
