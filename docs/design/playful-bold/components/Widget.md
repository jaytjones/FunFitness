# Widget

Home Screen widgets on the yellow ground: small shows the streak and title, medium shows the month's challenge and Distance/Lift progress.

**Maps to:** `FunFitnessWidgets` (`.systemSmall`, `.systemMedium`), fed by the App Group snapshot.

**Consumer provides:** streak weeks, rank, title, challenge title and %, distance and weight totals with remaining-to-next-milestone strings.

**Rules**
- The widget ground is `bg`, so it follows the system appearance: yellow in light, grape in dark. In tinted/clear Home Screen modes, drop fills and keep the outlines, which survive the tint.
- Text sizes stay at or above 11pt; the "to next milestone" lines are the smallest text allowed.
- Last month's challenge is hidden until the app refreshes the snapshot.
- Medium layout: challenge in an inset white tile on the left, Distance and Lift bars on the right.

**Tokens:** `bg`, `on-accent`, `surface`, `line`, `numeral`, `label`, ProgressMeter slim.
