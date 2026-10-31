# SettingsRow

A ruled settings line: label in serif, value in mono, a chevron or switch, hairline under.

**Maps to:** `ProfileView` rows: `EditableProfileRow`, `EditableNumberRow`, `DateOfBirthRow`, `NotificationToggleRow`, `HealthKitSettingsSection`, `CloudSyncSection`, `SettingsActionRow`.

**Consumer provides:** title, optional subtitle, value or control, destructive flag.

**Do**
- 52px minimum row; label `body` in `ink`; value `data` in `ink-muted`.
- Section heads in `label` + `ink-muted`; no grouped-inset boxes.
- Destructive rows in `danger` text; confirm in a system alert with the app's existing wording.
- System switches keep their pill shape (`radius-pill`).

**Don't**
- Don't add coloured icon squares. Text rows only.

**Tokens:** `ink`, `ink-muted`, `line`, `danger`, `on-ink`, `radius-pill`, `body`, `data`, `label`.
