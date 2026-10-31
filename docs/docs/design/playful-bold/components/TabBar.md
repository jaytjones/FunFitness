# TabBar

The floating pill tab bar that replaces the system TabView bar: four outlined labels with the active one on a yellow pill.

**Maps to:** `ContentView` tabs (Home, Progress, Achievements, Profile). Labels shorten to **Home · Progress · Badges · You** so they fit at the largest standard Dynamic Type size without truncating.

**Consumer provides:** the selected tab. The LogButton sits to its right (separate component) and shares the row.

**Do**
- Keep labels as words, no icons. The words are part of the look.
- Float it 12pt above the home indicator with `space-5` side margins; content scrolls under it.
- At accessibility text sizes, switch to two rows of two or fall back to the system tab bar. Never shrink the type.

**Don't**
- Don't badge tabs with counts. New badges are announced by Celebration, not a red dot.
- Don't put the yellow pill on two tabs.

**Tokens:** `surface`, `line`, `stroke-card`, `brand-yellow` + `on-accent` for the active pill, `headline` type at 16pt.
