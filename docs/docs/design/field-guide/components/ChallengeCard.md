# ChallengeCard

The monthly challenge as an "expedition" section: label, title, the app's description, and a ruler.

**Maps to:** `HomeView` `ChallengeCard` (`Challenge`, `UnlockedChallenge`) and `SeasonalCard` (`SeasonalEngine`: Halloween all Oct, Thanksgiving Nov 15 to 30, Winter Holidays in Dec).

**Consumer provides:** month, challenge name, emoji, description, current and target totals, fraction.

**Do**
- Open the section with a 2px `ink` rule so it reads as a new chapter.
- Use the app's emoji as content beside the label; it's the challenge's own art.
- Ruler legend: "3.4 of 41.4 mi" left, percent right.

**Don't**
- Don't restyle for the season (no orange chrome for Halloween). The pack and copy carry the season.

**Tokens:** `ink`, `accent`, `line`, `progress-track`, `title`, `body`, `label`.
