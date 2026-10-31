The empty binder: a dashed card slot, a heading and the app's own empty-state copy with a Log button.

**Maps to:** `EmptyAchievementsState` (and `AchievementPreview`'s empty branch).

**Consumer provides**
- `title`, `message`, `action`.

**Do**
- Reuse the dashed slot so the empty state looks like the first page of the binder.
- Keep the app's copy: "Start logging your activities to unlock fun achievements and comparisons!"

**Don't**
- Don't use a lock emoji as decoration.

**Tokens:** `line-strong`, `ink`, `ink-muted`, `accent`, `on-accent`, `title`.
