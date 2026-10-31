# Ticker

The inverse "Right now…" card that restates every total as a count of real-world things from the active pack.

**Maps to:** `AbsurdityTicker` on `HomeView` (`AppViewModel.absurdityTickerText(for:)`). Lines are the real engine output for the example totals.

**Consumer provides:** one string per logged type, in `ActivityType.allCases` order.

**Rules**
- The card is inverted (`ink` fill, `surface` text) so it reads as a different kind of thing from stat cards. In After Dark it flips to a cream card with grape text.
- Keep the emoji at the end of each line; that's where the app puts it.
- When HeroStat already shows the primary type, the Ticker can drop that line.

**Tokens:** `ink`, `surface`, `headline`, `label`.
