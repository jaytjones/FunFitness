# LogButton

The primary action: a full-width ink bar reading "Log an entry", pinned above the tab bar on Guide.

**Maps to:** the `plus.circle.fill` button in `HomeView` toolbar and `TrackWorkoutCard` / `RepeatLastButton`, which open `LogActivitySheet`. The bar replaces the floating plus.

**Consumer provides:** the tap action; optionally a repeat-last line (from `RepeatLastButton`'s last activity) shown as a mono sub-label.

**Do**
- Fill with `ink`, text in `on-ink`, Fraunces 20/700. Square corners (`radius-sm`).
- Keep it full width inside the `space-6` gutter, `space-3` above the tab bar's heavy rule.
- Long-press offers the same choices the plus menu does today (log, live walk/run, strength session).

**Don't**
- Don't colour it rust. Rust marks progress; the action is ink.
- Don't show it on Progress or Collection. One primary action, on Guide.

**Tokens:** `ink`, `on-ink`, `focus`, `radius-sm`, `space-3`, `space-4`.
