# Celebration

The full-screen milestone moment on the yellow ground: confetti, the illustrated badge, the title and the comparison.

**Maps to:** `MilestoneView` (confetti, haptics, one screen per activity type per event, including Health imports).

**Consumer provides:** milestone title, pack comparison sentence, illustration, Keep Going and Share actions.

**Motion:** confetti pieces are the outlined rectangles from the illustration set, falling for 1.2s with a light rotation; the badge pops in (scale 0.6 → 1.05 → 1, spring). With Reduce Motion: no confetti fall, the badge fades in, the haptic still plays.

**Rules**
- Comparison copy is used exactly as written in `ComparisonEngine` (it never contains units).
- Several unlocks at once: one screen each, with "1 of 3" as a small label. Never stack titles on one screen.
- In After Dark, the ground is grape and confetti keeps its fills.

**Tokens:** `bg`, `display`, `title`, primary and secondary Button, illustration classes.
