Home Screen widgets as HUD readouts: small (weekly streak and title) and medium (challenge % plus Distance and Lift bars with "to next milestone").

**Maps to:** `SmallWidgetView` and `MediumWidgetView` in FunFitnessWidgets.

**Consumer provides**
- `WidgetSnapshot` fields as today.

**Do**
- Use 8-segment bars, small size.
- Follow system appearance: Arcade in dark, Daylight in light.

**Don't**
- Don't put the gradient in widgets.

**Tokens:** `surface`, `streak`, `rank`, `type-distance`, `type-weight`, `progress-track`, `hud`.
