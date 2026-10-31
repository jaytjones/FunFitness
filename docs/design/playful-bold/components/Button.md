# Button

Chunky pill buttons with an outline and a hard shadow that "press" into the page.

**Variants**
- **Primary** (`accent` fill): the one action that completes a flow. Log it, Keep Going.
- **Secondary** (`surface` fill): Repeat last, Share, Save to Apple Health.
- **Quiet** (underlined text): See all, Not now.
- **Danger** (`danger` text on surface): Delete Session, Delete All Data. Always confirms in a dialog.

**States:** rest, pressed (translate 4px, `shadow-press`), focused (`focus` ring), disabled (45% opacity, no shadow).

**Rules:** one primary per screen. Labels are verbs that say what happens ("Log it", not "Submit"). Minimum height 52pt.

**Tokens:** `accent`, `on-accent`, `surface`, `line`, `stroke-card`, `shadow-pop`, `shadow-press`, `danger`, `focus`, `headline`.
