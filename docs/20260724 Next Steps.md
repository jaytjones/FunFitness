# FunFitness — Next Steps

Engineering backlog from a full source review (2026-07-24). Covers all 15 Swift files,
`project.pbxproj`, entitlements, and the asset catalog.

**Scope note:** findings are from source reading, not a compiler run. `xcodebuild` failed with
`CoreSimulator is out of date (1051.50.0 vs 1051.55.0)` — restart or update Xcode before trusting
any "it builds" claim. Re-verify each item before acting; line numbers drift.

**Overall:** a coherent, well-scoped MVP. The comparison/milestone concept is strong and
`ComparisonEngine` is cleanly separated. Problems cluster in three places:

1. Derived state is **cached** instead of **computed** → guaranteed drift (already caused "Bug #1").
2. Milestone unlocking is **timing-based** (a 0.1s sleep) → races and silent data loss.
3. **Zero accessibility support** — `grep -c accessibility FunFitness/*.swift` returns `0`.

---

## Suggested sequencing

| Phase | Scope | Est. |
|---|---|---|
| **A — Stabilize** | §1 correctness bugs + §3 contrast fixes | 1–2 days |
| **B — Fix the foundation** | A + §2 architecture. **Recommended stopping point before new features.** | ~1 week |
| **C — Ship-ready** | B + full §3 accessibility, §5 config, app icon, activity history | ~2 weeks |
| **D — Grow** | §6 product features | ongoing |

The current data-flow will keep generating "Bug #N" entries until Phase B lands. Avoid building new
features on top of it.

---

## 1. Correctness bugs — fix first

- [ ] **`ProgressView` shadows `SwiftUI.ProgressView`.**
      [`ProgressView.swift:11`](../FunFitness/ProgressView.swift#L11) declares `struct ProgressView: View`
      in the module, shadowing the stock type everywhere. This is why progress bars are hand-rolled
      with `GeometryReader`. **Rename to `ProgressTabView`.** Unblocks free accessibility via
      `ProgressView(value:)` / `Gauge` (see §3).

- [ ] **ModelContainer is recreated on every access.**
      [`FunFitnessApp.swift:13`](../FunFitness/FunFitnessApp.swift#L13) is a *computed* `var`, so each read
      constructs a new container over the same store file. Scene `body` can evaluate more than once.
      Appears to be a regression from commit `8174363`. Fix:
      ```swift
      private let sharedModelContainer: ModelContainer = { ... }()
      ```
      Also reconsider `fatalError` on failure — a migration error crashes the app with no recovery.
      Prefer falling back to an in-memory container plus a user-visible error state.

- [ ] **Milestone unlocking depends on an arbitrary 0.1s sleep.**
      [`LogActivitySheet.swift:130`](../FunFitness/LogActivitySheet.swift#L130) schedules
      `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)`, then calls `dismiss()` on line 158.
      The closure captures `activities` — the `@Query` array of a view that no longer exists — and
      whether that snapshot includes the new row is undefined. Meanwhile
      [`ContentView.swift:88`](../FunFitness/ContentView.swift#L88) *also* recalculates. Two writers,
      one racing. Same class of bug as "Bug #1" in `BUG_FIXES.md`, patched rather than removed.
      **Proper fix is §2** (computed totals + idempotent reconciliation).

- [ ] **2nd+ milestone celebrations don't animate.**
      [`ContentView.swift:61`](../FunFitness/ContentView.swift#L61) swaps `milestone:` in place inside the
      `fullScreenCover`. SwiftUI preserves view identity, so `@State showContent` stays `true` and
      `.onAppear` never re-fires → no confetti, no entrance animation after the first.
      Fix: `.id(viewModel.pendingMilestones[currentMilestoneIndex].id)`.

- [ ] **Motivational message re-randomizes on every layout pass.**
      [`ProgressView.swift:247`](../FunFitness/ProgressView.swift#L247) calls `messages.randomElement()`
      inside `body`. Visibly flickers while scrolling. Move to `@State`, seeded once.

- [ ] **Home hardcodes the milestone count.**
      [`HomeView.swift:250`](../FunFitness/HomeView.swift#L250) — `"\(unlockedCount) of 12 unlocked"`.
      `AchievementsView` correctly uses `ComparisonEngine.allMilestones.count`. Add a 13th milestone
      and Home lies.

- [ ] **"0.0 mi to go" forever after full completion.**
      `remainingToNextMilestone` returns `(nil, 0)` ([`AppViewModel.swift:63`](../FunFitness/AppViewModel.swift#L63)),
      so the card shows "Complete!" beside "0.0 mi to go". Needs a distinct completed state.

- [ ] **Age is silently destroyed by typing.**
      [`ProfileView.swift:128`](../FunFitness/ProfileView.swift#L128) — `set: { profile?.age = Int($0) }`
      nils on any non-numeric character. No `.keyboardType(.numberPad)`. Line 127 force-unwraps
      `profile!.age!`.

- [ ] **Delete dead code.**
      - [`Item.swift`](../FunFitness/Item.swift) — untouched Xcode template model, not in the schema.
      - `showOnboarding` ([`ContentView.swift:18`](../FunFitness/ContentView.swift#L18)) — written, never read.
      - `UnlockedAchievement.celebrationSeen` ([`UnlockedAchievement.swift:15`](../FunFitness/UnlockedAchievement.swift#L15))
        — never read, never set to `true`.

---

## 2. Architecture — the core structural issue

- [ ] **Stop caching derived state.** `totalDistance`, `totalWeight`, `totalActivities`,
      `isActiveThisWeek`, and `unlockedAchievementIds` in `AppViewModel` are pure functions of
      `[ActivityLog]` / `[UnlockedAchievement]`. Caching them and re-syncing via `.onChange`
      guarantees drift. The drift is already visible:
      [`ProfileView.swift:31`](../FunFitness/ProfileView.swift#L31) re-derives `totalMiles` from its own
      `@Query` rather than trusting `viewModel.totalDistance`.

      ```swift
      @MainActor @Observable final class AppViewModel {
          var activities: [ActivityLog] = []
          var totalDistance: Double {
              activities.lazy.filter { $0.activityType == .distance }.reduce(0) { $0 + $1.value }
          }
      }
      ```
      Alternative: drop totals from the view model entirely and compute where queried.

- [ ] **`.onChange(of: activities.count)` is the wrong trigger.** Only fires when the *count* changes —
      a delete-plus-insert in one tick goes undetected. Falls out naturally once totals are computed.

- [ ] **Add idempotent achievement reconciliation.** Unlocks currently only happen on the write path.
      Kill the app inside the 0.1s window, or clear and re-enter data, and earned achievements stay
      locked with no recovery. Write a pure `reconcileAchievements(totals:context:)`, run it at launch
      *and* after every write. This deletes the race entirely.

- [ ] **`AppViewModel` should be `@MainActor` and `final`.** It's mutated from a dispatch closure and
      drives UI. `SWIFT_APPROACHABLE_CONCURRENCY = YES` is already set; moving to Swift 6 language mode
      (currently `SWIFT_VERSION = 5.0`) would flag this.

- [ ] **Replace `[Theme: String]` dictionaries in `Milestone`.** Two problems in
      [`ComparisonEngine.swift`](../FunFitness/ComparisonEngine.swift): every milestone's `title` repeats
      the *same* string three times (12 milestones × 3 = pure duplication), and dictionary lookup gives
      no compile-time coverage guarantee — a missing key silently degrades to `"🎯"` /
      `"Milestone Reached!"`. Replace with one shared title plus
      `struct ThemeContent { emoji, comparison }` resolved by exhaustive `switch`.

- [ ] **Cheap perf/pattern cleanups.**
      - `allMilestones` is a `static var` that reallocates on every access
        ([`ComparisonEngine.swift:253`](../FunFitness/ComparisonEngine.swift#L253)) — read 3× per
        AchievementsView body. Make it `static let`.
      - `milestone(withId:)` linear-scans that rebuilt array. Add `static let byId: [String: Milestone]`.
      - `unlockedMilestones` ([`AchievementsView.swift:17`](../FunFitness/AchievementsView.swift#L17)) runs
        two `achievements.first {}` scans *inside a sort comparator* → O(n² log n).

      All trivial at n=12, but they're the wrong shape to grow into.

- [ ] **Create real folder structure.** All 15 files sit flat in `FunFitness/`. The README documents a
      `Models/ Engine/ ViewModels/ Views/` layout that doesn't exist. Also extract the cross-cutting
      utilities currently buried in view files:
      - `Color(hex:)` → bottom of [`HomeView.swift:264`](../FunFitness/HomeView.swift#L264)
      - `FlowLayout` → bottom of [`ProfileView.swift:623`](../FunFitness/ProfileView.swift#L623)
        (used by `OnboardingView` too)
      - `GoalChip` / `ThemeChip` are duplicate implementations of the same component — unify.

---

## 3. Accessibility — currently failing

### 3a. Contrast (measured WCAG ratios)

| Element | Foreground | Background | Ratio | Required | |
|---|---|---|---|---|---|
| "Unlocked \<date\>" — [`AchievementsView.swift:236`](../FunFitness/AchievementsView.swift#L236) | `#5B21B6` | `#1A1A2E` | **1.90:1** | 4.5:1 | ✗ severe |
| Tab tint — [`ContentView.swift:58`](../FunFitness/ContentView.swift#L58) · `+` button (all 4 tabs) | `#5B21B6` | `#0D0D1A` | **2.15:1** | 3:1 | ✗ |
| "Not set" placeholder — `ProfileView.swift:370, 419, 518` | `#9CA3AF` @ 50% | `#1A1A2E` | **2.67:1** | 4.5:1 | ✗ |
| Secondary body text | `#9CA3AF` | `#1A1A2E` | 6.72:1 | 4.5:1 | ✓ |

- [ ] `#5B21B6` is unusable as a **foreground** on near-black. It works fine as a *background* (buttons,
      where white sits on top). For text and the tab tint, use a lighter variant — **`#A78BFA`** lands
      near 7:1.
- [ ] Drop the `.opacity(0.5)` on "Not set" — it's displayed content conveying state, not a true
      placeholder, so it must clear 4.5:1.

### 3b. Everything else

- [ ] **Fixed point sizes ignore Dynamic Type** (WCAG 1.4.4). `.font(.system(size: 36))` in `StatCard`,
      `size: 100` (MilestoneView emoji), plus `80`, `60`, `48`, `40`. Use semantic fonts, or
      `@ScaledMetric` where a specific size is required.
- [ ] **Emoji-as-icons read literally.** `Text("🏃")` announces "person running". Mark decorative ones
      `.accessibilityHidden(true)` and move meaning to the parent element.
- [ ] **Progress bars are invisible to VoiceOver** — raw `RoundedRectangle`s, no `accessibilityValue`.
      Switching to `SwiftUI.ProgressView(value:)` or `Gauge` fixes this for free *and* deletes the
      `GeometryReader` boilerplate. Blocked by the rename in §1.
- [ ] **Unlabeled edit buttons.** `pencil.circle.fill` / `checkmark.circle.fill` in all three profile
      rows announce as image names.
- [ ] **Tap targets under 44×44pt.** Those same pencil buttons, and `xmark.circle.fill` at
      [`LogActivitySheet.swift:100`](../FunFitness/LogActivitySheet.swift#L100), are bare images at ~22pt.
      Add `.frame(width: 44, height: 44).contentShape(Rectangle())`.
- [ ] **No Reduce Motion handling.** Confetti and spring animations should check
      `@Environment(\.accessibilityReduceMotion)`.
- [ ] **No `.accessibilityIdentifier`s** — UI tests can't target anything.
- [ ] Group cards with `.accessibilityElement(children: .combine)` so VoiceOver reads a StatCard as one
      unit rather than six fragments.

---

## 4. UI / UX

- [ ] **Keyboard can't be dismissed and covers the submit button.**
      [`LogActivitySheet.swift:51`](../FunFitness/LogActivitySheet.swift#L51) uses `.decimalPad` /
      `.numberPad` — neither has a Return key. With `.presentationDetents([.medium, .large])`, the
      medium detent puts "Log Distance" exactly where the keyboard sits. **This blocks the app's
      primary action.** Add a `ToolbarItemGroup(placement: .keyboard)` Done button and autofocus the
      field with `@FocusState`.

- [ ] **Remove or disable four dead controls that look functional.**
      - "Sign Out" ([`ProfileView.swift:257`](../FunFitness/ProfileView.swift#L257)) — shows a destructive
        confirmation alert, then does nothing. There is no auth in the app at all.
      - "Notifications" / "Privacy & Security" (`ProfileView.swift:216-218`) — chevron rows implying
        navigation, going nowhere.
      - "Share" in [`MilestoneView.swift:78`](../FunFitness/MilestoneView.swift#L78) — empty closure.

- [ ] **No way to view, edit, or delete a single activity.** You can log a workout but never review or
      correct one; the only recourse for a typo is "Clear Activity Data" (nuclear).
      **This is the largest missing feature.**

- [ ] **Light mode is broken.** Every background is a literal hex, so the app is dark-only — but system
      chrome isn't. The segmented `Picker` in `LogActivitySheet` has no color scheme override and
      renders light-on-light for a Light Mode user. Stopgap: `.preferredColorScheme(.dark)` at the root.
      Real fix: asset catalog color sets.

- [ ] **85 hardcoded `Color(hex:)` call sites**, no token layer. Moving `#0D0D1A`, `#1A1A2E`, `#9CA3AF`,
      `#5B21B6` into the asset catalog delivers light mode, increased-contrast variants, and the §3a
      fixes in a single change.

- [ ] **24 uses of deprecated `.cornerRadius()`** (iOS 17+). Replace with `.clipShape(.rect(cornerRadius:))`.

- [ ] **Pointless ternary** at [`ContentView.swift:42`](../FunFitness/ContentView.swift#L42):
      `selectedTab == 1 ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis"` — identical
      branches. The whole manual `.fill` swapping pattern is unnecessary; `TabView` applies the filled
      variant automatically.

- [ ] **Three inconsistent editing models on one screen.** `EditableProfileRow` writes on every
      keystroke; `EditableEmailRow` and `EditableNumberRow` stage into `editValue` and commit on tap.
      Name saves live, Email and Weight need confirmation — identical-looking rows, different behavior,
      plus ~150 lines of near-duplicate code. Unify into one generic row. No cancel affordance either.

- [ ] **`heightFeet` stores inches.** Property named `heightFeet`
      ([`UserProfile.swift:17`](../FunFitness/UserProfile.swift#L17)), UI labels it `unit: "in"`
      ([`ProfileView.swift:151`](../FunFitness/ProfileView.swift#L151)), getter parses by stripping
      non-digits from a `String`. Should be `heightInches: Int?`.

- [ ] **Avatar images stored unbounded and re-decoded constantly.**
      [`ProfileView.swift:46-47`](../FunFitness/ProfileView.swift#L46-L47) calls `UIImage(data:)` inside
      `body` on raw picker output — a 12MP photo is 5–15 MB, decoded every layout pass and stored inline
      in SwiftData. Downscale to ~256pt before saving; add `@Attribute(.externalStorage)`.

- [ ] **Imperial-only, no localization.** All strings are hardcoded literals;
      `String(format: "%.1f %@ to go", ...)` ignores locale decimal separators.
      `Measurement<UnitLength>` + a String Catalog handles both.

- [ ] **Confetti never stops.** `TimelineView(.animation)`
      ([`MilestoneView.swift:115`](../FunFitness/MilestoneView.swift#L115)) redraws at display refresh rate
      indefinitely, still iterating 60 particles long after they've expired. Gate on whether any
      particle is alive.

- [ ] **No haptics.** A confetti celebration without `.sensoryFeedback(.success, trigger:)` is a cheap
      win left on the table.

- [ ] **iPad and landscape enabled but unhandled.** `TARGETED_DEVICE_FAMILY = "1,2"` with landscape
      orientations in the Info.plist keys, but fixed 80pt avatars and portrait-tuned VStacks. Either
      restrict to iPhone portrait for V1 or add adaptive layout.

---

## 5. Build config & project hygiene

- [ ] **Two conflicting `DEVELOPMENT_TEAM` values** in `project.pbxproj`: `2XT4CUP82M` and `H5QYL4ZQ73`.
      Will cause signing failures depending on configuration.

- [ ] **Entitlements will fail App Store validation.**
      [`FunFitness.entitlements`](../FunFitness/FunFitness.entitlements) declares the CloudKit service with
      an **empty** `com.apple.developer.icloud-container-identifiers` array, plus
      `aps-environment: development`. Neither is used — no `cloudKitDatabase` in the
      `ModelConfiguration`, no push registration anywhere. Remove both, or wire CloudKit up properly
      (good V2 feature — see §6).

- [ ] **No app icon.** `FunFitness/Assets.xcassets/AppIcon.appiconset/` contains only `Contents.json`,
      zero PNGs. Hard App Store blocker. `AccentColor.colorset` is also empty.

- [ ] **Mismatched deployment targets:** `IPHONEOS_DEPLOYMENT_TARGET` is `26.0` in some configs, `26.4`
      in others. Also worth a deliberate decision — iOS 26.0 minimum is a very narrow install base for a V1.

- [ ] **`SWIFT_VERSION = 5.0`** on a brand-new project. Swift 6 language mode would catch the
      `@MainActor` issue in §2.

- [ ] **Zero real tests.** `FunFitnessTests.swift` and both UI test files are untouched templates.
      `ComparisonEngine` is pure and deterministic — start there:
      - exact-threshold boundaries (1.0 mi, 13.1, 26.2)
      - crossing multiple thresholds in a single log
      - re-logging after "Clear Activity Data"
      - `progressToNextMilestone` at 0, mid-range, and past the final milestone
      - `nextMilestone` returning `nil` past 100 mi / 100,000 lbs

      Note: `progressToNextMilestone` ([`AppViewModel.swift:76`](../FunFitness/AppViewModel.swift#L76))
      assumes the milestone arrays are sorted ascending. True today by hand, not enforced — sort or assert.

- [ ] **Five changelog docs inside the app target folder.** `BUG_FIXES.md`, `ACCESSIBILITY_FIX.md`,
      `EMAIL_VALIDATION.md`, `PROFILE_UPDATES.md`, `README.md` sit next to source. Move to `/docs`.

- [ ] **README is factually wrong in four places** — fix or delete:
      - claims iOS 17.0+ (project says 26.0)
      - "Theme Persistence syncs with UserDefaults" (it uses SwiftData)
      - documents a folder structure that doesn't exist
      - "App Store Ready" (no icon, dead controls, broken entitlements)

- [ ] **Data minimization.** Onboarding collects name + goal; Profile then asks for email, age, height,
      and weight — none used for anything. Either use them (BMI, pace targets, personalized milestones)
      or drop them. If kept, a `PrivacyInfo.xcprivacy` manifest declaring collected data types is
      required for App Store submission.

---

## 6. Product features (after Phase B)

Ordered by leverage given what already exists:

1. **Activity history + edit/delete** — biggest functional gap; see §4.
2. **HealthKit read** — auto-import workouts, removing manual logging friction entirely. The app's
   natural moat.
3. **CloudKit sync** — entitlements are already half-declared;
   `ModelConfiguration(cloudKitDatabase:)` is close to a one-liner once the container ID is real.
   Requires fixing §5 first.
4. **Share cards** — the comparison text is inherently shareable and is the organic growth channel.
   The button already exists (currently dead).
5. **More milestone density** — 12 is thin. Users hit 100 miles and run out of app.

---

## Quick reference — highest-impact five

If a session has limited time, do these:

1. `ProgressView` → `ProgressTabView` (§1) — unblocks accessible progress bars everywhere
2. `sharedModelContainer` computed `var` → stored `let` (§1) — data-integrity risk
3. Delete the 0.1s `asyncAfter`; computed totals + reconciliation (§1, §2) — root cause of the bug class
4. `#5B21B6` → `#A78BFA` for all foreground uses (§3a) — 1.90:1 is unreadable
5. Keyboard Done button in `LogActivitySheet` (§4) — blocks the primary action
