# Workout Score — Design Draft (C7, 2026-10-17)

**Status:** draft for discussion; nothing is built. Feedback (2026-10-12): a workout "score" that
isn't just calories, and the formula must be written down for users.

## Goals

- Rewards effort across every activity type (walks, runs, strength, duration, reps) on one scale.
- Not calories: FunFitness is about fun comparisons, not diet. Calories stay an estimate tucked into
  the session detail and Apple Health (C4).
- Explainable in two sentences on a "How your score works" screen.
- Works without an Apple Watch; heart rate makes it better when present.

## Candidate formula — "Effort Points"

Effort Points = minutes of activity × intensity

| Intensity source (best available first) | Value |
|---|---|
| Heart-rate zones (B2), when Health has readings | Zone 1 = 1, Zone 2 = 2, Zone 3 = 3, Zone 4 = 4, Zone 5 = 5 points per minute |
| Activity MET, otherwise | MET ÷ 2 points per minute (walk 3.5 → 1.75, run 9.8 → 4.9, strength 3.5 → 1.75) |

- Minutes: tracked moving time, a timed session's duration (C4), or a Duration log.
- Entries with no time (a manual distance or a single set) get an estimate from the distance or
  volume (e.g. distance ÷ a typical pace), marked "estimated".
- Heart-rate zones as % of max HR (220 − age, from the profile's date of birth): Z1 50–60%,
  Z2 60–70%, Z3 70–80%, Z4 80–90%, Z5 90%+.

Why: minutes × intensity is the idea behind Active Zone Minutes and Apple's Training Load, so it's
familiar, and it treats a 30-minute lifting session and a 30-minute jog fairly.

## Alternatives considered

- **Volume-based (weight × reps):** great for strength, meaningless for cardio; would need an
  arbitrary conversion factor.
- **Calories with a different name:** the feedback asked for something other than calories.
- **Heart-rate zone minutes only:** excludes everyone without a Watch.

## Open questions for Jay

1. Daily or weekly target (e.g. 150 points/week, echoing the WHO 150-minute guideline)?
2. Where it shows: Home card, session/run summaries, the widget?
3. Should points feed milestones/badges, or stay a separate stat?
4. Fun framing: compare points to reference units ("enough effort to … 🦕")?

## Data needed

Already stored: tracked moving time, session start/end, Duration logs, heart-rate avg/max (B2 —
avg only, so zone minutes need per-sample zones computed at read time and stored per entry).
New: per-entry zone minutes (optional fields), profile date of birth (exists).
