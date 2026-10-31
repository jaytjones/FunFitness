The 8-segment progress bar with a HUD readout, used for every milestone and challenge.

**Maps to:** ProgressView `TrackingCard` and the progress bars inside `StatCard` and `ChallengeCard`.

**Consumer provides**
- `progress` 0–1, `type`, `total`/`goal` strings, `remaining` string.

**Do**
- Lit segments use the activity's `type-*`; unlit use `progress-track` (lit holds 3:1 against unlit).
- Always pair with the % and the "to go" text so it is readable without colour.

**Don't**
- Don't animate segment by segment when Reduce Motion is on.
- Don't use more or fewer than 8 segments; consistency is the point.

**Tokens:** `progress-track`, `type-*`, `hud`, `caption`, `space-1`.
