# EmptyState

An empty page in the guide: one dashed, unobserved specimen frame, the app's empty copy, and the Log an entry bar.

**Maps to:** `AchievementsView` `EmptyAchievementsState`, `HomeView` `AchievementPreview` empty line ("Log your first activity to unlock achievements!"), empty History.

**Consumer provides:** title, message, optional action.

**Do**
- Keep the app's copy. Swap only the art: a dashed `ink-muted` frame replaces the lock emoji and faded emoji row.
- Centre the block with `space-12` above and below.

**Don't**
- Don't stack decorative emoji. One empty frame says it.

**Tokens:** `ink`, `ink-muted`, `line`, `on-ink`, `title`, `body`, `space-12`.
