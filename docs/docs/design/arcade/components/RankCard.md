The level panel: "LVL 4 · Silver", the silly title and 8 tier pips.

**Maps to:** HomeView `SillyTitleBanner` (`SillyTitleEngine`).

**Consumer provides**
- `rank` and its index in the 8 tiers (Unranked = LVL 0 … Diamond = LVL 7), `title`, `badgeCount`, `badgesToNext` and next rank name.

**Do**
- Level is just the rank tier index. No separate level math.
- Show "4 badges to Gold" from the real tier thresholds (0,1,2,4,8,12,16,20).

**Don't**
- Don't invent XP or level-up bars that move on anything but badge count.

**Tokens:** `rank`, `progress-track`, `ink`, `ink-muted`, `title`, `hud-strong`.
