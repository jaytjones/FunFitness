# LiveActivity

Lock Screen and Dynamic Island readouts for a tracked walk/run or strength session.

**Maps to:** `WorkoutLiveActivityWidget` (live clock, distance, pace, comparison line, Pause/Resume/End; strength: sets, last set, rest countdown, Log Set/End).

**Consumer provides:** activity kind, elapsed time, distance and pace (or sets and rest), comparison line, state (running / paused / finished).

**Rules**
- Lock Screen: a `surface` card with the outlined tag and the clock as the largest element. Pause is secondary; End is the pink primary.
- Dynamic Island compact: a pink dot + distance leading, time trailing (matches the 3.1 fix). Island is always `island` black with `island-ink` text; no outlines inside it.
- Paused: the clock dims to `ink-muted` and the tag reads PAUSED.
- No offset shadows on system surfaces; iOS clips them.

**Tokens:** `surface`, `line`, `accent`, `numeral`, `headline`, `caption`, `island`, `island-ink`.
