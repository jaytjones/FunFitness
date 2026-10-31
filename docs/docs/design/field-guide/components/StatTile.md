# StatTile

A per-type figure set in a ruled grid: plate label, big numeral, a thin ruler and "to go".

**Maps to:** `HomeView` `StatCard` (one per type) and `ProfileView` `StatBox`.

**Consumer provides:** activity type, formatted total, progress fraction to the next milestone, formatted remaining ("1.6 mi to go"). Optional aside caption from the ticker line.

**Do**
- Separate tiles with hairlines in `line`: a 2-up grid with a vertical rule between columns and a rule under each row. No boxes.
- Label in the type colour (`type-distance`, `type-weight`, `type-duration`, `type-reps`); numeral in `ink`.
- Use the specimen-aside variant (numeral left, italic caption right) for a single highlighted type on Home.

**Don't**
- Don't show calories here.
- Don't colour the numeral. Colour sits on the label and bar only.

**Tokens:** `line`, `ink`, `ink-muted`, `type-*`, `progress-track`, `numeral`, `label`, `caption`.
