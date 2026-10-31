The "Right now..." panel: one line per activity type comparing the total to something absurd.

**Maps to:** HomeView `AbsurdityTicker` (purple gradient today).

**Consumer provides**
- `lines` from `viewModel.absurdityTickerText(for:)`, one per type that has one.

**Do**
- Prefix each line with a short mono type tag (DIST, WT, TIME, REPS) in that type's colour.
- Lines are `headline` in `ink`.

**Don't**
- Don't truncate lines; let them wrap.

**Tokens:** `surface`, `ink`, `type-*`, `line`, `headline`, `hud-strong`.
