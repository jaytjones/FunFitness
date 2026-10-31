# Button

Buttons: primary (ink fill), secondary (ink hairline), disabled (dashed), destructive (danger outline), and a text link.

**Maps to:** `MilestoneView` "Keep Going" / "Share", `ShareCardButton`, `RepeatLastButton`, `SettingsActionRow` destructive actions, `LogActivitySheet` submit.

**Consumer provides:** label, role (primary, secondary, destructive, link), disabled state.

**Do**
- One primary per screen. Primary: `ink` fill, `on-ink` text.
- 48px minimum height; Fraunces 17/700; square (`radius-sm`).
- Focus: 2px solid `focus` ring, 2px offset.
- Destructive buttons say what they delete.

**Don't**
- Don't fill a button with `accent`. Rust is for progress and emphasis in text.
- Don't rely on dashed borders alone for disabled; also lower to `ink-muted`.

**Tokens:** `ink`, `on-ink`, `ink-muted`, `danger`, `focus`, `accent`, `radius-sm`.
