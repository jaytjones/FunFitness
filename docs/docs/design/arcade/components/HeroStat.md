The featured "next card": the next distance milestone shown as an unflipped trading card with a gradient border, rarity tag, silhouette art and segmented progress.

**Maps to:** Replaces the top of HomeView (the four `StatCard`s lead with distance today). Data comes from the same next-milestone lookup `StatCard` uses (`nextMilestone`, `progress`, `remainingDisplay`).

**Consumer provides**
- `milestone` (id, title, comparison, pack emoji), `positionInType` and `countInType` ("NEXT 03/15"), `rarity` (derived, see README), `total` and `threshold` in display units, `progress` 0–1, `remaining` string.
- `badgesToNextRank` for the "+1 badge · 4 to Gold" line.

**Do**
- Show the pack emoji as a single-colour silhouette in the activity's `type-*` colour until it unlocks.
- Lit segments = round(progress × 8), clamped to 1–7 until the milestone is reached (68% → 5, 50% → 4, 63% → 5, 72% → 6, 8% → 1).

**Don't**
- Don't show XP. The app has none; the payoff line is +1 badge and badges to the next rank.
- Don't put text on the glow.

**Tokens:** `surface`, `surface-alt`, `glow`, gradient stops, `rarity-*`, `on-rarity`, `type-distance`, `progress-track`, `ink`, `ink-muted`, `shadow-neon`, `display-hero`, `hud`, `label`.
