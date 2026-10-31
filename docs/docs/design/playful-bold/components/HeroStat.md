# HeroStat

The big Home card that leads with the joke: one giant count, the reference unit, the real total, and progress to the next milestone.

**Maps to:** the top of `HomeView` (today a `StatCard` for distance plus the separate "Right Now..." ticker). This card merges the two for the primary activity type.

**Consumer provides**
- `type` (distance / weight / duration / reps): sets the tag color and meter fill.
- `fit`: the `ReferenceUnitEngine.bestFit` result. Show `count` (formatted the way `ReferenceFit.phrase` formats it) as `display-hero` and the unit plural as `title`, with "!".
- `total` display string, the next milestone's comparison noun ("270 blue whales"), `progress` 0–1, and the two meter end labels.
- An illustration for the reference unit (see Illustration in the brand book). Without one, show the unit's emoji at 56pt inside a 72pt outlined circle.

**Rules**
- The giant number is always the reference count, never the raw miles. The raw total sits in the sentence under it.
- Sample copy in the preview is example data: 3.4 mi = 2.4 honeybee flights (Animals pack), next milestone 5 mi.
- Count with one decimal under 10, none above, same as `ReferenceFit.phrase`.
- Tap opens the log sheet on this type.

**Don't** show two HeroStats on one screen. Secondary types use StatTile.

**Tokens:** `surface`, `line`, `shadow-pop`, `radius-lg`, `display-hero`, `title`, `body`, `ink-muted`, `type-*`.
