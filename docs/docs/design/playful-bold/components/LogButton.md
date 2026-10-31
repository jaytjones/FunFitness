# LogButton

The round pink "+" that opens the log sheet; the one primary action on every tab.

**Maps to:** the `+` toolbar button that opens `LogActivitySheet` today. It moves from the top-right toolbar to the bottom-right, beside the TabBar, which also answers TestFlight item D1 ("improve the floating action button").

**States:** rest (offset shadow), pressed (moves 4px down-right, `shadow-press`), focused (3px `focus` ring, 3px offset).

**Long-press menu** (recommended): Log distance · Log weight · Log duration · Log reps · Repeat last. Tapping opens the sheet on the last-used type (A3).

**Accessibility:** label "Log an activity". 64pt target.

**Tokens:** `accent`, `on-accent`, `line`, `stroke-card`, `shadow-pop`, `shadow-press`, `focus`.
