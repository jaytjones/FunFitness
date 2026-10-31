# PackPicker

Underlined text tabs for choosing the content pack: Animals, Cities, Landmarks, Food, Dinosaurs.

**Maps to:** `HomeView` `ThemeSelector` ("Achievement Theme") and `ThemePack` / `ThemePackCatalog`. In copy these are "packs"; the visual skin is never called a theme pack.

**Consumer provides:** the pack list and selection.

**Do**
- Set names in Fraunces 17; the selected one at 800 with a 3px `accent` underline sitting on the 1px `line` rule.
- Let the row scroll horizontally at narrow widths; keep the selected tab in view.
- Switching packs re-captions every plate (binomials appear only for Animals).

**Don't**
- Don't use pills or a segmented control. Underlines are the guide's tab language.

**Tokens:** `ink`, `accent`, `line`, `space-2`, `space-4`.
