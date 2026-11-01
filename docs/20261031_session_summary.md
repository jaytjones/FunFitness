# FunFitness — Session Summary (2026-10-31)

A TestFlight feedback tool, a review of all 19 tester submissions, fixes for the four new ones, and
**3.1 (10) uploaded** (tag `3.1-10` → `5a87f78`; build 9 expired). All unit tests pass.

---

## Commits

| Commit | Change |
|---|---|
| `98ff370` | **`scripts/feedback`**: pulls TestFlight screenshot and crash feedback from the App Store Connect API into `docs/feedback/` (stable FB-#### numbers, screenshots, crash logs). Credentials in `~/.appstoreconnect/`. Setup: `scripts/README.md`. |
| `ca1afc9` | **Build fix:** `1c07e66` had added `docs/design/` to the app target, so identically named `.md` files collided in Copy Bundle Resources. All 82 doc files removed from the app's resources (older docs had been shipping inside the app too). |
| `6c7e178` | **FB-0002** crash fix, **FB-0001** live-set sync + delete, **FB-0004** "covered" wording, **FB-0003** pinned now-tracking bar; review doc `docs/20261031_testflight_feedback.md`. |
| `bf93ad1` | Design docs: wording fixes, "Changes since build 9" section; removed duplicate `docs/docs/design/` and the source zip. |
| `5a87f78` | **Build 10** (tag `3.1-10`). |

## TestFlight fixes (details in `docs/20261031_testflight_feedback.md`)

- **FB-0002 crash:** `Color.appBackground` / `appCard` dynamic providers were inferred `@MainActor` (target
  default isolation) and trapped when SwiftUI resolved them on its render thread. Now `nonisolated static let`
  `UIColor`s. Test: `AdaptiveColorTests`.
- **FB-0001:** `StrengthSessionManager.syncWithStore()` rebuilds the live set list from saved logs after every
  History delete / edit / ungroup / remove-from-session; a deleted session record means the next set starts a
  new one. Session screen rows: swipe to delete (iOS 27+, `swipeActionsContainer()`), long-press "Delete Set"
  and a VoiceOver action everywhere. No Undo (Jay). 6 tests.
- **FB-0004:** "You've covered 5 miles!"; medium widget row "Distance"; empty state "Log a walk or run!";
  Siri "Log my walk in FunFitness".
- **FB-0003:** `NowTrackingBar.swift`: a bar on every tab while a walk/run or strength session runs or awaits
  review. iOS 26.1+ uses `tabViewBottomAccessory(isEnabled:)`; earlier iOS uses `safeAreaInset`. Home shows
  the Track / Strength cards only when idle. Checked with previews; 4 tests.

## Decisions (Jay)

- Feedback tool: command line + Markdown report; `docs/feedback/` stays local (gitignored, tester details),
  only the review doc is committed.
- FB-0004 wording "covered"; FB-0003 pinned bar (recommended option); FB-0001 swipe-to-delete, no Undo.
- FB-0015 / D1 (`+` button "bland and nondescript"): postponed to the UI refresh when a design style is picked.
- Design systems: fix factual copy now, record app changes in `docs/design/README.md`, spec NowTrackingBar only
  after a style is chosen; delete the duplicate folder and zip.

## Gotchas learned

- Xcode's test runner kept reporting new tests as "not run" (stale list); `xcodebuild test
  -only-testing:FunFitnessTests` on the iPhone 17 Pro simulator runs them.
- Device-interaction automation needs an **iOS 27 simulator**; only iOS 26.4 is installed, so UI was checked
  with Xcode previews.
- When adding docs to Xcode, **untick the app target**: anything with target membership is copied into the app.
- Distribute failed with "PLA Update available" + "No iOS Distribution certificate" until the Account Holder
  accepted the updated Program License Agreement at developer.apple.com. Re-distributing the same archive worked.

## Jay's checklist — 3.1 (10)

1. **On your phone**, once build 10 installs:
   - Start a strength session, hide it: the bar shows on all four tabs; scroll Home so the tab bar shrinks
     (bar tucks inline); tap the bar to reopen; End → bar disappears, Start card returns. Repeat with a walk.
   - Log 2 sets live, delete one in History → gone from the session screen; swipe a set on the session screen
     to delete it; "Repeat last set" repeats the remaining set.
   - Run a strength session for several minutes, switching light/dark (FB-0002 crash check).
   - A distance milestone reads "You've covered …"; medium widget says "Distance".
2. Run `scripts/feedback` (or ask Claude "check for new TestFlight feedback") after testers have had a day or two.

## Next

- Field-test build 10 and triage new feedback into the review doc.
- **Pick a design style** (Playful Bold / Field Guide / Arcade); that unblocks the `+` button (D1) and the
  NowTrackingBar spec.
- **C7 workout score:** answer the open questions in `docs/20261017_workout_score_design.md`.
- **C3 named exercises** with the bundled-JSON content move (~3.3), then **C6 muscle groups**.
- Rest of 3.1: Apple Watch app, Journey Mode.
- Optional: install an iOS 27 simulator runtime so UI can be verified automatically.
