# Widget

Home Screen widgets in the guide's language: a ruled masthead line, mono labels, numerals, thin rulers.

**Maps to:** `FunFitnessWidgets` `SmallWidgetView` (streak + title) and `MediumWidgetView` / `MediumStatRow` (this month's challenge %, Run and Lift totals with "X to next milestone" under each bar). Data from `FunFitnessWidgetData`.

**Consumer provides:** streak weeks, silly title, challenge name/emoji/fraction, Run and Lift totals, fractions and remaining strings.

**Do**
- Use `containerBackground` = `surface`; the system clips the corners.
- Use the thin ruler (`ff-ruler--thin`) for bars; Run bar `type-distance`, Lift bar `type-weight`.
- Support the accented / tinted rendering mode: rules and ruler fills become the accent tint, text stays primary.

**Don't**
- Don't draw plates in widgets. There's no room for the illustration and its caption.
- Don't fake a corner radius in the view; the widget container owns it.

**Tokens:** `surface`, `ink`, `ink-muted`, `line`, `streak`, `type-distance`, `type-weight`, `progress-track`, `numeral`, `label`, `data`, `caption`.
