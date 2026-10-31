# Ticker

The "Right Now..." ticker as numbered field notes: one line per type, roman-numeralled.

**Maps to:** `HomeView` `AbsurdityTicker` ("<total> is <count> <unit> <emoji>" from `ReferenceUnit`). The lead line also feeds the HeroStat headline.

**Consumer provides:** the ticker strings, in type order.

**Do**
- Print the strings exactly as `ReferenceUnit` writes them, emoji included.
- Number with lowercase roman numerals in `data`, `ink-muted`.
- Static list; if it auto-advances, honour Reduce Motion by showing all four.

**Don't**
- Don't marquee-scroll. Field notes sit still.

**Tokens:** `ink`, `ink-muted`, `line`, `body`, `data`, `label`.
