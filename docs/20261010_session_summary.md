# FunFitness — Session Summary (2026-09-26 → 2026-10-10)

Covers paid Apple Developer enrollment and the first TestFlight builds, Release 2.3 (achievement
foundation), the pre-3.1 work (CloudKit Production, fact-check), and Release 2.4 (hardening).
**161 unit tests pass; `main` is pushed.**

---

## TestFlight & CloudKit

- Enrolled in the paid program; the team now provisions iCloud, Push, HealthKit, and App Groups.
- Release entitlements use `aps-environment = production`; Debug keeps `development`.
- `ITSAppUsesNonExemptEncryption = NO`, so uploads skip the export-compliance question.
- **Build 2** uploaded (version 1.0): 2.3 plus the first fact-check fixes. Build 1 should be expired
  (old reconcile logic). **Build 3** (2.4: widget, celebrations, cache, Swift 6) is set up and ready to
  archive; app and widget are both `CURRENT_PROJECT_VERSION = 3`.
- **CloudKit schema deployed to Production** with all five record types (`CD_UserProfile`,
  `CD_ActivityLog`, `CD_UnlockedAchievement`, `CD_StreakRecord`, `CD_UnlockedChallenge`).
  - The Development schema was missing `CD_UnlockedChallenge` (record types appear only once a
    record is saved).
  - Added a DEBUG-only `-initCloudKitSchema` launch argument. Its first run failed with "Zone Not
    Found" because the app's real store had stale zone metadata; the helper now uses a throwaway
    store (`b9f23bb`).
- Gotcha: build-setting and Info.plist edits made through Xcode's tooling sometimes don't reach
  `project.pbxproj` on disk, and ⌘S doesn't always save them. Check `git status` after project edits.

## Release 2.3 — achievement foundation

| Commit | Change |
|---|---|
| `c612947` 2.3.1 | `AchievementReconciler`: dedupe badge rows, revoke only after a local delete/edit, never revoke ids from newer builds. Thresholds derived from source units plus a tiny tolerance (75 mi / 15,000 lbs now earn their badges). Removed the per-install v1.2 unit migration that could re-convert synced data. |
| `c592b50` 2.3.2 | Unit-aware milestone titles (`title(pref:)`); no units baked into pack copy; corrected distance comparisons; silly-title rank frozen to the original 38 milestones. |
| `b6565e6` 2.3.3 | `ReferenceUnit` + `bestFit`: the Home ticker restates totals ("6,614 lbs is 2 hippos") with no ceiling. |
| `1334d80` 2.3.4 | Journey-anchor tiers D7–D10 (250 / 500 / 1,000 / 2,190 mi, "Appalachian Trail Complete!"). 42 milestones. |

## Content fact-check

`docs/20261010_fact_check.md` has the full tables and sources. Three research passes covered
distance, weight, duration, and reps copy plus every reference unit:

- Weight copy was the worst: 18 of 55 more than 60% off (e.g. a blue whale's heart at 100,000 lbs).
- Fixes landed in `b21d937` and `28aed6a` (2.4.2): about 56 copy lines, 9 reference-unit corrections,
  and 8 new sourced units that fill the distance gaps.

## Release 2.4 — hardening

| Commit | Change |
|---|---|
| `02836b2` 2.4 | **Widget extension target** (`FunFitnessWidgetsExtension`). The old widget code was never in a target; it now ships, with the App Group and full-bleed gradients. |
| `e3501bd` 2.4.1 | `celebrate()`: one celebration per type per event. **HealthKit imports now celebrate.** Per-type totals cached (was ~120 ms per Home render at 9,000 entries). Milestone nudges once per milestone. Thousands separators in display text. |
| `28aed6a` 2.4.2 | Duration/reps fact-check fixes; reference-unit gaps filled; unused milestone ticker copy removed. |
| `8bdcf10` 2.4.3 | **Swift 6 language mode** for the app and widget, zero warnings. Test targets stay on Swift 5; all suites are `@MainActor`. |

Docs: `docs/README.md` rewritten for 2.4; `docs/20261010_3.1_design_decisions.md` drafts route
storage, Watch sync, Journey Mode data, and the Live Activity.

Lesson from 2.4.1: a test helper returned `ModelContainer(...).mainContext` without holding the
container, which crashed the test process and took down 36 unrelated tests. Keep the container alive
(the `ReconcileFlagTests` suite stores it as a property).

---

## Jay's checklist — physical devices (build 3, over the next week or so)

Build 2 predates 2.4, so test **build 3**. First, upload it:

1. In Xcode, the run destination is already **Any iOS Device (arm64)**. Choose **Product → Archive**.
2. In the Organizer: **Distribute App → App Store Connect → Upload**. No export-compliance question
   should appear.
3. The archive now includes the widget extension. If signing complains about it, open the
   **FunFitnessWidgetsExtension** target → Signing & Capabilities and make sure your team is selected.
4. When build 3 finishes processing, add it to your internal testing group and **expire builds 1 and 2**.

Install build 3 from TestFlight on your iPhone (and a second device on the same Apple ID for sync).
Note anything odd with a screenshot; TestFlight → Send Beta Feedback works.

### Sync (two devices, same Apple ID)
- [ ] Log an activity on device A. It appears on B without relaunching (may take a minute).
- [ ] On A, delete an activity that drops a total below a milestone. The badge disappears on A, then on B.
- [ ] Delete and reinstall the app on B. Totals come back **unchanged** (not inflated) and badges are
      **kept** while sync catches up.
- [ ] With both devices offline (airplane mode), cross the same milestone on each, then reconnect. The
      badge shows once, not twice (Achievements count and Profile "Badges").

### Apple Health
- [ ] Profile → Apple Health: turn on import and allow access.
- [ ] Walking, running, hiking, and cycling workouts from Health appear and count toward distance.
- [ ] If an import crosses a milestone, **one** celebration screen appears (new in 2.4).
- [ ] Manually log a distance close in time and length to a Health workout. It isn't counted twice.
- [ ] Turn on write-back, log a distance in FunFitness, and check it appears in the Health app and
      isn't imported back.

### New in 2.3 / 2.4
- [ ] Home "Right Now…" ticker shows totals as real-world counts for each type you've logged.
- [ ] Switch to metric (Profile): titles, ticker, and cards show km/kg.
- [ ] Log one big backdated entry that crosses several milestones: **one** celebration per type.
- [ ] Add the **FunFitness widget** to the Home Screen (small and medium); it updates after logging.
- [ ] Silly title and badge counts look right.

### Decisions to bring to 3.1 planning
- [ ] First journey: Texas Triangle or Appalachian Trail (design doc §4).
- [ ] Whether GPS tracking works without HealthKit permission (design doc §1).
- [ ] Half/Full Marathon thresholds: keep the official 21.0975 / 42.195 km, or lower to 13.1 / 26.2 mi.
- [ ] External TestFlight testers (requires a one-time Beta App Review).

---

## Next

When device testing on build 3 is clean, plan 3.1 from the design doc. For later uploads, bump
`CURRENT_PROJECT_VERSION` on the app **and** the widget together.
