# FunFitness — iOS Fitness Tracker

**Version 1.0 MVP** · SwiftUI + SwiftData · iOS 18+

Transforms workout metrics into fun, shareable real-world comparisons.

---

## Features

### Data Models (SwiftData — all data stays on device)
- **UserProfile** — name, email, age, height, weight, fitness goal, avatar photo
- **ActivityLog** — distance (miles) and weight (lbs) entries with timestamps
- **UnlockedAchievement** — milestone unlock records

### Core Engine
- **ComparisonEngine** — 12 milestones (6 distance, 6 weight) with 3 themes (Animals, Cities, Landmarks)
- **AppViewModel** — reactive `@Observable` state; totals are computed from the persisted activity log, not cached

### UI — 4 Tabs

#### Home
- Distance and weight stat cards with progress bars
- Theme selector (Animals · Cities · Landmarks)
- Achievement preview showing unlock count
- Floating + button to log activities

#### Progress
- Cumulative stats (total activities, weekly status)
- Distance and weight progress cards with next-milestone tracking
- Motivational message card
- Activity history with swipe-to-delete (toolbar history button)

#### Achievements
- Progress banner (X of 12 unlocked)
- Unlocked achievement cards with themed comparison text
- Locked achievement teasers
- Empty state for first-time users

#### Profile
- Avatar with photo picker (downscaled to 256px before storage)
- Quick stats (workouts, miles, badges)
- Editable personal info: name, email, age, height (in), weight (lbs)
- Fitness goal selector
- Clear Activity Data / Clear All Data

### Additional
- **LogActivitySheet** — bottom sheet for logging distance or weight; keyboard toolbar Done button
- **MilestoneView** — full-screen celebration with confetti, haptics, reduce-motion support, and ShareLink
- **OnboardingView** — first-launch name and goal setup
- **Idempotent achievement reconciliation** — milestones re-checked on every data change, not on a timer
- **SwiftData lightweight migration** — handles schema evolution without data loss

---

## Design System

- Dark-first theme (`#0D0D1A` background) — light mode is a planned fast-follow
- `#A78BFA` accent (WCAG 4.5:1+ on dark backgrounds; replaces original `#5B21B6` which failed at 1.90:1)
- 20pt corner radius on all cards via `.clipShape(.rect(cornerRadius:))`
- SF Symbols for all icons
- Dynamic Type support via `@ScaledMetric` and semantic font styles
- `@Environment(\.accessibilityReduceMotion)` respected for confetti and animations
- `.sensoryFeedback(.success)` haptics on milestone unlock

---

## Project Structure

All Swift source files live flat inside `FunFitness/FunFitness/`:

```
FunFitness/FunFitness/
├── FunFitnessApp.swift           Entry point, ModelContainer init with in-memory fallback
├── ContentView.swift             Tab coordinator, idempotent achievement reconciliation
├── AppViewModel.swift            @Observable state; computed totals
├── ComparisonEngine.swift        Milestones, themes, Milestone struct
├── SharedComponents.swift        Color(hex:), SelectionChip, FlowLayout, FitnessProgressStyle
├── UserProfile.swift             SwiftData @Model
├── ActivityLog.swift             SwiftData @Model
├── UnlockedAchievement.swift     SwiftData @Model
├── HomeView.swift
├── ProgressView.swift            (public struct name: ProgressTabView)
├── AchievementsView.swift
├── ProfileView.swift
├── LogActivitySheet.swift
├── MilestoneView.swift
├── ActivityHistorySheet.swift
├── OnboardingView.swift
└── PrivacyInfo.xcprivacy
```

---

## Requirements

- iOS 18.0+
- Xcode 16+
- Swift 5.0
- SwiftUI + SwiftData (no backend, no HealthKit)

---

## How to Use

1. **First launch** — enter your name and pick a fitness goal
2. **Log activities** — tap + from any tab; a keyboard Done button dismisses the number pad
3. **Track progress** — Home and Progress tabs show cumulative stats
4. **Unlock achievements** — crossing a milestone threshold triggers a full-screen celebration
5. **Browse history** — tap the history button in the Progress tab toolbar; swipe to delete entries
6. **Switch themes** — Animals, Cities, Landmarks toggle on the Home tab
7. **Edit profile** — tap pencil icons on any field; avatar is downscaled automatically

---

## Milestone System

### Distance (cumulative miles logged)

| Miles | Animals | Cities | Landmarks |
|-------|---------|--------|-----------|
| 1 | 270 giraffes stacked | 18 NYC blocks | 4 Eiffel Towers laid flat |
| 5 | 2 blue whales | Central Park loop | Golden Gate Bridge and back |
| 13.1 | Half marathon | Manhattan island length | Las Vegas Strip ×5 |
| 26.2 | Full marathon | Austin to Round Rock | Great Wall at Badaling section |
| 50 | Wildebeest migration | Austin to San Antonio | Appalachian Trail day 3 |
| 100 | Monarch butterfly daily flight | Austin to Houston | English Channel ×4 |

### Weight (cumulative lbs logged)

| Lbs | Animals | Cities | Landmarks |
|-----|---------|--------|-----------|
| 500 | Male lion | Smart Car | Church bell |
| 2,500 | Hippo | Mini Cooper | Statue of Liberty torch |
| 10,000 | Elephant | Transit bus | Liberty Bell |
| 25,000 | T-Rex skull | Fire truck | Berlin Wall section |
| 50,000 | Humpback whale | Semi-truck | Stonehenge section |
| 100,000 | Blue whale heart | Space shuttle engine | Pyramid capstone block |

---

## Before App Store Submission

- [ ] Add app icon
- [ ] Complete App Store Connect privacy nutrition label entries (mirrors `PrivacyInfo.xcprivacy`)
- [ ] Light mode audit (currently forced dark via `.preferredColorScheme(.dark)`)
- [ ] `accessibilityIdentifier` coverage for UI automation tests

### V2 Roadmap
- HealthKit integration
- GPS live tracking
- Sign in with Apple
- Push notifications
- iPad-optimized layouts

---

Built with SwiftUI + SwiftData · Dark theme · iOS 18
