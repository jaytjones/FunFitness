# StatTile

A full-color tile for each secondary activity type: total on the left, the live comparison on the right.

**Maps to:** the Weight, Duration and Reps `StatCard`s on `HomeView`. Their two-stop gradients (`ActivityType.cardGradient`) become one flat `type-*` fill with an outline.

**Consumer provides:** `type`, total display string, and the ticker phrase for that type (`ReferenceFit.phrase` with "!"), e.g. "2.6 grizzly bears!".

**Rules**
- Text on the fill uses the matching `on-type-*` token. Weight is white text in Sunny and dark text in After Dark; the tokens handle it.
- Label names the measure in plain words: WEIGHT LIFTED, TIME MOVING, REPS.
- Show only types the person has logged. A type with zero total is hidden, not shown as 0.
- Long comparisons wrap to three lines; never truncate the joke.

**Tokens:** `type-*`, `on-type-*`, `radius-md`, `numeral`, `headline`, `label`.
