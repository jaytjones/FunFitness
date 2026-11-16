# FunFitness — Session Summary 2 (2026-11-15): 3.3 "Your Style" code complete, 3.2 (16) for testers

This picks up where `docs/20261115_session_summary.md` (3.2 (14) set up) left off.

- **3.2 "New Look"** is complete. Jay checked contrast and Dynamic Type on device.
- **3.3 "Your Style"** is code complete and unreleased. Arcade and Field Guide are built behind
  the `INTERNAL_STYLES` build flag, so only Jay sees them: in Debug and Internal builds, on the
  owner's iCloud account. Release builds (testers, App Store) contain neither. That's checked
  after every batch by searching the built Release app, by the string catalog check, and by
  `BuildFlagsTests`.
- **Testers' build 3.2 (16)** is archived, uploaded and tagged.

All unit tests pass.

## Builds and tags

| Build | Scheme | Who | Commit / tag |
|---|---|---|---|
| 3.2 (14) | FunFitness Internal | Jay-only group | `80a5654` (tag `3.2-14`) |
| 3.2 (15) | FunFitness Internal | Jay-only group; owner check confirmed in Production ("Owner ✓") | `b634153` (tag `3.2-15`) |
| 3.2 (16) | **FunFitness (Release)** | **all testers**, the first since 3.1 (13) | `d6aa350` (tag `3.2-16`) |

The next upload is **3.2 (17)**. No CloudKit schema change in 14–16.

**3.2 (16) brings testers:** the first build labelled 3.2; FB-0020 (Outdoor/Indoor tracking with
indoor distance from steps, "Save workouts to Apple Health" plus a one-time prompt, calories on
tracked walks/runs, the strength "too short" message, no silent skipped saves); Watch writes
distance and energy; the "Your workouts are only on this iPhone" notice. It also includes the style
plumbing, with no visible change.

## Decisions (Jay)

- **Unreleased styles are Jay-only**, even in TestFlight. They sit behind the `INTERNAL_STYLES`
  flag (Debug and Internal configurations only), with an owner check (hashed iCloud user record
  ID) as a backstop. The earlier "Tester menu for all testers" idea was dropped.
- **Unlock rules:** styles only (comparison packs are unaffected). A streak ladder on the
  longest-ever streak: Arcade at 4 weeks, Field Guide at 8, +4 per later style. Or one
  non-consumable "Unlock all styles" purchase, which also covers styles added later. Playful Bold
  is always free.
- **Fonts:** Playful Bold keeps SF Pro Rounded. Arcade uses Chakra Petch Bold for headings only.
  Field Guide uses system fonts (New York + SF Mono). The other spec fonts were compared in
  mockups and not adopted.
- **Field Guide** is built in 3.3. Arcade (and Field Guide) **stay Jay-only** until Jay launches
  them.
- **Share controls are small icons, never "Share" buttons.** In Arcade they sit top-right on the
  Streak tile, beside the level chip, and in the collected card's sheet (not the grid).
- Arcade's dark mode looked close to After Dark. The tokens are similar by design, and the Arcade
  components carry the identity.
- **3.4 and accounts:** Jay wants to reach non-Apple devices someday. 3.4 should start with an
  optional account plus a cross-platform backend (e.g. email/password with forgot-password, Sign
  in with Apple, later Google), keeping "no account needed" as the default.
- The 5K field test is deferred.

## What was built

**Release 3.3 plumbing (ships in every build, invisible while only Playful Bold exists)**
- The Internal build configuration and "FunFitness Internal" scheme. `INTERNAL_STYLES` is set in
  Debug and Internal only. `BuildFlagsTests` reads the project file and fails if Release ever
  gets the flag.
- `StyleRuntime`: the active style, read by every token at draw time. The app rebuilds its tabs
  when it changes, and widgets and the Live Activity read it from the App Group.
- `StyleID.resolve`: an unknown or unavailable synced style shows as Playful Bold and is never
  overwritten.
- `pick(playfulBold:arcade:fieldGuide:)` for small per-style hooks. Radius, stroke, shadow, type
  and the progress meter all follow the style.

**Behind the flag (Jay-only)**
- **Access** (`StyleAccess`): free, earned, purchased or owner. Uses `StreakRecord`'s
  never-lowered best streak, so deleting old workouts can't re-lock a style.
- **Owner check** (`OwnerCheck`): SHA-256 of the app's CloudKit user record. Debug and Internal
  builds log it and show an "Owner check (internal)" section in Profile.
- **Purchase** (`StylePurchases`, StoreKit 2): entitlement check, purchase, restore, redeem, and
  `Transaction.updates`. Product ID `com.jaytjones.FunFitness.styles.all`.
- **Style picker** in Profile › Style: status per style ("Keep a 4-week streak · N to go"),
  Unlock all styles now, Restore Purchases, Redeem Code.
- **Arcade:** game HUD, dark-first.
  - Home: featured next card with gradient border and glow, level chip, Weight and Streak tiles,
    collection row.
  - Chrome: HOME · STATS · CARDS · YOU tab bar and a square gradient log button.
  - Cards: a trading-card binder with rarity frames.
  - Celebration: card-pack reveal.
  - Everywhere else: 8-segment meters, flat challenge and ticker panels, Stats heatmap, the
    trading-card share image, share icons.
- **Field Guide:** naturalist's guide in Daylight and Lamplight.
  - Guide: masthead, lead plate with a headline from the real comparison and "Fig. NN."
    captions, ruler progress, specimen grid with streak tally, title page, numbered field notes.
  - Chrome: "Log an entry" bar and text tabs under a heavy rule.
  - Collection: specimen catalogue No. 01–42, with the share icon in each specimen's page.
  - Celebration: ink-drawn plate and stamp.
  - Progress: stem chart and stippled heatmap.
  - Share and Live Activity: plate share page; Live Activity on its fixed dark ground.

**Also this session (ships to testers in 3.2 (16))**
- "Your workouts are only on this iPhone": shown when the data isn't backed up (sync off, not
  signed in, or restricted) and something has been logged. Offers Turn On iCloud Sync (sync-off
  case), Export a Copy (CSV) and Not Now (30 days). Home rechecks iCloud on return, and Profile
  shows a one-line note.

**Tooling:** `FunFitness.storekit` is a local StoreKit test file at the repo root (never bundled,
$2.99 placeholder). Debug-only launch arguments for simulator screenshots: `-seedSampleData`,
`-previewStyle <id>`, `-previewOwner YES`, `-previewTab N`, `-previewCelebration <id>`,
`-iCloudSyncEnabled NO`.

**Tests added:** `BuildFlagsTests`, `StyleFallbackTests`, `StyleAccessTests`, `StyleTokenTests`,
`ArcadeRulesTests` (rarity table and totals, segments, levels), `FieldGuideRulesTests`,
`LocalDataNoticeTests`.

## Commits

| Commit | Change |
|---|---|
| `167b6fd` `bc21b36` `59d2af8` | Plan: 3.2 complete; Jay-only flag approach; unlock rules |
| `76364e5` `30c5718` | Internal configuration + flag; unknown-style fallback |
| `284d2ca` `29cb052` `80a5654` `b634153` | Unlock rules, owner check, purchase; owner hash; owner check result row; build 15 |
| `edc856a` `5dd603e` `0b716c7` | Arcade tokens, style picker, Chakra Petch |
| `82428a3` `2481942` `c186346` `5004000` `e1a90fe` `b7a4ff3` `9b49fd0` | Arcade Home, dock, binder, reveal, panels, Stats, share |
| `1e976a1` `620d4b2` `0e422b3` `e7babbe` | Arcade share icons (visible, icon-only, placement) |
| `e41fa9f` | Local-only data notice |
| `e646a81` | Local StoreKit test file |
| `a64d3d1` `db215c8` `fdfa5c2` `38719f2` `36215e5` `2ddce49` `50f817f` | Field Guide FG-1 to FG-7 |
| `72f5cc9` `ce47199` | 3.3 code complete; Field Guide system fonts |
| `d6aa350` `21ce297` `84a16cb` | Build 16; catalog strings from the archive; checklist |

## Jay's next steps

**1. Testers' build:** add 3.2 (16) to the tester groups (keep 14 and 15 in the Jay-only group)
with What to Test notes. After a few days, say "check feedback".

**2. Test purchases locally**
- In Xcode: Edit Scheme › Run › Options › **StoreKit Configuration** › `FunFitness.storekit`.
  Run Debug, open Profile › Style, and try Unlock all styles, Restore and Redeem Code. Debug ›
  StoreKit › Manage Transactions resets or refunds.
- Set StoreKit Configuration back to **None** before archiving.

**3. Create the in-app purchase in App Store Connect**
1. Apps › FunFitness › Monetization › **In-App Purchases** › **+** › **Non-Consumable**.
2. Reference Name "Unlock All Styles". Product ID **`com.jaytjones.FunFitness.styles.all`**
   (must match exactly).
3. Set the price, display name and description ("Unlock every FunFitness style now, including
   styles added later."). Add the review screenshot (the Style picker).
4. Make sure the Paid Apps agreement is active (Agreements, Tax, and Banking).
5. Optional: Offer Codes › a one-time free code for Jay's own App Store install.
6. The product is submitted with the version that launches a style. Until then, test it with an
   **Internal** TestFlight build (sandbox, free).

**4. On device (Debug or Internal):** switch styles in Profile › Style. Check Home, tabs, Cards or
Collection, a celebration, Stats, sharing, widgets and the Live Activity, in both appearances. Not
yet tested on device: the reveal and plate animations, share images in light mode, the lower
halves of Home and Stats.

**5. Launching a style (when Jay decides):** remove its `#if INTERNAL_STYLES`, set `isReleased`,
move its text into the string catalog, include Chakra Petch for Arcade (excluded from Release
today), and submit with the in-app purchase.

## Still open
- 3.4 planning: a backend comparison (Firebase / Supabase / own server) for optional accounts and
  non-Apple devices.
- Field Guide line-drawing plates: emoji until a drawing library exists.
- From earlier: Effort Points could use manual durations; device checks from build 14 (indoor
  walk, Health prompt, calories, Watch walk); the 5K field test (deferred).
