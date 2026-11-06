# FunFitness — Sequenced Development Plan

**Prepared:** July 30, 2026 · **Revised:** November 6, 2026 (releases renumbered after 3.1; see "Revision history" at the end)
**Principle:** Every release is a complete, shippable app. No release depends on a future one to be useful, and each one widens the funnel: first make the solo experience excellent, then make it sticky, then make it connected.

---

## Sequencing Logic (read this first)

Three dependency rules drive the entire order below:

1. **Stabilize the schema before you sync it.** The units refactor, richer profile, and expanded achievement model all change SwiftData models. Do every planned schema change *before* CloudKit sync ships (R2.1), because migrating a synced, multi-device schema is 10x harder than migrating a local one.

2. **Build units infrastructure before HealthKit.** HealthKit returns SI units (meters, kilograms). If the app is still hard-coded to miles/lbs when HealthKit lands, you'll bolt on conversion twice. Units first, HealthKit second.

3. **Local retention before remote anything.** Streaks, notifications, and widgets need zero backend and deliver most of the retention value. Accounts and sync only become *necessary* when social features arrive — so they slot in just before, not at the start.

---

## Release 1.1 — "The Polished MVP" (App Store debut)

> **Status: built (July 2026).** App Store debut postponed pending the personal-vs-business name decision; the app is in TestFlight. CI (GitHub Actions) is still open.

**Theme:** Ship what exists, but finished.

**Scope**
- App icon, App Store Connect privacy labels, screenshots, listing copy
- Light mode (remove forced `.preferredColorScheme(.dark)`, audit both themes)
- Edit and backdate activity entries (currently delete-only)
- Expanded achievement library: tiered milestones between the existing 12 (e.g., distance badges at 2.5, 10, 17.5, 35, 75 mi) so the unlock cadence doesn't stall — reuses the existing `ComparisonEngine` and reconciliation, no schema redesign
- **Live Absurdity Ticker** on Home: fractional comparisons ("You are 43% of a blue whale") between milestones
- `accessibilityIdentifier` coverage + basic CI (GitHub Actions: build + unit tests on PR)

**Why it's usable at this stage:** This is the current MVP with its known rough edges sanded off and its ceiling raised. A user can adopt it today as their only tracker and not hit the "I've unlocked everything" wall for months. The ticker makes the core joke visible every single session instead of only at milestones.

**Exit criteria:** Approved on the App Store; both color modes pass a contrast audit; ComparisonEngine has exhaustive unit tests; a user can correct a mistyped entry without deleting history.

---

## Release 1.2 — "Everyone's Invited"

> **Status: built (July 2026).**

**Theme:** Units, profile, and data trust. The invisible release that makes everything later possible.

**Scope**
- **Metric/imperial support end-to-end** — store canonical SI values internally, convert at the display layer; migrate existing miles/lbs data once
- Richer profile: date of birth (derive age), unit preference, optional fields, input validation, weekly goal targets, profile completeness meter
- CSV/JSON export from Settings
- Localization scaffolding: externalize all strings (English-only shipping is fine; the strings files must exist now)

**Why this order:** This is the last big schema churn. It intentionally precedes HealthKit (rule 2) and sync (rule 1). Export ships here because "your data is yours" should be true *before* you ask users for an account later.

**Why it's usable at this stage:** Identical daily experience, but now correct for the ~95% of the world on metric, and users can take their data with them. Nothing here is glamorous; all of it is load-bearing.

**Exit criteria:** A user in kg/km never sees an imperial unit; migration verified against real 1.1 data; export round-trips cleanly; no hard-coded user-facing strings remain.

---

## Release 1.3 — "The Habit Loop"

> **Status: built (July 2026).**

**Theme:** Come back tomorrow. All local, no accounts, no backend.

**Scope**
- **Streak engine** (weekly activity streaks) with **streak shields** for sick/travel days
- Local notifications: streak-at-risk nudge, "0.8 miles from your next milestone," weekly recap — opt-in, granular toggles, frequency-capped
- **Comparison of the Day** notification/card (the levity-native notification)
- **Home Screen widget**: current streak + progress toward next silly milestone
- Silly Titles & Ranks ("Certified Hippo Hoister") derived from existing achievement data

**Why this order:** Streaks must exist before the widget and the at-risk notification can (they display streak state). Titles are nearly free once the expanded achievement library (1.1) exists. None of this needs the network — maximum retention per unit of risk.

**Why it's usable at this stage:** The app now has a reason to be opened daily, not just on workout days. A solo user gets the full modern-tracker retention loop with zero privacy trade-offs — still 100% on-device.

**Exit criteria:** Streak math survives timezone changes and DST; shields work; notifications never fire for opted-out users; widget updates within minutes of a logged activity.

---

## Release 1.4 — "It Logs Itself"

> **Status: built (August 2026).** HealthKit sync is distance-only (Health has no "weight lifted" metric).

**Theme:** Kill manual-entry friction; make sharing gorgeous.

**Scope**
- **HealthKit read integration**: auto-import walks, runs, strength workouts; deduplicate against manual entries; retroactive-import decision surfaced to the user ("count my Health history toward milestones?")
- HealthKit write-back of manually logged workouts
- One-tap repeat of last activity + Siri Shortcut ("log my run")
- **Illustrated share cards** for milestones, streaks, and titles (replaces plain ShareLink output)

**Why this order:** HealthKit lands cleanly because units (1.2) are done, and its imports immediately feed the streaks/notifications machine (1.3) — an import can save a streak, which feels magical. Share cards ship here because by now there's genuinely fun stuff to share (titles, streaks, ticker states).

**Why it's usable at this stage:** This is the "recommend it to a friend" version — the tracker tracks without being asked, and every achievement produces a screenshot-worthy card. **This is also the natural end of the solo-only product; everything after adds connectivity.**

**Exit criteria:** A week of Apple Watch workouts appears with zero manual logging and zero duplicates; share cards render correctly for every theme; permission denial degrades gracefully to manual mode.

---

## Release 2.1 — "Your Data, Everywhere"

> **Status: built (August 2026), changed scope.** iCloud-only sync through SwiftData + CloudKit private database; no Sign in with Apple (moved to 3.4 Social, which needs a real identity), so there is no server account to delete. CloudKit Production schema deployed October 2026. Two-device sync smoke test still open.

**Theme:** Accounts and sync — the bridge release.

**Scope**
- Sign in with Apple (Keychain-stored credentials), optional — the app must remain fully usable signed-out
- CloudKit sync via SwiftData: offline-first, append-only activity log for conflict resolution
- First-sync migration flow for existing local users; account deletion flow (App Store requirement)
- Restore-on-new-device experience

**Why this order:** Every schema change is behind us (rules 1–2 paid off). Sync ships *before* social because social is impossible without identity, but *after* the solo product is complete so signed-out users lose nothing.

**Why it's usable at this stage:** The lost-phone catastrophe is solved. A user upgrades their iPhone and their 18-month giraffe-stacking history walks across automatically.

**Exit criteria:** Two-device sync converges correctly under conflict; signed-out mode has full feature parity minus sync; account deletion verifiably removes server data.

---

## Release 2.2 — "Always Something New"

> **Status: built (September 2026).** Followed by two unplanned hardening releases: **2.3** achievement foundation (reconciler, unit-correct titles, reference units, Journey-anchor tiers) and **2.4** (widget extension target, Swift 6, fact-check, TestFlight feedback fixes).

**Theme:** Content depth and self-competition.

**Scope**
- **Monthly challenges** in FunFitness's own voice ("Lift a Hippo March"), locally evaluated, badge-rewarded
- Progress analytics: weekly volume charts, personal records, calendar heatmap (Swift Charts)
- **Two new theme packs** (Food + Dinosaurs) — pure content, exercising the pack pipeline that Phase 3 monetization will reuse
- Additional activity types: duration-based and rep-based logging so yoga/cycling/HIIT count
- Seasonal comparison variants (first holiday season with turkeys)

**Why this order:** Challenges need the streak/notification plumbing (1.3) to announce themselves and sync (2.1) so progress follows the user across devices. New activity types were deferred until analytics existed to display them meaningfully.

**Why it's usable at this stage:** The app now has a renewable content calendar — a reason each *month* is different — without yet needing any other humans. Retention no longer depends on the user's own novelty-seeking.

**Exit criteria:** A challenge runs end-to-end (announce → track → award → share card); charts render correctly for 2 years of dense data; a rep-based workout flows into totals, streaks, and comparisons.

---

## Release 3.1 — "On Your Wrist, On the Map"

> **Status: in TestFlight (builds 5–11), closing out with build 12.**

**Theme:** Presence during the workout itself.

**Scope**
- **GPS activity tracking** with route capture, works with or without Apple Health ✅
- **Live Activity** during a tracked walk/run and a live strength session ✅
- **Apple Watch companion app**: outdoor walk/run tracking saved to Health, quick log for lifts, bodyweight sets and timed activities ✅ (build 11); GPS routes, a stats glance (streak, weekly Effort Points, totals) and a complication (build 12)
- **Journey Mode v1**: Texas Triangle and Appalachian Trail with a picker, map, and checkpoint facts ✅ (build 11; the checkpoint celebration moves to 3.2 so it's built once, in the new style)
- Added from TestFlight feedback: heart rate from Health, medium widget, workout sessions and sets, session timing and calorie estimates, saving strength workouts to Health, distance surface, named exercises and muscle groups, Effort Points ✅

**Why this order:** GPS and Watch both demand physical field testing — isolating them in one release keeps that testing burden contained. Journey Mode ships alongside GPS because live-tracked distance flowing into a visible journey map is the payoff moment.

**Why it's usable at this stage:** FunFitness graduates from "logbook" to "companion" — present during exercise, not just after. Still fully valuable to a solo user.

**Exit criteria:** A tracked 5K produces an accurate route with acceptable battery cost (iPhone and Watch); watch-logged workouts sync to phone; Journey Mode reflects the run within seconds.

---

## Release 3.2 — "New Look"

**Theme:** One coherent visual identity: **Playful Bold** (`docs/design/playful-bold/`) becomes the app's style, replacing today's look.

**Scope**
- **Style foundation (its own TestFlight build; as built 2026-11-06 it already uses Playful Bold's colours and type, since the old look is retired, but keeps today's layout):** Swift tokens from `tokens.json` (`Shared/Style.swift`); a `Style` environment value; every hard-coded color, gradient and font replaced with tokens; slots for the parts each style restructures (tab bar, log button, Home header, badges, celebration). Called "Style" in code; `activeTheme` stays the comparison pack.
- **Playful Bold:** Sunny (light) is primary, After Dark (dark) the variant. Floating word-only tab bar (Home · Progress · Badges · You); a 64pt log button beside the tab bar with a long-press type menu (closes TestFlight D1); Home leads with one hero stat, other types as flat tiles; card gradients become flat fills with outlines; the pack picker becomes "Compare with"; share cards always render in Sunny.
- Everything that draws UI follows: widgets, Live Activity, the NowTrackingBar (specced in this style), share cards, the Watch app's accent.
- **Journey checkpoint celebration**, built directly in the new style.
- **Style setting stored on the profile** (`UserProfile.activeStyleID`, synced through iCloud), shipped with a single style so every device agrees before 3.3 adds more.

**Why this order:** Every later release adds screens (style picker, social). Restyling first means those are built once. Dropping the old look, rather than keeping it as a fourth style, avoids a fourth variant of every restructured screen and keeps the test matrix at two appearances per style.

**Why it's usable at this stage:** Same features, a clearer and friendlier app — and the bland `+` button (the most-repeated tester complaint about looks) is fixed.

**Exit criteria:** No hard-coded colors or fonts remain outside the token files; both appearances pass a contrast audit and Dynamic Type up to AX sizes; widgets, Live Activity, share cards and Watch match the style; the foundation build shows no visual change.

---

## Release 3.3 — "Your Style"

**Theme:** Choice and reward — styles become something you earn or buy.

**Scope**
- **Arcade** as the second style (structurally closest to Playful Bold, so cheaper to add)
- **Style catalog with unlock rules** — a mix of earned (e.g. a rank or badge count) and purchased; exact rules **TBD (Jay)** before this release starts
- Style picker in Profile with live previews of locked styles
- **StoreKit 2** pulled forward from 3.5 if any style is sold, so purchases and restore are proven before theme packs use them
- **Field Guide** (the structural outlier: ruled sections, rulers, redrawn charts) follows here or with 3.5, if still wanted

**Why this order:** The foundation and the first style (3.2) build the slots every style plugs into; a second style tests that they generalize. Unlocks reuse the theme-pack pattern (`ThemePack.isPremium`); unlock state is derived from badges or App Store entitlements, so nothing new is stored.

**Exit criteria:** Switching styles syncs across devices within seconds; locked styles can't be applied; earned unlocks survive reinstall; purchase/restore works across devices (if any style is sold).

---

## Release 3.4 — "Bring Your Friends"

**Theme:** The social layer, in FunFitness's voice.

**Scope**
- **Sign in with Apple** (deferred from 2.1) for a real identity
- Lightweight backend for social graph (friends, activity visibility) — CloudKit sharing or a small hosted service
- Friends feed: see friends' unlocks, send a "high five"
- **Friend Duels**: weekly head-to-heads scored in silly units ("who lifts more corgis this week?") with gentle, funny consolation screens
- Friendly leaderboards denominated in theme units
- Privacy controls: private-by-default, granular sharing

**Why this order:** Social is deliberately late. It requires identity, benefits from content depth (2.2) and a finished visual identity (3.2–3.3), and is the first feature set with abuse/moderation surface area. By now the solo product is strong enough that social is amplification, not a crutch.

**Why it's usable at this stage:** Users without friends on the app lose nothing; users with friends gain the accountability loop that market research shows carries people past month one.

**Exit criteria:** Duel lifecycle works end-to-end; a friendless user never sees a hollow empty state; blocked users are invisible in both directions.

---

## Release 3.5 — "The Franchise"

**Theme:** Personality and sustainability.

**Scope**
- **The Mascot**: companion character reacting to progress (widget-ready) — budget illustrator time separately
- **Collectible Trophy Shelf**: achievements as illustrated collectible cards
- **Absurd Units Converter**: standalone screenshot-bait tool
- Theme-pack IAP via StoreKit 2 (the 2.2 pack pipeline becomes the storefront); comparison copy moves from Swift to bundled JSON first (the exercise catalog already did in 3.1)
- Community-submitted comparisons with curation/moderation pipeline
- Milestone Remix: generated one-liner comparisons with curated fallback

**Why this order:** Monetization arrives only after the product has proven retention (fair to users, better conversion). Community submissions need the moderation muscle built in 3.4. The mascot lands last because it's the largest pure-design investment and every prior release gives it more states to react to.

**Why it's usable at this stage:** This is the end-state identity: a self-sustaining, personality-rich product with a content flywheel (community packs) and a revenue model that sells *jokes*, not access to your own data.

**Exit criteria:** IAP purchase/restore works across devices; at least one community pack ships through the full submission→curation→release pipeline; mascot states cover the core loop.

---

## Backlog (no release yet)

- C8 weather (WeatherKit) and music context on workouts — parked
- Per-set list in the log sheet, if testers dislike the Sets stepper
- C6 body heat map (needs artwork); Effort Points framed in reference units
- iOS 26 minimum for live iPhone workouts (`HKWorkoutSession`); recovering a run after the app is killed
- GitHub Actions CI; two-device iCloud sync smoke test
- Public App Store launch (personal vs business name), external testers, App Privacy review
- Action-plan ideas: XP levels, gear/shoe tracking, "Explain my workout" receipts

---

## Dependency Map (summary)

```
1.1 Polished MVP ──► 1.2 Units/Profile ──► 1.4 HealthKit ─┐
        │                    │                             │
        └──► 1.3 Streaks/Notifications ◄───────────────────┤
                             │                             │
                             ▼                             ▼
                    2.1 iCloud Sync ──► 2.2 Challenges/Content ──► 2.3/2.4 Hardening
                             │                                          │
                             ▼                                          ▼
                    3.1 Watch + GPS + Journey ──► 3.2 New Look (Playful Bold)
                                                         │
                                                         ▼
                                                  3.3 Your Style (Arcade + unlocks)
                                                         │
                                                         ▼
                                                  3.4 Social/Duels ──► 3.5 Mascot/IAP/Community
```

**The through-line:** at 1.1 it's a finished toy; at 1.4 it's a real tracker; at 2.2 it's a habit; at 3.2 it has a face; at 3.5 it's a brand. A user who stops updating at any release still owns a complete app — and the silly comparisons get louder, not quieter, at every step.

---

## Revision history

- **2026-07-30:** original plan (1.1 → 3.3).
- **2026-11-06 (Jay):** after 3.1, a visual-identity release is inserted. Playful Bold becomes the default style (today's look is retired, not kept as a fourth style); Arcade and Field Guide become unlockable (earned + purchased, rules TBD); the chosen style syncs across devices. Releases renumbered: 3.2 New Look, 3.3 Your Style, 3.4 Social (was 3.2), 3.5 Franchise (was 3.3).
