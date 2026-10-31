FunFitness reads like a naturalist's field guide, Vol. I. Every total is an entry, every milestone a numbered plate, every badge a catalogued specimen. The chrome is quiet ink on parchment; the fun lives in the copy and the drawings.

No logo yet; set FunFitness in the display face (Fraunces 800).

## Content fundamentals

- **Write from the user's side.** "3.4 mi logged", "4 badges to Gold", "Log an entry". Second person in prompts ("Reach 5 mi to unlock"), never "we".
- **Playful in content, plain in chrome.** The jokes come from the packs and `ReferenceUnit`: "That's about 270 blue whales lined up nose to tail!", "1,240 lbs is 2.6 grizzly bears 🐻". Labels, buttons and tabs stay plain: GUIDE, PROGRESS, COLLECTION, PROFILE.
- **The guide voice is a light layer, not a rewrite.** Use it for structure words only: Plate, Fig., No., Specimen, Observed, Not yet observed, New entry recorded, Field notes, Expedition. Milestone titles and pack comparisons are printed exactly as the app writes them.
- **Headline pattern on Guide:** "<total in words> is roughly <count> <unit>." built from the lead ticker line. "3.4 mi is 2.4 honeybee flights to the flowers 🐝" becomes "3.4 miles is roughly 2.4 honeybee flights." Never invent a count.
- **Captions** follow "Fig. NN. <Binomial>. <sentence>." The number is the milestone's catalogue number. Binomials appear only in the Animals pack: Balaenoptera musculus (blue whale), Ursus arctos (brown and grizzly bear), Apis mellifera (honeybee), Hippopotamus amphibius (hippo), Giraffa camelopardalis (giraffe), Loxodonta africana (elephant). Other packs use the plain name.
- **Pack copy never contains units.** Units sit in the chrome around it ("5 mi: 270 blue whales").
- **Packs, not themes.** Animals, Cities, Landmarks, Food and Dinosaurs are packs. Daylight and Lamplight are appearances. Never call either a "theme pack".
- **Streaks are weekly.** "6 weeks running", "Best 9", "1 streak shield". Never "days".
- **Calories stay out of the guide.** They appear only in session detail and Apple Health.
- **Emoji** come from the app's data (pack art, challenge emoji, ticker lines) and appear where that data appears. Never use emoji to decorate chrome.
- **Casing:** sentence case for headlines and buttons ("Log an entry", "Keep Going" keeps the app's own casing). Labels are uppercase mono via CSS `text-transform`, typed in normal case.
- Sample screens say "Example data".

## Visual foundations

### Colour

Two appearances: **Daylight** (`light`, primary) and **Lamplight** (`dark`).

- `bg` is the page. `surface` is the inside of a plate (illustration boxes, the share page, the log sheet). `surface-alt` is for recessed fills only.
- `ink` sets text, rules, plate outlines and line drawings. It also fills the one primary action, the Log an entry bar, with `on-ink` text.
- `accent` (rust) marks progress and emphasis: plate numbers, the italic comparison phrase, ruler fills, the active tab and pack underline, links. Never fill a button with it.
- `accent-2` (moss) marks observation: "Observed Oct 3, 2026", "New entry recorded", rank lines.
- Type colours label and fill per-type marks: `type-distance` (rust), `type-weight` (moss), `type-duration` (slate), `type-reps` (ochre). They are text-safe on `bg` and `surface` in both appearances. A type colour always travels with the type's word, so colour never carries meaning alone.
- `streak` is the weekly count and shield. `success` and `danger` always come with a word.
- `live-ground`, `live-ink`, `live-ink-muted`, `live-accent` are fixed across appearances for the Lock Screen Live Activity, which sits on dark system material.
- **Contrast:** every text token meets 4.5:1 on the grounds its usage note names in both appearances; `line`, `progress-track` and `focus` meet 3:1. Lamplight steps `line` down from `ink` so hairlines don't glare.

### Type

- **Fraunces** (`--font-display`): `display-hero`, `display`, `title`, `numeral`, plus `comparison` (italic 600) for the comparison phrase in rust. Heavy, optical sizing on.
- **Newsreader** (`--font-body`): `headline`, `body`, `body-strong`, `caption` (italic, for figure captions and Latin binomials).
- **IBM Plex Mono** (`--font-mono`): `label` and `tab` (uppercase, 0.12 to 0.14em tracking), `data` for dates, paces, PR values, catalogue numbers and chart axes.
- One `display-hero` per screen. Numerals are lining and tabular.

### Rules, not cards

- Structure comes from rules. `rule-hair` (1px, `line`) between rows, around plates and between grid cells. `rule-heavy` (2px, `ink`) under the masthead and above the tab bar, and to open a new chapter (the monthly expedition).
- No shadows, no elevated cards, no tinted panels. A plate is the only box, and it holds a drawing.
- Corners are square: `radius-sm` 0 for bars, plates, buttons, inputs; `radius-md` 2px for chips and the stepper; `radius-pill` only for system switches.

### Layout and spacing

- 390pt phone canvas, `space-6` (24) side gutter. Sections are separated by a hairline and `space-5` to `space-6`.
- Every tab page opens with the masthead: "THE FUNFITNESS FIELD GUIDE" left, the page's running head right (VOL. I on Guide, PROGRESS, COLLECTION, PROFILE), 2px `ink` rule under.
- On Guide the Log an entry bar sits full width above the tab bar.

### Progress: the ruler

Ticks in `line` (minor every 5%, major every 25%) over a solid bar in the type colour; the unfilled length is a 1px `progress-track` rule. Labels sit below: logged amount left, the target with its milestone phrase or "N to go" right. Never a rounded pill.

### Charts

Ink linework. Weekly volume is a stem chart: `ink` stems ending in a type-colour dot, open circles for zero weeks, values over each stem. The 12-week heatmap is hairline cells with 1 or 3 stipple dots; density is read by dot count, not a colour ramp. Figures are lettered "Fig. A", "Fig. B".

### States

- Focus: 2px solid `focus`, 2px offset, on every interactive element.
- Disabled: dashed outline and `ink-muted` text.
- Pressed: `surface-alt` fill on rows; chips invert to `ink` / `on-ink`.
- Locked: dashed `ink-muted` outline, no fill, "Not yet observed".

### Motion

Ink is drawn, not bounced. Plate strokes trace in over about 600ms on Celebration; ruler fills extend left to right over 400ms; the stamp lands with one haptic. With Reduce Motion, show finished states and keep haptics. Confetti, if kept, is a single fall of small paper flecks in `ink`, `accent`, `accent-2`.

## Iconography

The guide is typographic. Tabs are words with no SF Symbols; rows carry no icons; the one glyph family is drawn marks (ruler ticks, tally strokes, the shield outline, the chevron "›" in mono). System controls (switches, steppers, share sheet) keep SF Symbols where iOS draws them. Pack art stays emoji in content until line drawings exist for every milestone.

## Illustration

Plates are line drawings: `ink` strokes at 1.6px, round caps, dashed or dotted secondary lines, one filled eye dot, a ground line where the animal stands. No fills, no shading, no colour. Each plate sits in an outlined `surface` box with an italic `caption` under it and, on Celebration, a black-and-white scale bar. Drawings are simple shapes from SVG paths. The previews include a blue whale, honeybee with hive and flower, brown bear, hippo and giraffe as examples; the full set (42 milestones × 5 packs) does not exist yet, and until it does a plate shows the milestone's emoji centred in the frame.

## Mapping to SwiftUI

Ship the tokens as an asset catalog colour set per token (Any = Daylight, Dark = Lamplight) plus a small `FG` namespace. Fonts: bundle Fraunces, Newsreader and IBM Plex Mono (all OFL) and register them in Info.plist; `Font.custom(_:size:relativeTo:)` keeps Dynamic Type.

```swift
import SwiftUI

enum FG {
    static let bg = Color("bg"), surface = Color("surface"), ink = Color("ink")
    static let onInk = Color("on-ink"), inkMuted = Color("ink-muted"), line = Color("line")
    static let accent = Color("accent"), track = Color("progress-track")

    static func display(_ size: CGFloat = 40) -> Font { .custom("Fraunces", size: size, relativeTo: .largeTitle).weight(.heavy) }
    static let caption = Font.custom("Newsreader", size: 15, relativeTo: .footnote).italic()
    static let label = Font.custom("IBMPlexMono-Medium", size: 12, relativeTo: .caption)
}

struct Ruler: View {               // ProgressMeter
    var fraction: Double; var tint: Color = FG.accent
    var body: some View {
        VStack(spacing: 0) {
            Canvas { ctx, size in                       // ticks every 5%, major every 25%
                for i in 0...20 {
                    let x = size.width * CGFloat(i) / 20, h: CGFloat = i % 5 == 0 ? 12 : 7
                    ctx.stroke(Path { $0.move(to: .init(x: x, y: size.height)); $0.addLine(to: .init(x: x, y: size.height - h)) },
                               with: .color(FG.line), lineWidth: i % 5 == 0 ? 2 : 1)
                }
            }.frame(height: 12)
            GeometryReader { g in
                ZStack(alignment: .bottomLeading) {
                    Rectangle().fill(FG.track).frame(height: 1)
                    Rectangle().fill(tint).frame(width: g.size.width * fraction)
                }
            }.frame(height: 14)
        }
        .accessibilityElement().accessibilityValue(Text(fraction, format: .percent))
    }
}

// Log an entry bar
Button("Log an entry") { showLogSheet = true }
    .font(.custom("Fraunces", size: 20, relativeTo: .headline).weight(.bold))
    .frame(maxWidth: .infinity, minHeight: 56)
    .foregroundStyle(FG.onInk).background(FG.ink)          // square: no clipShape
```

Live Activity: set `.activityBackgroundTint(Color("live-ground"))` and use the `live-*` colours, which have the same value in both appearances.

## Adapting the app

What this direction changes structurally compared with today's app:

- **Tabs** become text-only and renamed: Home → GUIDE, Progress → PROGRESS, Achievements → COLLECTION, Profile → PROFILE. Replace the default `TabView` bar with a custom bar (words, 2px top rule, accent underline), keeping `TabView` underneath for state and accessibility.
- **Cards become ruled sections.** `StatCard`, `StreakCard`, `ChallengeCard`, `RecentActivityCard`, `TrackingCard`, `WeeklyVolumeCard`, `PersonalRecordsCard`, `ActivityHeatmapCard` drop `appCard` backgrounds and 20pt corners for hairline-separated sections on `bg`.
- **Home leads with one plate.** `AbsurdityTicker`'s lead line becomes the `display-hero` headline; the next milestone becomes a drawn plate with a ruler; the full ticker moves below as numbered field notes.
- **The plus button becomes a full-width bar** ("Log an entry") above the tab bar, on Guide only. The toolbar `plus.circle.fill` and `TrackWorkoutCard` / `RepeatLastButton` fold into it (long-press menu and a repeat-last sub-label).
- **ThemeSelector becomes underlined text tabs** (PackPicker), labelled "Pack".
- **Badges become specimens** numbered No. 01 to No. 42 in milestone order; locked ones are dashed empty frames.
- **The silly title becomes a title page** (RankCard) instead of a banner.
- **Progress bars become rulers** everywhere, including widgets.
- **Charts are redrawn** as stems and stippled cells in ink instead of filled bars and a colour ramp.
- **Celebration** keeps Keep Going and Share but trades the full-screen confetti for a drawn plate and stamp; the share image becomes a single plate page at the same 360 × 450.
- **Live Activity** keeps its data and controls; only styling changes, on fixed dark tokens.
- **New asset need:** a line-drawing library for pack figures. Until it exists, plates fall back to the existing emoji.
