# FunFitness — Session Summary 2 (2026-11-15): 3.3 "Your Style" code complete

Release 3.3 is code complete and unreleased. Arcade and Field Guide are built behind the
`INTERNAL_STYLES` build flag, so only Jay sees them: in Debug and Internal builds, on the owner's
iCloud account. Release builds (testers, App Store) contain neither. That is checked after every
batch by searching the built Release app, by the string catalog check, and by `BuildFlagsTests`.
All unit tests pass.

## What 3.3 contains

**Plumbing (ships in every build, invisible while only Playful Bold exists)**
- `StyleRuntime`: the active Style, read by every token at draw time. The app rebuilds its tabs
  when the Style changes, and widgets and the Live Activity read it from the App Group.
- `StyleID.resolve`: a Style this build doesn't have, or that this person can't use, shows as
  Playful Bold. The synced choice is never overwritten.
- `pick(playfulBold:arcade:fieldGuide:)` for small per-Style hooks in shared views.

**Behind the flag (Jay-only)**
- **Access** (`StyleAccess`): the streak ladder uses the longest-ever streak (`StreakRecord`'s
  high-water mark): Arcade at 4 weeks, Field Guide at 8, +4 per later Style. Alternatively, one
  "Unlock all styles" purchase (StoreKit 2, `StylePurchases`). The owner check (iCloud user record
  hash) gives Jay everything.
- **Style picker** in Profile, with the purchase, Restore and Redeem Code.
- **Arcade:** game HUD, dark-first. Chakra Petch headings (excluded from Release). Home (featured
  next card, level chip, tiles, collection row), dock, trading-card binder, card-pack reveal,
  segment meters, Stats, trading-card share image, share icons (Jay prefers icons).
- **Field Guide:** naturalist's guide in Daylight and Lamplight, with system stand-ins (New York
  serif, SF Mono). Masthead, lead plate with "Fig. NN." captions, ruler progress, specimen grid
  with streak tally, title page, numbered field notes, "Log an entry" bar, text tabs, specimen
  catalogue No. 01–42, ink-drawn plate celebration with stamp, stem chart and stippled heatmap,
  plate share page, Live Activity on its fixed dark ground.

**Also this session (ships to testers)**
- Local-only data notice: "Your workouts are only on this iPhone". It offers Turn On iCloud Sync,
  Export a Copy, and Not Now (30 days).
- `FunFitness.storekit`: a local StoreKit test file (repo root, never bundled).

## Commits (this part of the session)

`e646a81` StoreKit file · `a64d3d1` FG-1 tokens/type/ruler · `db215c8` FG-2 dock · `fdfa5c2` FG-3
Guide · `38719f2` FG-4 Collection · `36215e5` FG-5 celebration · `2ddce49` FG-6 Progress ·
`50f817f` FG-7 share + Live Activity. Earlier: Arcade c1–c7 and share fixes, local-data notice
`e41fa9f`.

## Jay's next steps

**1. Test purchases locally (now)**
- In Xcode: Product › Scheme › Edit Scheme › Run › Options › **StoreKit Configuration** ›
  `FunFitness.storekit`. Then run Debug, open Profile › Style, and try Unlock all styles, Restore,
  and Redeem Code. Debug › StoreKit › Manage Transactions resets or refunds.
- The price in the file is a $2.99 placeholder. Edit it in Xcode if you like.

**2. Create the in-app purchase in App Store Connect**
1. App Store Connect › Apps › FunFitness › Monetization › **In-App Purchases** › **+**.
2. Type **Non-Consumable**. Reference Name "Unlock All Styles". Product ID
   **`com.jaytjones.FunFitness.styles.all`** (must match exactly).
3. Set the price; add the display name "Unlock All Styles" and a description ("Unlock every
   FunFitness style now, including styles added later."). Add the review screenshot when asked
   (the Style picker).
4. Agreements, Tax, and Banking: the Paid Apps agreement must be active for purchases to work.
5. Optional, for your own App Store install later: In-App Purchase › Offer Codes › create a
   one-time free code and redeem it on your account.
6. The product is submitted with the app version that launches a Style. Until then, test it in
   TestFlight with an **Internal** build (sandbox, free) after removing the scheme's StoreKit file.

**3. On device (Internal build from Xcode or the Jay-only TestFlight group)**
- Switch styles in Profile › Style. Check Home, tabs, Cards/Collection, a celebration
  (`-previewCelebration D2` in Debug), Stats, sharing, and widgets in both appearances.
- Field Guide's Live Activity: start a walk and check the Lock Screen panel.

**4. Launching a Style (when you decide)**
Remove its `#if INTERNAL_STYLES`, set `isReleased`, move its text into the string catalog, bundle
or confirm fonts (Arcade's Chakra Petch is currently excluded from Release), and submit with the
in-app purchase.

## Still open
- Testers' build **3.2 (16)** (Release): Health fixes, indoor tracking, calories, the local-data
  notice. Not uploaded yet.
- Field Guide fonts: decided — system fonts (New York + SF Mono); Fraunces/Newsreader/Plex not
  adopted after the mockup.
- Field Guide line-drawing plates: emoji until a drawing library exists (README).
- 3.4 planning: accounts and a backend with non-Apple devices in mind (Jay, 2026-11-15).
