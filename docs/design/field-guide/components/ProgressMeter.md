# ProgressMeter

The ruler: tick marks above a solid bar, labels below. The guide's only progress indicator.

**Maps to:** every `ProgressView`/bar in the app: `StatCard` and `TrackingCard` next-milestone bars, `ChallengeCard` %, `ProgressBanner` in `AchievementsView`, widget bars.

**Consumer provides:** fraction (0 to 1), activity type (picks the bar colour), left label (logged amount) and right label (milestone target with its short pack phrase, or "N to go").

**Do**
- Ticks in `line`: minor every 5%, major every 25%. Bar fill in the type colour (or `accent`); the unfilled length is a 1px `progress-track` rule.
- Left label "3.4 mi logged"; right label "5 mi: 270 blue whales" (target + the milestone's own comparison noun phrase) or "1.6 mi to go".
- Expose `progressbar` semantics with the value; VoiceOver: "Distance, 68 percent, 1.6 miles to go".
- Animate fills left to right over 400ms; none with Reduce Motion.

**Don't**
- Don't round the bar ends or add a track box. It's a ruler, not a pill.
- Don't make up a phrase for the right label; use the milestone comparison or "to go".

**Tokens:** `line`, `progress-track`, `accent`, `type-*`, `ink`, `space-2`.
