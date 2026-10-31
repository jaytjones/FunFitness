# LogSheet

The bottom sheet for logging: type picker, big number fields, sets stepper, date, one primary button.

**Maps to:** `LogActivitySheet`. Covers TestFlight A2–A5 and C2: reps on by default for Weight, opens on the last-used type, the rep count is a typed field (stepper kept only for Sets), and the Reps type carries the hint "Bodyweight moves like push-ups or squats".

**Consumer provides:** selected type, value(s), unit labels from the user's preference, sets (1–20), date, optional surface (Distance), notes.

**Layout by type**
- Distance: one field (mi/km) + Surface chips (Road · Track · Trail · Treadmill, optional; small chips, selected = `brand-yellow`).
- Weight: weight + reps fields side by side, Sets stepper, a caption that totals what will be saved.
- Duration: one field (min). Reps: one field + hint.

**Rules**
- Numbers are typed with the number pad. The field shows the unit inside, in muted ink.
- The summary caption is the confirmation; no second "are you sure".
- Calories never appear here.

**Tokens:** `surface`, `surface-alt`, `line`, `brand-yellow`, `numeral`, `headline`, `caption`, `radius-lg` (sheet top), `radius-md` (fields).
