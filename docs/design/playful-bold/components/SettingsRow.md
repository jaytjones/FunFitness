# SettingsRow

Rows for Profile and Settings: title, optional explanation, and a toggle, value or chevron, grouped in one outlined card.

**Maps to:** `ProfileView` sections (Personal Information, Units, Weekly Goals, Notifications, Apple Health, iCloud sync, Export, Delete).

**Rules**
- Group header is a `label` in `ink-muted` above the card.
- Every toggle row gets one line saying what it does. "Streak Check-In" alone isn't enough.
- Toggle on = `accent` with an outlined knob; off = `progress-track`.
- Destructive rows sit last in their group, in `danger`, and open a confirmation that names what is deleted.

**Tokens:** `surface`, `line`, `accent`, `progress-track`, `danger`, `body-strong`, `caption`, `label`.
