# ProgressMeter

A thick outlined pill that fills with the activity's color, with a hard ink edge where the fill stops.

**Maps to:** `FitnessProgressStyle` (today an 8pt rounded bar). Used by HeroStat, Progress tracking cards, ChallengeCard, RankCard and widgets.

**Consumer provides:** `value` 0–1, `type` (sets fill), optional end labels. Two sizes: regular (22pt) and slim (14pt, for lists and widgets).

**Rules**
- Always pair with end labels or a "1.6 mi to go" caption. The bar alone doesn't say what it measures.
- The fill edge is a 2.5px `line` stroke so the stop point reads without color.
- At 100%, keep the bar full and change the caption to "Complete!".
- Animate fill changes over 0.6s ease-in-out; with Reduce Motion, jump.

**Tokens:** `progress-track`, `type-*`, `line`, `stroke-control`, `radius-pill`, `caption`.
