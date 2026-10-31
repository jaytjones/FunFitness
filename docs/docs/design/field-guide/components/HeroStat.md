# HeroStat

The Home plate, shown here in the full Guide screen: a plate label, a one-sentence headline built from the ticker with the comparison set in italic rust, a line-drawn plate of the next milestone, and its ruler.

**Maps to:** `HomeView` top section: `AbsurdityTicker` (headline) and `StatCard` next-milestone row (plate + ruler). The headline uses the lead type's `ReferenceUnit` line ("3.4 mi is 2.4 honeybee flights to the flowers"), rewritten as "3.4 miles is roughly 2.4 honeybee flights."

**Consumer provides:** activity type, total with unit, comparison count + plural unit name, the next milestone's pack figure (art, Latin binomial for Animals, comparison) and progress fraction.

**Do**
- Set the label in `label` + the type colour ("PLATE 01 · DISTANCE"). Plates are numbered 01 Distance, 02 Weight, 03 Duration, 04 Reps.
- Set the sentence in `display-hero`; the comparison phrase in `comparison` (italic) in `accent`.
- Caption the plate in `caption`: "Fig. NN." uses the milestone's specimen number, then the binomial for Animals (Balaenoptera musculus, Ursus arctos, Apis mellifera, Hippopotamus amphibius), else the plain name.
- Use the real milestone copy on the ruler: "5 mi: 270 blue whales".

**Don't**
- Don't invent comparisons. Every number comes from `ReferenceUnit` or `ComparisonEngine`.
- Don't put units in pack copy. Units belong to the chrome ("3.4 mi logged").

**Tokens:** `ink`, `accent`, `type-*`, `surface`, `line`, `display-hero`, `comparison`, `caption`, `label`.
