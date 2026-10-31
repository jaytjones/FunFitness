The square gradient "+" that opens the Log sheet.

**Maps to:** The toolbar `plus.circle.fill` in HomeView today; here it moves into the dock beside TabBar and opens `LogActivitySheet`.

**Consumer provides**
- `onTap` opening LogActivitySheet.
- Accessibility label "Log activity".

**Do**
- Use the brand gradient (`gradient-start` → `gradient-mid` → `gradient-end`) built in CSS/SwiftUI from the tokens.
- Draw the glyph in `on-gradient` at 3.2px stroke.

**Don't**
- Don't put text in it.
- Don't reuse the gradient on any other button.

**Tokens:** `gradient-start`, `gradient-mid`, `gradient-end`, `on-gradient`, `radius-md`, `focus`.
