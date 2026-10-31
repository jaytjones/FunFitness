Playful Bold makes FunFitness feel like a sticker sheet: a sunny yellow ground, white cards cut out with thick ink outlines and hard offset shadows, chunky rounded type, and one giant number that is always the joke. Use it when the comparison should be the loudest thing on the screen.

This is one of three competing directions (with Field Guide and Arcade). All three use the same token names, so components written against `--surface`, `--ink`, `--type-weight` and friends keep working if the app ever offers a second skin.

## Content fundamentals

The app is funny; the chrome is plain. Jokes live in the comparisons, titles and challenge names, which already exist in the code. Labels, buttons and settings say exactly what they do.

- **Lead with the comparison, not the measurement.** The giant number is the reference count ("2.4"), the unit is the punchline ("honeybee flights to the flowers!"), and the real total sits underneath ("3.4 mi logged. Next stop: 270 blue whales.").
- **Use the engine's words.** Comparison sentences come from `ComparisonEngine` exactly as written ("That's the weight of a mama hippo!"). Ticker lines come from `absurdityTickerText(for:)` ("1,240 lbs is 2.6 grizzly bears 🐻"). Never paraphrase them in UI.
- **Address the person as "you".** Share cards switch to first person ("I lifted 1,000 lbs.").
- **Title case for card titles and screen titles** ("Recent Activity", "Weekly Volume"), sentence case for everything else, ALL CAPS only in `label` tags.
- **Exclamation marks belong to milestones and comparisons**, not to buttons or settings. "Log it", not "Log it!".
- **Streaks are weeks.** "6 weeks", never days.
- **Calories stay quiet.** They appear only in session detail and Apple Health, never on Home, rows or widgets.
- **Emoji** appear where the app already puts them: at the end of ticker lines, as pack art on badges, in Live Activity comparison lines. Never in buttons, tabs, labels or section headers.
- **Gentle on misses.** A broken streak says "Start a new streak this week". No red, no sad faces.

Real lines to model on: "Log your first activity to unlock achievements!", "A streak shield protects your streak for one missed week.", "Rack up a spooky 66.6 km before the pumpkins rot.", "Elite Elephant Wrangler".

## Visual foundations

### Color
- Screens sit on `bg`: the brand yellow in **Sunny** (light), deep grape in **After Dark**.
- Cards are `surface` with a `stroke-card` outline in `line` and `shadow-pop`. Text on cards is `ink`; secondary text is `ink-muted`.
- Each activity type owns a color: `type-distance` pink, `type-weight` purple, `type-duration` teal, `type-reps` orange. Use it for its tag, meter fill, StatTile fill, chart bars and icon chip. Text on any of these uses the matching `on-type-*` token, never a literal white.
- `accent` (pink) is the action color: LogButton, primary Button, toggles. It doubles as the Distance color because distance is the hero type.
- `brand-yellow` marks the current selection (active tab, segmented control, small chips). In After Dark it is also the focus ring and the greeting.
- `streak` is for the flame only. `success` and `danger` appear as text on `surface`, always with a word.
- The Ticker is the one inverted card: `ink` fill, `surface` text.

All text pairs meet 4.5:1 in both themes, including `on-type-weight` on `type-weight` (white in Sunny, dark in After Dark, because the lifted purple is too light for white).

### Type
- **Fredoka** (display, 600–700) for numbers, titles, buttons, tabs and tags. **Nunito** (body, 600–800) for sentences and rows. Fallback: SF Pro Rounded.
- One `display-hero` per screen. Totals use `numeral` with tabular figures.
- Body text is Nunito 600, not 400; regular weight looks thin next to the outlines.
- In SwiftUI, scale every style with Dynamic Type (`.font(.custom("Fredoka", size: 40, relativeTo: .largeTitle))`).

### Shape, outline and shadow
- Corners: `radius-lg` (32) for cards and sheets, `radius-md` (20) for tiles, fields and widgets, `radius-sm` (12) for chips inside cards, `radius-pill` for tags, chips, buttons, meters and the tab bar.
- Outlines: `stroke-card` (3px) on cards, buttons, tab bar, LogButton and illustrations; `stroke-control` (2.5px) on chips, meters and toggles.
- Shadows are hard and offset (`shadow-pop`, 6px down-right, no blur). Pressing moves the element 4px down-right and shrinks the shadow to `shadow-press`. Nothing else gets a shadow: not text, not list rows, not system surfaces.
- Tags tilt -2°. Nothing else rotates at rest.

### Spacing and layout
- Screen margins `space-5` (20). Gap between cards `space-4` (16). Card padding `space-6` (24). New sections start `space-8` (32) below the last.
- Home order: greeting → HeroStat → StatTiles → StreakCard + RankCard → ChallengeCard → Ticker → Recent Activity → PackPicker.
- The TabBar floats over content with the LogButton beside it; leave 96pt of bottom inset in scroll views.

### Motion
- Buttons and chips press on touch-down (0.12s). Meters fill over 0.6s ease-in-out.
- Celebration: confetti falls for 1.2s, the badge springs in (0.6 → 1.05 → 1).
- With Reduce Motion: no confetti fall, no springs; fades only. Haptics still fire.

### States
- Focus: 3px `focus` ring, offset 3px, on every interactive element.
- Disabled: 45% opacity, no shadow.
- Locked badges: dashed outline, no fill, no shadow.

## Iconography

Line glyphs drawn at 2.6pt stroke with round caps, sitting inside 44pt rounded-square chips filled with the type color. In SwiftUI, use SF Symbols at `.semibold` weight as the equivalents: `figure.run`, `dumbbell`, `timer`, `arrow.triangle.2.circlepath`, `plus`, `square.and.arrow.up`, `lock`, `shield`. Icons inherit the `on-type-*` or `ink` color. No emoji as icons.

## Illustration

Pack art is drawn as chunky flat shapes: rounded rectangles and circles filled from the palette (`type-reps` orange, `brand-yellow`, `accent-2` purple, `surface`), outlined at 3px in `line`, with one solid `ink` dot for an eye. No gradients, no texture, no faces beyond dots. The previews include a bee, a blue whale, a brown bear, a pumpkin, a flame and a medal as examples of the style. Until illustrations exist for all five packs, show the pack emoji at 56pt inside an outlined 72pt circle.

There is no logo yet. Set "FunFitness" in Fredoka Bold.

## Using it in SwiftUI

Define the tokens once as asset-catalog colors (Any / Dark appearances) named exactly as below, then reference them through one extension.

```swift
extension Color {
    static let ffBg = Color("bg")              // FFD43B / 17122E
    static let ffSurface = Color("surface")    // FFFFFF / 262051
    static let ffInk = Color("ink")            // 1E1640 / FFF8E1
    static let ffLine = Color("line")
    static func ffType(_ t: ActivityType) -> Color { Color("type-\(t.rawValue)") }
    static func ffOnType(_ t: ActivityType) -> Color { Color("on-type-\(t.rawValue)") }
}

struct PopCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(Color.ffSurface, in: .rect(cornerRadius: 32))
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.ffLine, lineWidth: 3))
            .background(Color.ffLine, in: .rect(cornerRadius: 32).offset(x: 6, y: 6))
    }
}
```

`ActivityType.cardGradient` and the hex literals in `SharedComponents.swift` and `HomeView.swift` are replaced by these tokens; `appBackground` becomes `bg` and `appCard` becomes `surface`.

## Adapting the app

What this direction changes structurally, compared with the current build:

- **Home** leads with one HeroStat that merges the distance StatCard with its ticker line. Weight, Duration and Reps become flat StatTiles. The full Ticker stays as one inverted card lower down.
- **Tab bar** becomes a floating pill with words only: Home · Progress · Badges · You (Achievements and Profile are renamed for length).
- **The + button** moves from the top-right toolbar to a 64pt LogButton beside the tab bar, with a long-press menu of types (answers TestFlight D1).
- **Gradients go.** Every card gradient becomes a flat fill plus outline.
- **Pack picker** is renamed "Compare with" so packs aren't confused with light/dark appearance.
- **Light mode becomes the hero.** Today's app is designed dark-first; here Sunny is primary and After Dark is the variant.
- **Share cards** are always rendered in Sunny colors.
