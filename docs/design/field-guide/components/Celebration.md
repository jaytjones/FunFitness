# Celebration

The milestone moment as a freshly recorded plate: a "New entry recorded" stamp, the milestone title, the plate with a scale bar and the pack comparison as its caption, then Keep Going and Share.

**Maps to:** `MilestoneView` (with `ConfettiView`, haptics, Reduce Motion handling).

**Consumer provides:** milestone id (catalogue number), title in user units, pack figure and comparison text, emoji, unlocked count and next-rank distance.

**Do**
- Animate as ink being drawn: the plate's strokes trace in over 600ms, the stamp lands with one haptic. With Reduce Motion, show the finished plate and keep the haptic.
- Confetti, if kept, is small paper flecks in `ink`, `accent` and `accent-2`, falling once.
- Quote the comparison exactly (the em dash here is the app's own copy).

**Don't**
- Don't turn the screen rust or add a gradient. The page stays parchment.

**Tokens:** `bg`, `surface`, `ink`, `ink-muted`, `accent-2`, `line`, `display`, `caption`, `label`.
