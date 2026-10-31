The log sheet: segmented type picker, big numeric input, reps toggle, sets stepper, date, surface chips and Repeat Last Activity.

**Maps to:** `LogActivitySheet` (and `SurfacePicker`, `RepeatLastButton`).

**Consumer provides**
- `type`, value, `includeReps` and rep count, `sets` (1–20), date, surface (distance only), notes.

**Do**
- The selected type segment fills with that type's colour and its `on-type-*` text.
- Show the computed total (weight × reps × sets) as a HUD line.

**Don't**
- Don't hide the units; they ride in the input in mono.

**Tokens:** `surface`, `surface-alt`, `line-strong`, `type-*`, `on-type-*`, `accent`, `hud`, `label`.
