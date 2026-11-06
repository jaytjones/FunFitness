# FunFitness — Release Checklist (TestFlight / App Store)

Keeps the version and build number identical in the repo, the app, the widget extension, and App
Store Connect. Set up 2026-10-17 after Xcode silently uploaded the build-8 archive as build 9.

## How versions are set

- **One place:** `MARKETING_VERSION` (e.g. `3.1`) and `CURRENT_PROJECT_VERSION` (the build, e.g.
  `9`) live in the **project-level** build settings (FunFitness project › Build Settings), and both
  the **FunFitness** app and **FunFitnessWidgetsExtension** inherit them. Don't set them on a target —
  if a target shows a bold (overridden) value, delete the override.
- **Guard:** `FunFitnessTests/BuildNumberTests` fails if the built app and embedded widget disagree.
- Test targets keep their own `1.0 (1)`; they never ship.

## Every upload

1. **Bump the build** (project › Build Settings › Current Project Version) to the next number after
   the latest build in App Store Connect › TestFlight. New version (e.g. 3.2)? Change Marketing
   Version and keep counting builds upward.
2. **CloudKit:** if any `@Model` changed, deploy the schema first (`-initCloudKitSchema` Debug run →
   CloudKit Console › Deploy to Production), then untick the argument.
3. **Tests:** `xcodebuild test -scheme FunFitness -only-testing:FunFitnessTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
4. **Commit and push** the bump (message: `Build N`).
5. **Archive:** Any iOS Device (arm64) › Product › Archive. Organizer should show `3.1 (N)`.
6. **Distribute:** TestFlight & App Store › on the options screen **untick "Manage Version and Build
   Number"** (Xcode otherwise renumbers the upload if the number is taken, and the repo goes out of
   step). With it off, a duplicate number fails the upload with a clear error — bump and re-archive.
7. **Tag** the uploaded commit: `git tag 3.1-N && git push origin 3.1-N`.
8. App Store Connect: confirm `3.1 (N)` is processing, add What to Test, add testers, expire the
   previous build.

## Build history

| Build | Commit / tag | Notes |
|---|---|---|
| 3.1 (9) | `65effb9` (tag `3.1-9`) | Archived as build 8; Xcode renumbered the upload to 9 (code identical). Repo set to 9 afterwards. |
| 3.1 (10) | `5a87f78` (tag `3.1-10`) | TestFlight fixes FB-0001–FB-0004; docs no longer bundled in the app. Uploaded 2026-10-31; build 9 expired. First distribute failed until the updated Program License Agreement was accepted. |
| 3.1 (11) | `382d9fc` (tag `3.1-11`) | C7 Effort Points, C3/C6 exercises, Journey Mode, first Apple Watch app. Archived as build 10; Xcode renumbered the upload to 11 (code identical). Repo set to 11 afterwards. |
| 3.1 (12) | — | Next upload. |
