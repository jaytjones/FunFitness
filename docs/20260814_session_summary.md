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
theme packs, new activity types, seasonal comparisons.
