# LogSheet

The log sheet as a blank field-guide entry: type tabs, one large numeral field on a ruled line, ruled form rows.

**Maps to:** `LogActivitySheet` (type picker, numeric field, reps toggle + count, Sets stepper 1 to 20, `SurfacePicker` chips Road/Track/Trail/Treadmill, backdating, notes) and `SelectionChip`.

**Consumer provides:** initial type, the value, reps toggle + count, sets, surface (distance only, optional), date, notes; validation messages.

**Do**
- Sheet body on `surface` with a 2px `ink` top rule. Rows separated by hairlines.
- Type picker: underlined mono tabs; the underline takes the type colour, the word stays `ink`.
- Numeral field: `numeral` at 44px on a 1px `ink` baseline, unit in `ink-muted`.
- Submit reads like the app: "Log 3 Sets" or "Log Weight". Full-width ink bar.
- Validation text in `danger` with the app's words ("Please enter a valid value greater than 0").

**Don't**
- Don't box fields. A single rule under the entry is the field.
- Don't show the surface chips for weight, duration or reps (shown here only to document them).

**Tokens:** `surface`, `ink`, `on-ink`, `ink-muted`, `line`, `type-*`, `danger`, `radius-md` (chips, stepper), `radius-pill` (system switch only).
