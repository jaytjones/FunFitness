# FunFitness — App Store Listing (first public release, draft 2026-11-24)

Everything to enter in App Store Connect for the first App Store release, field by field. It describes the
**Release build** (Playful Bold, no Friends, no Arcade / Field Guide, no style purchase): those stay internal
until Jay launches them; add-on text for them is in section 12. Character limits are App Store Connect's.

**Decide first (section 1):** health data in iCloud (App Review 5.1.3), seller name, privacy answers vs the
privacy manifest. Then host the privacy policy and support page (`privacy_policy.md`, `support_page.md`).

---

## 1. Decisions and risks before submitting

### 1a. Health data in iCloud — App Review Guideline 5.1.3(ii) (highest risk)

5.1.3(ii) says apps "may not store personal health information in iCloud." FunFitness syncs its own workout
log through the person's private iCloud (SwiftData + CloudKit), and that log includes some values **read from
Apple Health**: imported walks/runs/hikes/rides, and the average/max **heart rate** of tracked walks and runs.
Reviewers have rejected apps for syncing HealthKit-derived data to iCloud.

Options (Jay to choose before submitting):
1. **Lowest risk:** keep Health-derived health measures off iCloud. Heart rate is the clearest "personal health
   information": stop syncing `avgHeartRate` / `maxHeartRate` (keep them on the device only, or re-read them
   from Health on each device). Imported workouts could also stay device-only, with each device importing from
   Health itself (Health already syncs between the person's devices). Small-to-medium code change.
2. **Submit as is and explain** in the review notes (section 9): iCloud sync is the person's own private
   database, optional (toggle in Profile), and only holds the person's own activity log; nothing goes to the
   developer. May pass; may be rejected and need option 1 anyway.

Recommendation: option 1 for heart rate at least (it's the clearest case) before the first submission.

### 1b. Seller name

The App Store shows the **account holder's name** as the seller. On an Individual account that's "Jay Jones".
To show a company name (for example Discover Health Quest), the account must be an **Organization** (needs a
D-U-N-S number; takes days to weeks). Can be changed later only by migrating the account, so decide now.
Copyright line (section 2) should match.

### 1c. App Privacy answers vs `PrivacyInfo.xcprivacy`

The Release app sends nothing to the developer: no analytics, no accounts, no servers. Workouts, routes,
health data, name, email and photo stay on the device, in Apple Health, or in the person's **private** iCloud,
which the developer can't read. By Apple's definition that's **Data Not Collected** (section 6).

The privacy manifest, though, currently declares Name, Email, Health, Fitness and Photos as *collected* (not
linked, not tracking). Make the two agree: either remove those entries from the manifest (matches "Data Not
Collected"; recommended) or declare the same types in App Privacy. Small change; ask and it's done.

### 1d. Hosting

Privacy policy and support page need public URLs (required: privacy policy URL for every app, and HealthKit
apps must have one). Suggested: `https://discoverhealthquest.com/funfitness/privacy` and
`.../funfitness/support` if that domain is Jay's; otherwise GitHub Pages, Notion or Carrd work.

### 1e. Release scope

Before archiving the App Store build: Release configuration (FunFitness scheme), StoreKit configuration set to
None, `-initCloudKitSchema` / `-initFriendsSchema` unticked, CloudKit Production schema deployed (done), and
**don't** submit the "Unlock All Styles" in-app purchase yet (no style is released, so App Review would find a
purchase with nothing to buy).

---

## 2. App Information (App Store Connect › App Information)

| Field | Value |
|---|---|
| Name (30) | **FunFitness** — or, if taken, **FunFitness: Silly Stats** (24) |
| Subtitle (30) | **Workouts measured in hippos** (27) |
| Bundle ID | com.jaytjones.FunFitness |
| SKU | FUNFITNESS-IOS-001 |
| Primary language | English (U.S.) |
| Primary category | **Health & Fitness** |
| Secondary category | Lifestyle (or Entertainment) |
| Content rights | Does not contain, show or access third-party content: **No third-party content** |
| Age rating | See section 7 (expected **4+**) |
| Copyright | **© 2026 Jay Jones** (or the company name, per 1b) — also set `NSHumanReadableCopyright` in the build |
| License agreement | Apple's standard EULA |

Alternate subtitles: "Turn workouts into giraffes" (28) · "Fitness stats, made ridiculous" (30) ·
"Silly comparisons, real progress" (31: too long).

## 3. Pricing and Availability

- Price: **Free**. No in-app purchases in this release.
- Availability: all countries/regions where English works for Jay (copy is English only). Consider limiting to
  English-speaking storefronts at first.
- Pre-orders: no. Distribution: public. Apple Silicon Mac / Vision Pro availability: **untick** (the app hasn't
  been tested there; iPhone-only UI).

## 4. Version page (iOS App › 3.2 / Prepare for Submission)

### Promotional text (170; can change any time without review)

> Every mile, lift and rep becomes something hilarious: hippos, giraffes, landmarks, dinosaurs. Track
> workouts, keep your streak and collect silly milestones. 🦛

(163 characters)

### Description (4,000)

> **Fitness, measured in hippos.** 🦛
>
> FunFitness turns your workouts into ridiculous real-world comparisons. Lift 6,000 pounds this month? That's
> two hippos. Walk 100 miles? That's nearly four days of camel treks. Every workout counts toward a growing
> collection of silly milestones, and every milestone comes with a celebration you can share.
>
> **TRACK EVERYTHING YOU DO**
> • Track walks and runs with GPS and a route map, or indoors with step-based distance for treadmills
> • Live strength sessions with sets, reps, rest timers and named exercises
> • Log distance, weight lifted, time and reps in seconds, backdate entries and add notes
> • See what you did last time for each exercise, and your best set over time
> • Apple Watch app for quick logging and tracked walks and runs, with complications
> • Live Activity on the Lock Screen while you work out
> • Siri and Shortcuts: "log my run"
>
> **MILESTONES THAT MAKE YOU LAUGH**
> • 42 milestones from your first mile to the whole Appalachian Trail
> • Five comparison packs: Animals, Cities, Landmarks, Food and Dinosaurs
> • Confetti celebrations and share cards for every milestone
> • A "Right now" ticker that restates your totals in hippos, school buses and more
>
> **KEEP THE HABIT GOING**
> • Weekly streaks with streak shields for the weeks life gets in the way
> • Monthly challenges and seasonal comparisons
> • Silly titles that level up as you go
> • Effort Points: one weekly score for any kind of movement
> • Journeys: walk the Texas Triangle or the Appalachian Trail one workout at a time
> • Gentle, optional reminders
>
> **SEE YOUR PROGRESS**
> • Weekly charts, personal records and a 12-week activity heatmap
> • Muscles worked this week, and exercise history
> • Home Screen widgets for your streak and progress
> • Metric or imperial
>
> **YOUR DATA STAYS YOURS**
> • Works with Apple Health: import workouts and save the ones you track (optional)
> • Syncs between your devices with your own iCloud (optional)
> • Export your log any time (CSV or JSON)
> • No ads, no accounts, no tracking. FunFitness doesn't collect your data.
>
> FunFitness is for fun and motivation. It isn't a medical device; calorie and distance figures are estimates.

(≈2,150 characters. If 1a option 1 isn't done, keep the iCloud line as is; it's accurate either way.)

### Keywords (100, comma-separated, no spaces)

> workout,tracker,walking,running,steps,gym,weightlifting,streak,habit,milestones,funny,motivation,log

(99 characters. Don't repeat words already in the name/subtitle: "fitness", "hippos", "workouts".)

### Support URL / Marketing URL

- Support URL (required): `https://<your domain>/funfitness/support` (page text in `support_page.md`)
- Marketing URL (optional): the domain's FunFitness page, or leave blank.

### Version / build

- Version **3.2**, build: the next upload (currently **19**). Upload with the **FunFitness** scheme (Release).
- What's New: not shown for an app's first release.
- Release: **Manually release this version** (so Jay picks launch day), **Phased release: off** for a first
  release (on for later updates).

## 5. Screenshots and previews

Required sizes:

| Device | Size (portrait) | Count |
|---|---|---|
| iPhone 6.9" (iPhone 17 Pro Max) | 1320 × 2868 | 3–10 (upload 6) |
| Apple Watch (Ultra 3 / Series 11) | 422 × 514 (Ultra) or 416 × 496 (Series 46 mm) | 1–10 (upload 3) |

Smaller iPhone sizes are generated from the 6.9" set. No iPad (the app is iPhone-only).

Suggested iPhone set, each with a short caption above the screenshot:

1. Home hero stat — **"Your workouts, in hippos"**
2. Milestone celebration with confetti — **"Hit milestones you'll want to share"**
3. Tracking a walk with the route map — **"Track walks and runs, indoors or out"**
4. Live strength session with "Last time" — **"Lift smarter: see last time's sets"**
5. Progress tab: charts, records, heatmap — **"Watch your progress add up"**
6. Journey or streak card / widget — **"Keep your streak alive"**

Watch set: quick log, tracking a walk, a complication.

Simulator captures with sample data are possible (Debug launch arguments `-seedSampleData -previewTab N`); real
device screenshots look best for tracking and Watch. App Preview video: optional, skip for launch.

## 6. App Privacy (App Store Connect › App Privacy)

- Privacy Policy URL: `https://<your domain>/funfitness/privacy`
- "Do you or your third-party partners collect data from this app?" **No** → label: **Data Not Collected**.
- Reason (for Jay's records): no analytics or SDKs; no developer servers; data stays on device, in Apple Health
  or in the person's private iCloud, which the developer can't access. Apple's crash and TestFlight reports
  are Apple's, not the developer's collection.
- Align `PrivacyInfo.xcprivacy` (section 1c).
- When Friends launches: change to collected **Identifiers › User ID** (see `../20261124_3.4_privacy_and_store_text.md`).

## 7. Age rating questionnaire

Answer **None / No** to every content question (violence, sexual content, profanity, horror, alcohol/tobacco/
drugs, gambling, contests, mature themes, medical treatment information), and:

| Question | Answer |
|---|---|
| Unrestricted web access | No |
| User-generated content / messaging or chat | No (Friends isn't in this release) |
| Advertising | No |
| Parental controls / age assurance | No |
| Health or wellness topics (if asked) | Yes: fitness tracking and activity goals |

Expected rating: **4+**.

## 8. App Review Information

- Sign-in required: **No** (no account).
- Contact: Jay's name, phone and email (App Review only; not shown publicly).
- Attachment: none needed.

## 9. Notes for App Review

> FunFitness needs no account. To see the core feature quickly: tap the + button, log 1 mile (or 1 km) of
> distance and save; a milestone celebration appears. Log a few more entries to see the comparisons, streak
> and Progress charts.
>
> Apple Health is optional. FunFitness reads walking, running, hiking and cycling workouts so they count toward
> totals, reads heart rate during walks and runs the person tracks in the app, and reads body weight to estimate
> strength-session calories. It can save tracked walks, runs and strength sessions to Health. Health data is used
> only to show the person their own progress; it is never shared, sold or used for advertising, and the
> developer never receives it.
>
> iCloud sync is optional (Profile › iCloud Sync) and uses the person's own private CloudKit database, so their
> log appears on their other devices. The developer has no access to it.
>
> Location is used only while the person tracks a walk or run, to measure distance and draw the route. Motion
> (steps) is used for indoor walks.
>
> The Apple Watch app logs activities and tracks walks and runs; it syncs with the iPhone app. Live Activities
> show an in-progress workout on the Lock Screen.

(Adjust the iCloud paragraph to match the decision in 1a.)

## 10. Export compliance

`ITSAppUsesNonExemptEncryption = NO` is already in the build, so App Store Connect won't ask. (The app only
uses Apple's built-in HTTPS/iCloud encryption, which is exempt.)

## 11. Checklist

1. Decide 1a (health data in iCloud), 1b (seller name), 1c (manifest); make any code changes.
2. Set the copyright string in the build; bump to build 19+; archive with the **FunFitness** scheme.
3. Host the privacy policy and support page; paste the URLs.
4. Fill App Information, Pricing, App Privacy, Age Rating (sections 2–3, 6–7).
5. Upload screenshots (section 5), description, keywords, promotional text (section 4).
6. Review information and notes (sections 8–9); select the build; Manual release; Submit for Review.
7. After approval, release when ready; then tag the build and note it in `release_checklist.md`.

## 12. Later: when Arcade / Field Guide or Friends launch

- **Styles + purchase:** add "Unlock All Styles" (non-consumable, `com.jaytjones.FunFitness.styles.all`,
  display name "Unlock All Styles", description "Unlock every FunFitness style now, including styles added
  later.", review screenshot of the Style picker). What's New: "New looks: Arcade and Field Guide. Earn them with
  your streak, or unlock every style at once." Description bullet: "Three styles — Playful Bold, Arcade and Field
  Guide — earned with your streak or unlocked in one purchase."
- **Friends:** description paragraph, What's New, review notes and App Privacy change are drafted in
  `../20261124_3.4_privacy_and_store_text.md`; add the Friends section to the privacy policy.
