FunFitness Arcade dresses the app as a game HUD with a trading-card collection. Every milestone you can unlock is a card; the next one sits face down on Home with a glowing silhouette and a segmented bar that fills as you log. It is dark-first: **Arcade** is the primary theme and **Daylight** is the light theme.

This direction adds a game framing on top of the same data the app already has. Nothing here needs a new model field, a new engine or a new number. Levels, rarity and the collection count are display rules computed from milestones, unlocks and silly-title tiers that exist today.

No logo yet; set FunFitness in the display face (Chakra Petch, uppercase, bold) with "FITNESS" in `accent`.

## Content fundamentals

- Write from the user's side, second person: "You've covered 5 miles!", "1.6 mi to go".
- Content is playful, chrome is plain. Jokes live in milestone comparisons and silly titles ("That's about 270 blue whales lined up nose to tail!", "Elite Elephant Wrangler"). Labels, buttons and HUD readouts are short and literal: NEXT 03/15, DIST 3.4 / 5.0 MI, KEEP GOING.
- Casing: display and HUD text is uppercase (CSS `text-transform`, so the source strings stay sentence case for VoiceOver). Body copy and comparisons are sentence case.
- Emoji: only where the app already uses them, which is pack art and challenge or season marks (🐳, 🎃). Never decorate chrome with emoji.
- Streaks are weekly. Always "6 weeks · best 9". Never days.
- Visual skins are "themes" (Arcade, Daylight). Content sets are "packs" (Animals, Cities, Landmarks, Food, Dinosaurs). Never call a skin a pack. Pack copy never contains units.
- No calories in the main UI.
- Mark sample screens "Example data".

## Game layer, mapped to real data

The reference mockup invented several game numbers. Each one is replaced with something the app already computes.

| Mockup showed | Problem | Arcade shows | Source |
|---|---|---|---|
| LVL 07 | No level system exists | **LVL 4 · SILVER** | `SillyTitleEngine` tier index |
| +120 XP ON UNLOCK | There is no XP | **+1 BADGE · 4 TO GOLD** | unlocked count vs next tier threshold |
| EPIC tag on the next card | Made up | **COMMON** (D2 is 3rd of 15) | rarity rule below |
| NEXT 03/12 | Wrong total | **NEXT 03/15** | position of D2 in the 15 distance milestones |
| 2× BLUE WHALE | Not real copy | **YOU'VE COVERED 5 MILES!** + "That's about 270 blue whales lined up nose to tail!" | `Milestone.title`, pack comparison |
| COLLECTION · 3/12 | Wrong totals | **COLLECTION · 8/42** | unlocked achievements / 42 |
| 9 days, best: 14 | Streaks are weekly | **6 weeks · best 9**, 1 shield | `StreakEngine` |
| 1,240 lbs · 2.5 lions | Not the ticker's output | **1,240 lbs · 2.6 grizzly bears** | `ReferenceUnit` |

**Level.** Level is the silly-title rank's index in its 8 tiers. Unranked is LVL 0, so: Unranked 0 (0 badges), Starter 1 (1), Iron 2 (2), Bronze 3 (4), Silver 4 (8), Gold 5 (12), Platinum 6 (16), Diamond 7 (20). The sample user has 8 badges: **LVL 4 · SILVER, "Elite Elephant Wrangler", 4 badges to Gold.**

**Rarity.** Rarity is a display rule computed from a milestone's position in its own activity type's ordered list. No schema change. With N milestones in a type: Legendary = round(10% × N) at the top (minimum 1), Epic = round(20% × N) below that (minimum 1), Common = round(40% × N) from the start, Rare = whatever is left in between. Halves round up.

| Type (N) | Common | Rare | Epic | Legendary |
|---|---|---|---|---|
| Distance (15) | D1, D1b, D2, D2b, D3, D3b | D4, D4b, D5, D5b | D6, D7, D8 | D9, D10 |
| Weight (11) | W1, W1b, W2, W2b | W3, W3b, W4, W4b | W5, W5b | W6 |
| Duration (8) | T1, T2, T3 | T4, T5 | T6, T7 | T8 |
| Reps (8) | R1, R2, R3 | R4, R5 | R6, R7 | R8 |

Totals: 16 Common, 12 Rare, 9 Epic, 5 Legendary (42). Rarity means "further along", not "luckier". Every card unlocks the same way: by reaching its threshold.

**Keep it light.** Rarity and levels can read as pressure. Rules: no loss states, nothing ever goes down a level, a broken streak shows "0 weeks" with the best kept and no red or shaming copy, no timers on cards, no "you're falling behind". Rarity is never used to rank people against each other.

## Visual foundations

**Color.** Deep indigo ground (`bg`), raised `surface` panels outlined in `line`, `surface-alt` for inner frames and inputs. `ink` for text, `ink-muted` for HUD labels and secondary lines. `accent` (cyan) is the primary action and selected state; `accent-2` (magenta) is the second highlight and the streak colour. Each activity type owns a hue: distance `type-distance` (cyan), weight `type-weight` (yellow), duration `type-duration` (violet), reps `type-reps` (magenta). Fills of those colours carry `on-type-*` text, which is dark in Arcade and white in Daylight. In Daylight every hue is darkened to hold 4.5:1 as text on `bg`, `surface` and `surface-alt`.

**Rarity frames.** `rarity-common`, `rarity-rare`, `rarity-epic`, `rarity-legendary` are used for card borders and tag fills; tag text is `on-rarity`. Always print the rarity word too.

**The one gradient.** The brand gradient runs `gradient-start` → `gradient-mid` → `gradient-end` (cyan → violet → magenta) at 135°. It is used in exactly two places: the featured card's 2px border and the LogButton fill. Build it from the token stops; never hard-code it.

**Glow.** `glow` is the centre of a radial fade into `surface-alt` behind card art. Never put text on it. In Arcade the featured and revealed cards also take `shadow-neon`; panels stay flat (`shadow-panel` is `none` in Arcade).

**Type.** Chakra Petch for display (`display-hero`, `display`, `title`, `tab`), always uppercase and bold. Rubik for body and big rounded numerals (`headline`, `body`, `body-strong`, `caption`, `numeral`, `numeral-sm`); unit words ride beside numerals at 0.62em ("6 weeks"). JetBrains Mono for HUD readouts (`label`, `hud`, `hud-strong`), uppercase with open tracking. Use tabular figures for numerals.

**Spacing and radius.** 4px base: `space-1` … `space-12`. Screen gutter and panel padding `space-4`; gaps between panels and slots `space-3`; segments `space-1` apart. `radius-sm` (6) for tags, chips in pickers and the level chip, `radius-md` (12) for panels, slots, buttons and inputs, `radius-lg` (18) for the featured card, tab bar, sheets and share card, `radius-pill` for chips and switches only.

**Progress.** Every progress bar is 8 segments: lit = round(progress × 8), clamped to 1–7 until the milestone is reached. Lit segments are the activity's `type-*` colour, unlit are `progress-track`. Always pair with % and "to go".

**Borders and states.** `line` is decorative only. Anything a border has to communicate (empty or locked slot, input outline, unselected chip) uses `line-strong`, which holds 3:1 on every ground. Locked and empty card slots are dashed `line-strong`. Focus is a 2px solid `focus` ring with 2px offset (yellow in Arcade, violet in Daylight), at least 3:1 on every surface. Pressed state: scale 0.97. Disabled: `surface-alt` fill, `ink-muted` text.

**Layout.** Home reads top to bottom: wordmark and level chip, featured next card, Weight and Streak tiles, collection row (four slots, last one dashed), then the existing cards (challenge, ticker, recent activity, pack picker). The dock (TabBar + LogButton) floats at the bottom.

**System surfaces.** Dynamic Island is always black: use `device`, `on-device`, `device-muted`, `device-accent` there regardless of theme.

## Iconography

SF Symbols in the app, drawn at 2pt stroke where outlined, tinted with the activity's `type-*` colour inside a `radius-sm` box. Previews use simple inline SVG stand-ins for `figure.run`, `dumbbell`, `timer` and `arrow.triangle.2.circlepath`; ship SF Symbols. The LogButton "+" is a heavy-stroke plus in `on-gradient`.

## Illustration

Card art is the pack's existing emoji, nothing new to draw. Before unlock the emoji becomes a single-colour silhouette in the activity's colour with a soft glow (`glow` behind it). After unlock it shows in full colour. Locked cards in the binder use a flat `line-strong` silhouette with no glow. No characters, mascots or scenes.

## Motion

- Segments fill left to right, 40ms apart, when a log saves.
- Celebration is a card-pack reveal: the card scales from 0.9 and flips once with a 0.6s spring while rays fade in behind it, plus the existing success haptic.
- Reduce Motion: no flip, rays, confetti or segment stagger. The Celebration shows its finished static frame (card, Keep Going, Share) immediately, matching `MilestoneView`'s current reduce-motion branch.

## Mapping to SwiftUI

Load tokens into an asset catalog colour set per token (Any = Daylight, Dark = Arcade) or a generated `Color` extension. Default the app to dark if you want Arcade first; otherwise follow the system.

```swift
extension Color {
    static let ffBg          = Color("bg")
    static let ffSurface     = Color("surface")
    static let ffInk         = Color("ink")
    static let ffInkMuted    = Color("ink-muted")
    static let ffAccent      = Color("accent")
    static let ffTypeDist    = Color("type-distance")
    static let ffTrack       = Color("progress-track")
    static let ffGradient    = [Color("gradient-start"), Color("gradient-mid"), Color("gradient-end")]
}

enum Rarity { case common, rare, epic, legendary
    // Display rule only: position within the type's ordered milestone list.
    init(index i: Int, count n: Int) {
        let leg = max(1, Int((Double(n) * 0.1).rounded()))
        let epic = max(1, Int((Double(n) * 0.2).rounded()))
        let common = Int((Double(n) * 0.4).rounded())
        if i >= n - leg { self = .legendary }
        else if i >= n - leg - epic { self = .epic }
        else if i < common { self = .common }
        else { self = .rare }
    }
}

struct SegmentBar: View {
    let progress: Double; let tint: Color
    var lit: Int { progress >= 1 ? 8 : min(7, max(progress > 0 ? 1 : 0, Int((progress * 8).rounded()))) }
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(i < lit ? tint : .ffTrack).frame(height: 12)
            }
        }
        .accessibilityElement().accessibilityLabel("\(Int(progress * 100)) percent")
    }
}

// Featured card border: the only gradient.
RoundedRectangle(cornerRadius: 18)
    .strokeBorder(LinearGradient(colors: Color.ffGradient, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
```

Fonts: bundle Chakra Petch, Rubik and JetBrains Mono (all OFL) and register them in Info.plist; use `.font(.custom("ChakraPetch-Bold", size: 34, relativeTo: .largeTitle))` so Dynamic Type still scales.

## Adapting the app

What this direction changes structurally compared with today:

1. **Tabs renamed:** Home, Progress, Achievements, Profile become HOME · STATS · CARDS · YOU. Same four views.
2. **Log button moves** from the Home toolbar `plus.circle.fill` into a square gradient button beside the tab bar, visible on every tab.
3. **Home top rebuilt:** the four gradient `StatCard`s are replaced by one featured next card (next distance milestone), a Weight + Streak tile pair, and a **new collection row** (last few unlocked cards plus one dashed empty slot, tapping through to Cards). Per-type totals for duration and reps move to the Stats tab tracking cards.
4. **Level chip in the header:** `SillyTitleBanner` becomes a "LVL n · RANK" chip on Home with the full RankCard on the You tab.
5. **Achievements becomes a binder:** `AchievementCard` grid becomes trading cards with rarity frames, grouped by type with "Distance · 2 / 15" headers. Locked cards are dashed silhouettes.
6. **Celebration becomes a card reveal** with the same Keep Going and Share actions, haptics and reduce-motion handling.
7. **Share card is the trading card** itself rather than the current share layout.
8. **Gradients removed** from StreakCard, AbsurdityTicker and StatCard; they become flat panels. The brand gradient survives only on the featured card border and the log button.
9. **New display-only logic:** a `Rarity(index:count:)` helper and a tier-index lookup on `SillyTitleEngine`. No Core Data or CloudKit changes.
10. **ThemeSelector heading** becomes "Comparison pack".
