# ChallengeCard

This month's challenge on a warm orange card with its seasonal illustration.

**Maps to:** the monthly challenge card on `HomeView` (`ChallengeEngine`) and the seasonal "Special" card (`SeasonalEngine`).

**Consumer provides:** challenge title, blurb, target and progress in the user's units, percentage, an illustration per month.

**Rules**
- Card fill is `type-reps` (the warm orange) for every challenge, whatever its activity type. The meter fill uses the challenge's own type color.
- Show progress in the user's units even when the blurb names metric (the blurb's "66.6 km" is part of the joke; the meter says 41.4 mi).
- After the month ends, hide the card until the app refreshes. Never show last month's challenge.
- Completed: swap the meter for "Done! Badge added to your collection." and a Share button.

**Tokens:** `type-reps`, `on-type-reps`, `title` at 24pt, `body`, ProgressMeter.
