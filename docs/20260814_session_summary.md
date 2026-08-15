# FunFitness — Session Summary (2026-08-14)

## Release 2.1 — "Your Data, Everywhere" ✅ (implementation complete; sync unverified on-device)

Theme: accounts and sync — the bridge release. **Decision:** iCloud-only via SwiftData +
CloudKit **private database**. Sync + restore-on-new-device happen automatically through the
user's iCloud account — **no Sign in with Apple**, no server, and therefore no App Store
server-side account-deletion obligation. Sign in with Apple is deferred to Release 3.2,
where social features need a real identity.

**Status:** Builds clean; **73/73 tests pass on the iPhone 17 simulator** (68 prior + 5 new).
Not yet committed. The App Store publish remains postponed pending a personal-vs-business
name decision, so we target the CloudKit **Development** environment for now.

---

## What shipped

### 1. CloudKit-compatible schema
CloudKit forbids unique constraints / non-optional relationships and requires every stored
attribute to be optional or have a default. Our four `@Model` types have no relationships and
no unique constraints, so the only change was **adding a default value to every non-optional
stored property** in `ActivityLog`, `UserProfile`, `UnlockedAchievement`, and `StreakRecord`.
Additive + lightweight — SwiftData auto-migrates the existing on-disk store; no migration plan.
Initializer signatures are unchanged, so no call sites moved.

### 2. Single ModelContainer factory (`PersistenceController.swift`, new)
Both the app and the Siri intent previously built their own plain, non-synced container. They
now both call `PersistenceController.makeSharedContainer()`, which:
- Builds `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.discoverhealthquest.funfitness"))` when sync is on, or `.none` when the user has opted out.
- Reads a `UserDefaults` opt-out flag (`iCloudSyncEnabled`, default ON). SwiftData can't retarget `cloudKitDatabase` at runtime, so the flag is read at construction; a change applies on next launch (surfaced in the UI).
- Keeps the previous **in-memory fallback** on store-load failure.
- Exposes a DEBUG-only `initializeCloudKitSchemaForDevelopment()` helper (NOT called at launch — it needs iCloud + network and would crash the simulator) for pushing the schema to CloudKit Development before production promotion.

Wired into `FunFitnessApp.swift` and `LogActivityIntent.swift`.

### 3. Capabilities / entitlements
Added to the `FunFitness` target (both release + debug entitlement files):
- `com.apple.developer.icloud-container-identifiers` = `iCloud.com.discoverhealthquest.funfitness`
- `com.apple.developer.icloud-services` = `CloudKit`
- `aps-environment` = `development` (added automatically by the tooling)
- Info.plist `UIBackgroundModes` = `remote-notification` (CloudKit change pushes)

### 4. Sync UI (`CloudSyncManager.swift`, new)
- `CloudSyncManager` (`@MainActor @Observable`): reports iCloud account availability via `CKContainer.accountStatus()` and observes `NSPersistentCloudKitContainer.eventChangedNotification` to expose `syncing / upToDate / error` + last-sync date.
- `CloudSyncSection` (styled like the existing Notification/Health cards) added to `ProfileView`: a **Sync to iCloud** opt-out toggle + an honest status row ("On — last synced …", "Syncing…", or "Sign in to iCloud in Settings…").
- `ProfileView.clearAllData()` now also deletes the `StreakRecord` (previously missed) and the Clear-All copy states the wipe also removes data from iCloud.

### Tests (`PersistenceTests.swift`, new — +5, total 73)
Sync opt-out flag behavior; parameterless model init proving CloudKit-legal defaults; schema
loads into a container; activity insert/fetch round-trip.

---

## Open items / next session
1. **On-device sync verification** (headline exit criterion, can't be unit-tested):
   two devices on the same iCloud account → data converges + restores; Siri-logged entry
   syncs; sign-out / sync-off keeps the app fully usable; Clear-All removes CloudKit data.
   Watch records appear in the CloudKit Console (Development).
2. **Pre-publish (deferred):** promote the CloudKit schema Development → Production, and flip
   `aps-environment` to `production`, when the App Store publish proceeds.
3. Still open from 1.4: on-device HealthKit import verification.

**Next release: 2.2 "Always Something New"** — monthly challenges, analytics/charts, new
theme packs, new activity types, seasonal comparisons. (Started this session — see below.)

---

## Release 2.2 — "Always Something New" (in progress; started 2026-08-14)

Theme: make the app a *renewable* habit — every month feels different — without needing
other humans. Five features: new activity types, analytics, monthly challenges, two theme
packs, seasonal comparison variants.

**Decisions (with user):**
1. New activity types (duration + reps) get the **full milestone + per-pack comparison treatment** (not just streaks/analytics).
2. Introduce a **data-driven ThemePack model now** (packs as data, `isPremium` hook) to prep the 3.3 IAP pack pipeline.
3. Deliver in **small, independently shippable segments** — each builds green and is its own commit — rather than one big pass.

Plan file: `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/plans/funfitness-2.2.md`.
Still in the CloudKit **Development** environment (publish postponed), so schema evolution is
safe; new models just have to stay CloudKit-legal.

### Segment 1 — activity-type descriptor refactor ✅ (commit `dbecf6c`)
Behavior-preserving foundation. Previously ~30 sites branched on `type == .distance ? … : …`,
which would silently misroute any new type into the weight branch.
- **`ActivityKind.swift`** (new): `ActivityType` descriptor — `displayName`, `emoji`, `usesReps`, `hasUnitConversion`, `usesDecimalInput`, `exportName`. `ActivityType` is now `CaseIterable`.
- `effectiveValue` keys off `usesReps`; `ActivityWriter`, `AppViewModel` (`total(for:)`), `ComparisonEngine` (`milestones(for:)`), `ExportManager`, and `ContentView` (uses `ActivityType.allCases`) all route through the descriptor.
- `UnitConverter`: type-dispatched `toSI`/`fromSI`/`displayString`/`inputString`/`displayUnit`/`siUnit`.
- `LogActivitySheet` + `ActivityHistorySheet` display/edit routed through the descriptor (history/edit header now reads "Weight" via the shared `displayName`).
- Tests: new `ActivityKindTests`; serialized `PersistenceTests` (two tests shared the global `UserDefaults` sync flag and raced under parallel execution — a pre-existing latent flake).

### Segment 2 — data-driven ThemePack refactor ✅ (commit `8123f27`)
Behavior-preserving: same three packs, identical copy.
- **`ThemePack.swift`** (new): `ThemePack` value + `ThemePackCatalog` (animals/cities/landmarks). Pack `id`s are stable and match `UserProfile.activeTheme`, so **no migration**. `isPremium` hook reserved for 3.3.
- `ComparisonEngine`: `Milestone` is now theme-agnostic (`id`/`threshold`/`unit`/`title`); the silly per-theme copy moved to a `content[packId][milestoneId]` store, so adding a pack is one content block instead of edits across every milestone. `getEmoji/getComparison/getTicker` now take a `ThemePack`.
- Removed the `Theme` enum; replaced with `ThemePack` across `AppViewModel` (`activePack`), `ContentView` (load/save by id), `MilestoneView`, `ShareCardView`, `AchievementsView`, `HomeView` (`ThemeSelector` iterates the catalog). Removed dead `AchievementPreview.theme`.
- Tests: iterate `ThemePackCatalog.all`; new `everyPackHasContentForEveryMilestone` (asserts entries *exist*, since the getters fall back to non-empty placeholders).

**Status after Segments 1–2:** builds clean; **80/80 tests pass** on the iPhone 17 simulator;
both commits pushed to `main` (`main` == `origin/main`).

### Resume plan — "features before content" order (user's choice)
Segment 3 (new activity types: duration = minutes, reps = count, both reuse `ActivityLog.value`;
add `durationMilestones`/`repsMilestones` + content for the 3 existing packs; 4-way
`LogActivitySheet` picker; Home/Progress show new-type cards when they have data)
→ Segment 5 (monthly challenges: new `UnlockedChallenge` `@Model`, `ChallengeCatalog`,
`reconcileChallenges` mirroring `reconcileAchievements`, Home card)
→ Segment 6 (Swift Charts analytics in the Progress tab: weekly volume, PRs, heatmap)
→ Segment 4 (Food + Dinosaurs packs — content for all 4 types, the big content grind)
→ Segment 7 (seasonal date-gated comparison overlay).

HealthKit import/write-back stays distance-only. New `@Model` types must stay CloudKit-legal
(defaults, no unique constraints).
