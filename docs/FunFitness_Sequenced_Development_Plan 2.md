# FunFitness — Sequenced Development Plan

**Prepared:** July 30, 2026
**Principle:** Every release is a complete, shippable app. No release depends on a future one to be useful, and each one widens the funnel: first make the solo experience excellent, then make it sticky, then make it connected.

---

## Sequencing Logic (read this first)

Three dependency rules drive the entire order below:

1. **Stabilize the schema before you sync it.** The units refactor, richer profile, and expanded achievement model all change SwiftData models. Do every planned schema change *before* CloudKit sync ships (R2.1), because migrating a synced, multi-device schema is 10x harder than migrating a local one.

2. **Build units infrastructure before HealthKit.** HealthKit returns SI units (meters, kilograms). If the app is still hard-coded to miles/lbs when HealthKit lands, you'll bolt on conversion twice. Units first, HealthKit second.

3. **Local retention before remote anything.** Streaks, notifications, and widgets need zero backend and deliver most of the retention value. Accounts and sync only become *necessary* when social features arrive — so they slot in just before, not at the start.

---

## Release 1.1 — "The Polished MVP" (App Store debut)

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

**Theme:** Presence during the workout itself.

**Scope**
- **Apple Watch companion app**: quick-log, streak glance, complication
- **GPS activity tracking** (battery-sane background location) with route capture
- **Journey Mode v1**: cumulative distance rendered as an illustrated virtual trip (Austin → San Antonio → Houston, reusing existing milestone copy) with checkpoint facts
- Live Activity during a tracked workout

**Why this order:** GPS and Watch both demand physical field testing — isolating them in one release keeps that testing burden contained. Journey Mode ships alongside GPS because live-tracked distance flowing into a visible journey map is the payoff moment.

**Why it's usable at this stage:** FunFitness graduates from "logbook" to "companion" — present during exercise, not just after. Still fully valuable to a solo user.

**Exit criteria:** A tracked 5K produces an accurate route with acceptable battery cost; watch-logged workouts sync to phone; Journey Mode reflects the run within seconds.

---

## Release 3.2 — "Bring Your Friends"

**Theme:** The social layer, in FunFitness's voice.

**Scope**
- Lightweight backend for social graph (friends, activity visibility) — CloudKit sharing or a small hosted service
- Friends feed: see friends' unlocks, send a "high five"
- **Friend Duels**: weekly head-to-heads scored in silly units ("who lifts more corgis this week?") with gentle, funny consolation screens
- Friendly leaderboards denominated in theme units
- Privacy controls: private-by-default, granular sharing

**Why this order:** Social is deliberately late. It requires identity (2.1), benefits from content depth (2.2), and is the first feature set with abuse/moderation surface area. By now the solo product is strong enough that social is amplification, not a crutch.

**Why it's usable at this stage:** Users without friends on the app lose nothing; users with friends gain the accountability loop that market research shows carries people past month one.

**Exit criteria:** Duel lifecycle works end-to-end; a friendless user never sees a hollow empty state; blocked users are invisible in both directions.

---

## Release 3.3 — "The Franchise"

**Theme:** Personality and sustainability.

**Scope**
- **The Mascot**: companion character reacting to progress (widget-ready) — budget illustrator time separately
- **Collectible Trophy Shelf**: achievements as illustrated collectible cards
- **Absurd Units Converter**: standalone screenshot-bait tool
- Theme-pack IAP via StoreKit 2 (the 2.2 pack pipeline becomes the storefront)
- Community-submitted comparisons with curation/moderation pipeline
- Milestone Remix: generated one-liner comparisons with curated fallback

**Why this order:** Monetization arrives only after the product has proven retention (fair to users, better conversion). Community submissions need the moderation muscle built in 3.2. The mascot lands last because it's the largest pure-design investment and every prior release gives it more states to react to.

**Why it's usable at this stage:** This is the end-state identity: a self-sustaining, personality-rich product with a content flywheel (community packs) and a revenue model that sells *jokes*, not access to your own data.

**Exit criteria:** IAP purchase/restore works across devices; at least one community pack ships through the full submission→curation→release pipeline; mascot states cover the core loop.

---

## Dependency Map (summary)

```
1.1 Polished MVP ──► 1.2 Units/Profile ──► 1.4 HealthKit ─┐
        │                    │                             │
        └──► 1.3 Streaks/Notifications ◄───────────────────┤
                             │                             │
                             ▼                             ▼
                    2.1 Accounts + Sync ──► 2.2 Challenges/Content
                             │                             │
              ┌──────────────┴──────────────┐              │
              ▼                             ▼              ▼
      3.1 Watch + GPS + Journey     3.2 Social/Duels ──► 3.3 Mascot/IAP/Community
```

**The through-line:** at 1.1 it's a finished toy; at 1.4 it's a real tracker; at 2.2 it's a habit; at 3.3 it's a brand. A user who stops updating at any release still owns a complete app — and the silly comparisons get louder, not quieter, at every step.
