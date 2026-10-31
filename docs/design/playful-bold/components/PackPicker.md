# PackPicker

Outlined pill chips for choosing the comparison pack; the chosen one lifts onto a white face with a shadow.

**Maps to:** the "Achievement Theme" `SelectionChip` row on Home and the pack setting in Profile. Rename the section to **Compare with** so it isn't confused with light/dark appearance.

**Consumer provides:** the five packs from `ThemePackCatalog.all` in `sortOrder`, the active id.

**Rules**
- Pack names only, no emoji in the chip. The emoji belong to the comparisons.
- One row that scrolls horizontally on Home; wraps in Profile.
- Switching packs re-renders HeroStat, StatTiles and Ticker immediately.
- Future premium packs (3.3) get a small lock glyph after the name, never a price in the chip.

**Tokens:** `line`, `stroke-card`, `surface`, `shadow-pop`, `radius-pill`, `headline` at 18pt.
