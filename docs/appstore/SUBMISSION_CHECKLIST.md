# FunFitness — App Store Submission Checklist (next session)

For the first public release, **3.2 (19)**: Playful Bold, no Friends, no Arcade / Field Guide, no in-app
purchase. Field-by-field text is in `20261124_app_store_listing.md` (section numbers below refer to it).


**Status:** 3.2 (19) submitted to App Review on 2026-11-27 (Manual release). Waiting for review.

## Before you start: decisions (only you)

- [x] **Seller name.** Individual account shows "Jay Jones"; an Organization account (D-U-N-S, days to weeks)
      shows a company name. If you switch, update the copyright string (build setting
      `NSHumanReadableCopyright`; I can change it) and section 2. *(Listing 1b)*
- [x] **Support email** to publish on the support page and privacy policy.
- [x] **App name** check: is "FunFitness" available in App Store Connect? Fallback: "FunFitness: Silly Stats".

## 1. Host the two web pages

- [x] Fill the brackets in `privacy_policy.md` (effective date, your name / company, support email).
- [x] Fill the brackets in `support_page.md` (support email, reply time, privacy link).
- [x] Publish both (your domain, or GitHub Pages / Notion / Carrd). Write down the two URLs.

## 2. Finish the screenshots

- [x] Done 2026-11-27 in the simulator: 6 captioned iPhone shots in `screenshots/iphone/`, 3 Watch shots in
      `screenshots/watch/` (order and captions in `screenshots/README.md`). *(Listing 5)*
- [ ] Optional: swap in a real-device Watch complication shot if you'd like one.

## 3. Build and upload 3.2 (19)

- [x] Pull `main`. In Xcode: scheme **FunFitness** (not Internal). Edit Scheme › Run › Options › StoreKit
      Configuration = **None**; Arguments: `-initCloudKitSchema` and `-initFriendsSchema` **unticked**.
- [x] Ask me to bump the build to **19** (or set Current Project Version = 19 at project level).
- [x] Product › Archive. Organizer shows **3.2 (19)**.
- [x] Distribute App › **Custom** › App Store Connect › Upload › **untick "Manage Version and Build Number"** ›
      Upload.
- [x] Tell me it uploaded; I'll tag `3.2-19` and update `release_checklist.md`.
- [ ] Optional: give 19 to testers in TestFlight for a day first (the heart-rate move and the new share icon
      haven't been on a device yet).

## 4. App Store Connect › App Information *(Listing 2)*

- [x] Name, Subtitle "Get fit, one giggle at a time", Primary category **Health & Fitness**, Secondary
      Lifestyle.
- [x] Content rights: no third-party content.
- [x] Age Rating questionnaire: every content question None / No; Health or wellness topics: Yes →
      expect **4+**. *(Listing 7)*

## 5. Pricing and Availability *(Listing 3)*

- [x] Price **Free**. Choose countries/regions.
- [x] **Untick** Apple Silicon Mac and Apple Vision Pro availability.
- [x] **Don't** submit the "Unlock All Styles" in-app purchase yet.

## 6. App Privacy *(Listing 6)*

- [x] Privacy Policy URL = your hosted page.
- [x] "Do you or your third-party partners collect data from this app?" **No** → "Data Not Collected".

## 7. Version page 3.2 *(Listing 4, 8, 9)*

- [x] Promotional text, Description, Keywords (copy from the listing).
- [x] Support URL; Marketing URL optional.
- [x] Upload iPhone (required slot "Dynamic Island (medium display)": `screenshots/iphone-medium/`; optional large slot: `screenshots/iphone/`, 6 each) and Apple Watch (`screenshots/watch/`, 3) screenshots in file order.
- [x] Select build **3.2 (19)** (after it finishes processing; answer export compliance if asked: "None of the
      algorithms mentioned" / exempt; the build already says it uses no non-exempt encryption).
- [x] App Review Information: sign-in **not required**; your name, phone, email; paste the **Notes for App
      Review**.
- [x] Version release: **Manually release this version**.

## 8. Submit

- [x] Add for Review › Submit to App Review. Typical review: 1–2 days.
- [ ] If rejected, paste the message into a session; the most likely topics are HealthKit and iCloud
      (5.1.3), with answers already in the review notes.
- [ ] After approval: Release this version, then tell me so I can record it.

## After launch (later sessions)

- Turn on phased release for future updates; reply to reviews.
- Friends launch: `../20261124_3.4_privacy_and_store_text.md` › Launch checklist (two-device test first).
- Styles launch: create the in-app purchase; remove the `INTERNAL_STYLES` flags; listing section 12.
