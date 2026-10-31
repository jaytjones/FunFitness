# ShareCard

The share image as a single plate page, 360 × 450: masthead, stamp, milestone title, plate with caption, a footer line with the user's title.

**Maps to:** `ShareCardView` `ShareCard` (360 × 450 frame) rendered by `ShareCardRenderer`, offered from `MilestoneView` and `ShareCardButton`.

**Consumer provides:** catalogue number, milestone title, pack figure + comparison + emoji, the user's silly title.

**Do**
- Render in the theme the user is in; the plate sits on `bg` inside the `surface` page so it reads as a tipped-in plate.
- Set the name "FunFitness Field Guide" in the masthead in `label`; no logo exists yet.

**Don't**
- Don't include body weight, calories or location.
- Don't add a QR code or URL.

**Tokens:** `surface`, `bg`, `ink`, `ink-muted`, `accent-2`, `line`, `display`, `caption`, `label`, `data`.
