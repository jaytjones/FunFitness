A row in the You tab: icon chip, title, optional subtitle, and a switch, chevron or nothing.

**Maps to:** ProfileView `SettingsActionRow`, `NotificationToggleRow`.

**Consumer provides**
- `icon`, `title`, `subtitle?`, trailing control, `destructive`.

**Do**
- Destructive rows use `danger` for icon and title, with the alert flow as today.

**Don't**
- Don't colour every icon differently; icons use `accent` except destructive.

**Tokens:** `surface`, `surface-alt`, `line`, `accent`, `danger`, `body-strong`, `caption`.
