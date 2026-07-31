# FunFitness — Product Action Plan

**Prepared:** July 30, 2026
**Source reviewed:** github.com/jaytjones/FunFitness (v1.0 MVP · SwiftUI + SwiftData · iOS 18+)

---

## Current State Summary

FunFitness is a well-scoped iOS MVP. It logs cumulative distance (miles) and weight lifted (lbs), stores everything on-device with SwiftData, and celebrates 12 milestones (6 distance, 6 weight) across 3 comparison themes (Animals, Cities, Landmarks). The codebase already shows good instincts: idempotent achievement reconciliation, computed (not cached) totals, lightweight migrations, Dynamic Type, reduce-motion support, WCAG-checked accent color, and a privacy manifest.

Its differentiator is clear and worth protecting: **it translates workout effort into absurd, delightful real-world comparisons** ("2 blue whales," "270 giraffes stacked"). Everything in this plan should either harden the foundation or amplify that levity.

Key gaps: no accounts/auth, no backend (data dies with the device), thin profile model, no HealthKit, manual-only logging, only 12 achievements total (a ceiling users can hit in weeks), and no retention loop (streaks, notifications, social).

---

## Part 1 — General Best-Practice Updates (Foundation)

Twelve platform and product fundamentals, roughly in priority order:

1. **User accounts & authentication.** Add Sign in with Apple (lowest-friction, App Store-favored) plus email/password fallback. Store tokens in the Keychain, never in UserDefaults. This is the prerequisite for sync, social, and device migration.

2. **Backend data sync (replace disk-only storage).** Today a lost phone means a lost fitness history — the single biggest trust risk. Two paths:
   - *Fast path:* CloudKit + SwiftData's built-in sync (minimal code, free, private, but Apple-only).
   - *Scalable path:* a lightweight API (e.g., Supabase/Firebase or a small Swift Vapor/Node service) if Android or web are ever on the roadmap.
   Keep offline-first behavior: log locally, sync opportunistically, resolve conflicts by append-only activity log.

3. **More robust profile creation.** Current profile is name/email/age/height/weight/goal. Expand to: date of birth (age auto-derives and stays correct), unit preferences (metric/imperial — the app is currently hard-coded to miles/lbs), preferred activity types, weekly goal targets, gender (optional, for future calorie estimates), and a profile completeness meter. Validate inputs (no 900-lb bodyweight typos) and make every field optional except name.

4. **HealthKit integration (read + write).** Auto-import walks, runs, and strength workouts so users don't have to manually log everything — manual-only logging is the top churn driver for tracker apps. Write logged workouts back to Health so FunFitness plays nicely in the Apple ecosystem. This is already on the V2 roadmap; it should be first in line.

5. **Push notifications & smart reminders.** Local notifications first (no backend needed): streak-at-risk nudges, "you're 0.8 miles from your next milestone" alerts, and weekly recap. Always opt-in, with granular toggles, and capped frequency — fitness apps that nag get deleted.

6. **Data editing, backdating, and export.** Users can currently only delete entries. Add: edit an entry, log with a past date ("I forgot to log Tuesday"), and export all data as CSV/JSON from Settings. Export builds trust and is table stakes under data-portability expectations.

7. **Light mode + full accessibility audit.** The README acknowledges forced dark mode. Ship the planned light theme, complete `accessibilityIdentifier` coverage, audit VoiceOver labels on custom controls (SelectionChip, progress cards, confetti screens), and verify contrast in both modes.

8. **Home Screen widgets & Live Activities.** A small widget showing current streak + progress toward the next silly milestone keeps the app visible daily. A Live Activity during a logged workout session is a natural follow-on once timers/GPS exist.

9. **Privacy-respecting analytics & crash reporting.** You can't prioritize V3 without knowing which themes people pick and where they drop off. Use TelemetryDeck or aggregated App Store Connect analytics rather than invasive SDKs — it matches the app's on-device privacy posture and simplifies the privacy nutrition label.

10. **Localization & internationalization.** Externalize strings now (cheap) even if you only ship English at launch. Unit-system support (km/kg) is the first real localization need and pairs with item 3.

11. **CI/CD and test depth.** The test targets exist; wire them into GitHub Actions (build + unit tests on PR), add snapshot tests for the milestone celebration screens, and use TestFlight for staged rollouts. Protect the ComparisonEngine with exhaustive unit tests — it's the heart of the product.

12. **App Store readiness & monetization groundwork.** Finish the existing checklist (app icon, privacy labels), add an onboarding paywall-free experience, and decide early between a one-time unlock, a "theme pack" IAP model, or fully free — this decision shapes items 2 and 5.

---

## Part 2 — Market-Inspired Features (What Top Trackers Do Right)

Research across current reviews of Strava, Nike Run Club, Fitbit, Hevy, Strong, Habitica, Zombies Run!, and Fito surfaced consistent themes. <cite index="10-1">Gamified fitness apps are excellent at building short-term consistency, but the ones that keep working long-term lean on community and progression rather than punishment — streaks and leaderboards carry users through the first month</cite>, while <cite index="14-1">a 2025 Frontiers in Psychology study found that moderate levels of gamification outperformed both sparse and overloaded systems in promoting physical activity</cite>. Reviewers also consistently reward fast, low-friction logging: <cite index="4-1">apps are judged on how many taps it takes to record a set, since friction between sets is the fastest way to make users abandon an app, and on whether the app instantly shows previous performance</cite>.

Fifteen proposed features, tagged by the app(s) that prove the pattern:

1. **Streaks with protection.** Weekly activity streaks are the most-cited retention mechanic (Strava, NRC, Fito). Critically, copy Fito's "streak shield": <cite index="15-1">users can protect their streak during illness, travel, or other interruptions</cite> — punishing streak loss is the #1 complaint in reviews of streak-based apps.

2. **Weekly & monthly challenges.** <cite index="9-1">Strava hosts monthly and seasonal challenges, such as running a specific distance, and completing them earns digital badges that motivate users to exercise more</cite>. FunFitness can run "Lift a hippo this month" challenges natively in its own voice.

3. **Expanded badge/achievement library.** 12 total achievements is a hard ceiling — an active user exhausts them in a couple of months. NRC ties badges to <cite index="14-1">real milestones: first 5K, longest run, fastest mile, weekly consistency streaks, extended streaks, cumulative volume</cite>. Add repeatable, tiered, and time-based achievements so there's always a next unlock.

4. **Levels / progression tiers.** <cite index="14-1">Nike Run Club uses a tiered level system (Bronze through Hall of Fame) based on recent activity volume</cite>. A lightweight XP/level system gives long-term structure between milestone unlocks.

5. **Shareable achievement graphics.** <cite index="7-1">Strava recently shipped Streaks shareables — sticker designs to share consistency with friends — plus a streak widget for the home screen</cite>. FunFitness's comparisons are inherently more shareable than a pace stat; polished share cards are the app's best free marketing channel.

6. **Friends & social feed (lightweight).** <cite index="4-1">Hevy's social layer — following training partners, sharing workouts, seeing what others are lifting — is the accountability element that keeps many users consistent</cite>. Start small: add friends, see their unlocks, send a "high five."

7. **Leaderboards & clubs.** Segment-style leaderboards and clubs are core to Strava's stickiness. For FunFitness: friendly leaderboards denominated in silly units (see Part 3).

8. **Apple Watch companion app.** Wrist logging and watch-face complications appear in nearly every "why I chose this tracker" review. Even a minimal watch app (quick-log + streak glance) matters.

9. **Fast logging & previous-performance recall.** One-tap repeat of the last activity, recent-activity shortcuts, and Siri Shortcuts ("Hey Siri, log my run"). The bottom-sheet logger is a good start; reduce it to two taps for repeat workouts.

10. **Progress analytics & trends.** Charts of weekly volume, personal records, and calendar heatmaps. <cite index="15-1">Fito offers monthly and yearly calendar reviews and innovative charts like heat-maps</cite>; Hevy/Strong reviews repeatedly praise clear volume-trend charts for spotting plateaus.

11. **GPS activity tracking.** Already roadmapped. <cite index="8-1">Strava's GPS-based tracking across 50+ sport types is the foundation of its 100M+ downloads</cite>. Even basic route capture unlocks map-based comparisons ("you just ran the length of the Vegas Strip — literally").

12. **More activity types.** Distance and weight only excludes yoga, cycling, swimming, HIIT, sports. Add duration-based and rep-based logging so more workouts "count" toward comparisons.

13. **Guided content / audio companions.** <cite index="12-1">NRC's audio-guided runs are the most-recommended feature for beginners</cite>. A budget version: milestone-aware audio cheers during a tracked workout.

14. **Gear tracking.** <cite index="15-1">Fito lets users tag workouts by shoes and equipment to see how many kilometers they've run in a given pair</cite> — a beloved niche feature that fits FunFitness's playful stat-nerd audience.

15. **Wearable & platform integrations.** Beyond HealthKit: accept data from Garmin/Fitbit via Health sync so switchers keep their history flowing in.

---

## Part 3 — Leaning Into the Levity (Uniqueness Amplifiers)

The silly comparison engine is the moat. Competitors have better sensors, bigger social graphs, and more content — none of them will tell you that you've lifted a T-Rex skull. These features make the joke the product:

1. **Live Absurdity Ticker.** Don't wait for milestones — show fractional comparisons everywhere: "You are 43% of a blue whale" on the Home tab, updating with every log. The gap between milestones becomes entertainment instead of dead air.

2. **Theme Packs as content.** Animals, Cities, and Landmarks are just the start. Ship rotating/unlockable packs: **Food** ("you've lifted 14,200 tacos"), **Dinosaurs**, **Movie Props** ("3 DeLoreans"), **Space** ("halfway to the ISS"), **Tiny Things** ("2.1 million paperclips"). Theme packs are also the natural IAP if monetization is desired.

3. **Journey Mode.** Turn cumulative distance into an illustrated virtual trip with a progress map: Austin → San Antonio → Houston (already in the milestone copy!), or fantasy routes ("Walk to Mordor" energy). Each checkpoint gets its own silly landmark fact.

4. **Absurd Units Converter.** A standalone playful tool: type any number and unit, get comparisons back. "How much is 30,000 lbs?" → "1.2 fire trucks, 12 hippos, or one very judgmental T-Rex skull." Screenshot-bait that markets the app even to non-users.

5. **Comparison of the Day.** A daily notification/card with one absurd reframe of the user's own stats: "Fun fact: this week you out-lifted a Smart Car." Keeps notifications delightful instead of naggy (pairs with Part 1, item 5).

6. **Silly Titles & Ranks.** Replace generic levels with earned titles: "Certified Hippo Hoister," "Giraffe Stacker III," "Honorary Wildebeest." Display on profile and share cards; let friends see them.

7. **Illustrated share cards.** Upgrade ShareLink output to designed cards with custom illustrations — the elephant you just "lifted" standing proudly next to your stats. This is the Strava-shareables play, but funnier (Part 2, item 5).

8. **Themed celebrations per milestone.** The confetti moment is great; make it specific. Unlock the elephant milestone → tiny elephants parachute down. Blue whale → the screen briefly floods. (Keep honoring reduce-motion.)

9. **Friend Duels in silly units.** Weekly head-to-head scored in theme units, not miles: "Who lifts more corgis this week?" Losers' consolation screen is gentle and funny. This is the levity-native version of leaderboards (Part 2, item 7).

10. **Collectible Trophy Shelf.** Achievements become collectible illustrated cards (Fito's achievement-card gacha proves the pull-to-collect loop works). A visual shelf/museum of everything you've "lifted" and everywhere you've "walked."

11. **Seasonal & holiday comparisons.** Time-limited units: turkeys in November, pumpkins in October, heart-shaped chocolate boxes in February. Creates recurring reasons to return and seasonal share moments.

12. **Milestone Remix (AI-generated one-liners).** Use an on-device or API-backed model to generate fresh, personalized comparison quips so the 100th unlock is as funny as the first — with a curated fallback list to keep quality high.

13. **The Mascot.** A companion character (à la Fito's bear or Duolingo's owl) who physically reacts to your progress — buried under the weight you logged today, exhausted after your long run. Widget-ready and merch-ready.

14. **"Explain my workout" mode.** After each log, an instant absurd receipt: "Today: 3 miles. That's 810 giraffes, 54 NYC blocks, or 12 Eiffel Towers lying down (they're fine)." Make the post-log screen the funniest screen in the app.

15. **Community-submitted comparisons.** Let users propose units ("my toddler," "a vending machine"); curate the best into a Community theme pack with contributor credits. Cheap content pipeline, strong engagement loop.

---

## Suggested Phasing

**Phase 1 — Foundation (next 1–2 releases):** HealthKit import, streaks + streak shield, expanded achievements, edit/backdate entries, light mode, Live Absurdity Ticker, illustrated share cards, app icon + App Store checklist.

**Phase 2 — Retention (releases 3–4):** Sign in with Apple + CloudKit sync, local notifications / Comparison of the Day, widgets, theme packs #4–5, challenges, progress charts, richer profile + metric units.

**Phase 3 — Social & Scale (releases 5+):** Friends feed, Friend Duels, leaderboards, Apple Watch app, Journey Mode, GPS tracking, seasonal packs, mascot, community comparisons, monetization (theme-pack IAP).

**North star:** every feature should survive the test — *"Does this make someone screenshot the app and send it to a friend?"* The comparisons already do. Build outward from that.

---

## Part 4 — Monetization Strategy

**Model: free core app, paid personality.** The tracker itself — logging, streaks, achievements, HealthKit, sync, and the original three themes (Animals, Cities, Landmarks) — stays free forever. Revenue comes from selling additional comparison theme packs as one-time in-app purchases.

### The offer

| Product | Price | Notes |
|---|---|---|
| Individual theme pack (Food, Dinosaurs, Movie Props, Space, Tiny Things…) | $1.99–2.99 | One-time purchase, StoreKit 2, syncs across devices via the account system (R2.1) |
| Seasonal packs (Holiday, Halloween…) | $1.99 | Time-themed but permanently owned once bought |
| "Everything Bundle" | $9.99 | All current packs; future packs discounted for bundle owners |
| *(Optional, later)* "Superfan" supporter tier | ~$14.99/yr | All current + future packs, early seasonal drops, mascot cosmetics. A superfan tier, never a gate |

### Why this model fits FunFitness

1. **You're selling jokes, not access.** Fitness apps that paywall the user's own data or progress (locked history, capped logging) earn hostile reviews — Fitbit Premium complaints are the canonical example. Theme packs hold nothing hostage; users buy more ways to laugh at their own stats. That's a purchase people feel good about, which protects ratings.

2. **The content pipeline pre-exists the storefront.** Release 2.2 ships two *free* packs specifically to exercise the pack infrastructure, so by Release 3.3 monetization is just a pricing layer on proven plumbing. Community-submitted packs create a low-cost content flywheel — curation effort, not authoring effort.

3. **The cost structure permits it.** CloudKit sync and a light social backend mean FunFitness never carries the recurring server costs that force most fitness apps into subscriptions. No rent owed, no rent charged.

4. **Timing maximizes conversion.** Monetization lands last (R3.3) because users with months of streaks and a shelf of trophies convert far better than day-one users — and asking for money before proving daily value earns "greedy dev" reviews on an app whose brand is generosity.

### What to avoid

- **Ads** — they would poison the screenshot-and-share aesthetic that is the app's growth engine, and fitness ad yields are mediocre anyway.
- **A launch subscription** — the category is saturated with subscription fatigue ("another $9.99/month tracker" is the most common one-star theme in the space), and subscriptions create pressure to gate features that should stay free.
- **Any functional paywall, ever** — the supporter tier, if added, only accelerates access to personality content (Duolingo's cosmetic economy is the reference, not Strava's feature paywall).

---

## Part 5 — Revenue Scenarios

Directional models, not forecasts. All figures are **annual, net of Apple's 15% Small Business Program cut** (applies under $1M/yr revenue), rounded. Key assumption sources: one-time IAP conversion in consumer utility/fitness apps typically runs 2–5% of monthly actives; average paying-user spend assumes most buyers take 1–2 packs and a minority take the bundle.

### Shared assumptions

- **MAU** = monthly active users (retained, not installs)
- **Pack conversion** = % of MAU who ever make a purchase
- **ARPPU** = average revenue per paying user per year (blend of single packs ≈ $2.49, multi-pack buyers, and $9.99 bundles)
- Supporter tier modeled only in the optimistic case (it's an optional later evolution)

### Scenario A — Conservative (indie side-project traction)

| Assumption | Value |
|---|---|
| MAU | 5,000 |
| Conversion | 2% |
| ARPPU | $4.00 |

**Gross:** 100 payers × $4.00 = **$400/yr** → **~$340/yr net**

*Interpretation:* At hobby-scale traction, revenue is beer money. This is fine — the model costs almost nothing to run (no servers to feed), so there is no pressure to compromise the free experience to chase revenue. The real return at this stage is ratings and word of mouth.

### Scenario B — Moderate (featured once, healthy organic growth)

| Assumption | Value |
|---|---|
| MAU | 50,000 |
| Conversion | 3.5% |
| ARPPU | $5.00 |

**Gross:** 1,750 payers × $5.00 = **$8,750/yr** → **~$7,400/yr net**

*Interpretation:* Covers an illustrator retainer for new packs and mascot content — the flywheel becomes self-funding. Seasonal packs matter most here: each drop re-engages lapsed users and creates a fresh purchase moment, effectively raising ARPPU over time.

### Scenario C — Optimistic (viral share-card moment, sustained press)

| Assumption | Value |
|---|---|
| MAU | 250,000 |
| Conversion | 5% |
| ARPPU (packs) | $6.00 |
| Supporter tier take-up | 1% of MAU at $14.99/yr |

**Gross:** (12,500 payers × $6.00) + (2,500 supporters × $14.99) = $75,000 + $37,475 = **~$112,000/yr** → **~$95,000/yr net**

*Interpretation:* At this scale FunFitness supports a full-time developer plus contract illustration. The supporter tier is worth introducing only here — below ~100K MAU its revenue doesn't justify the added product complexity and the risk of muddying the "everything's a fair one-time price" message.

### Sensitivity notes

- **Conversion is the lever that matters most**, and it is driven almost entirely by pack *quality and cadence* — a new pack every 6–8 weeks keeps a purchase moment in front of every cohort. A mediocre pack costs more in trust than it earns in revenue.
- **The share-card loop is the acquisition engine in every scenario.** Each scenario's MAU assumption depends on Part 3's shareability features shipping well; monetization inherits its ceiling from the levity features, not the other way around.
- **Break-even is structurally trivial.** With CloudKit and no ad infrastructure, annual fixed costs are roughly an Apple developer fee plus modest backend hosting once social ships (Scenario B–C: low thousands). Every scenario is profitable; the question is only whether it's beer money or a salary.
- **If Scenario C materializes,** revisit the Small Business Program assumption (the 15% rate ends at $1M/yr) and consider whether community pack contributors should share revenue — a strong loyalty play that also feeds the content pipeline.
