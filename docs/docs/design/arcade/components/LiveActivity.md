Lock Screen and Dynamic Island readouts for a live run: clock, distance, pace, comparison line, Pause and End.

**Maps to:** `WorkoutLiveActivityWidget` (`FunFitnessWidgetLiveActivity`).

**Consumer provides**
- `elapsed`, `distance`, `pace`, `comparison`, paused state.

**Do**
- Dynamic Island is always black: use `device`, `on-device`, `device-muted`, `device-accent`.
- Lock Screen panel follows the theme.

**Don't**
- Don't put the comparison in the compact island; distance only.

**Tokens:** `surface`, `type-distance`, `device*`, `danger`, `numeral-sm`, `hud`.
