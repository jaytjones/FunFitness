A small HUD panel with a mono label, a big rounded Rubik numeral and one muted line under it.

**Maps to:** HomeView `StatCard` (per-type totals) and the Weight / Streak pair under the featured card. Also ProfileView `StatBox`.

**Consumer provides**
- `label` (WEIGHT), `value` (1,240), optional `unit` word, `sub` line (the real ticker comparison), `type` for colour.

**Do**
- Use the real ReferenceUnit output in `sub`: "lbs · 2.6 grizzly bears".
- Set the unit word at 0.62em next to the numeral ("6 weeks").

**Don't**
- Don't show calories.
- Don't make up comparisons; if the ticker has none for a type, show the plain total.

**Tokens:** `surface`, `line`, `ink-muted`, `type-*`, `streak`, `numeral`, `label`, `caption`.
