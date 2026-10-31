A trading card in the binder grid: rarity frame, pack art, title, rarity word and milestone id; locked = dashed silhouette slot.

**Maps to:** `AchievementsView` `AchievementCard` (and `ProgressBanner` as the 8 / 42 counter). Tab renamed to Cards.

**Consumer provides**
- `milestone`, `unlockedAt?`, `rarity` (derived), `pack` emoji, locked threshold text ("Reach 5 mi to unlock").

**Do**
- Group by activity type with a "Distance · 2 / 15" header.
- On Home, the collection row shows the last three unlocked cards as small slots plus one dashed slot for the next card (`.slots`).
- Show the rarity as a word as well as the frame colour.

**Don't**
- Don't grey out or blur locked cards to the point the requirement is unreadable.
- Don't sell or trade cards; they are badges.

**Tokens:** `surface`, `surface-alt`, `glow`, `rarity-*`, `line-strong`, `ink`, `ink-muted`, `radius-md`.
