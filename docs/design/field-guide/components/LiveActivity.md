# LiveActivity

The live walk/run on the Lock Screen and Dynamic Island: clock, distance, pace, the comparison line as a caption, Pause/Resume and End.

**Maps to:** `WorkoutLiveActivityWidget` (`WorkoutLockScreenView`, `WorkoutClock`, `CompactTimer`, `RestCountdown`, `WorkoutStatsRow`, `WorkoutControls`) with `WorkoutLiveActivityAttributes` from `Shared/WorkoutLiveActivity.swift`. Strength sessions swap Pause for "Log Set" and show the rest timer.

**Consumer provides:** title + emoji, elapsed (timer), primary value/label, secondary value/label, comparison, paused/finished state, rest window.

**Do**
- Use the fixed `live-*` tokens in BOTH themes: `activityBackgroundTint` = `live-ground`, text `live-ink`, labels `live-ink-muted`, End and the distance in `live-accent`. The lock screen is dark system material whatever the app theme is.
- Keep numerals monospaced so the clock doesn't jitter.
- Buttons are hairline outlines with mono uppercase labels; End in `live-accent`.

**Don't**
- Don't use parchment on the lock screen; it glares at night and fights the wallpaper.
- Don't put more than one line of comparison copy.

**Tokens:** `live-ground`, `live-ink`, `live-ink-muted`, `live-accent`, `numeral`, `label`, `caption`.
