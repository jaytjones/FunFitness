The pill-ish dock of four uppercase tabs (Home · Stats · Cards · You) that sits beside the LogButton.

**Maps to:** ContentView `TabView` (today: Home, Progress, Achievements, Profile). This direction renames the labels to HOME · STATS · CARDS · YOU; the views behind them do not change.

**Consumer provides**
- `tabs`: four labels in order, `selected` index.
- Lay it out in a row with LogButton on the right (`.dock`).

**Do**
- Mark the current tab with `accent` text plus the 2px underline, so it never relies on colour alone.
- Keep labels one word, uppercase, `tab` style.

**Don't**
- Don't add a fifth tab; History stays a sheet.
- Don't fill the selected tab with the gradient. The gradient belongs to LogButton and the featured card border only.

**Tokens:** `surface`, `line`, `ink`, `accent`, `radius-lg`, `tab`.
