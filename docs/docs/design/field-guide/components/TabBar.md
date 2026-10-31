# TabBar

The bottom tab bar: four uppercase, letterspaced text tabs under a 2px ink rule.

**Maps to:** `ContentView` `TabView` (`.tabItem` Home, Progress, Achievements, Profile). Renamed in the guide voice: GUIDE = Home, PROGRESS = Progress, COLLECTION = Achievements (badges), PROFILE = Profile.

**Consumer provides:** the selected tab. Labels are fixed.

**Do**
- Set items in `tab` (IBM Plex Mono 13/500, 0.12em, uppercase) in `ink`.
- Mark the active item three ways: `accent` colour, weight 600, and a 2px `accent` underline. VoiceOver reads the tab name plus "selected".
- Keep the 2px `ink` rule (`rule-heavy`) on top. It pairs with the masthead rule.

**Don't**
- Don't add SF Symbols above the words. The guide is typographic; icons come back only if testing shows people miss them.
- Don't tint the bar background. It sits on `bg`.

**Tokens:** `ink`, `accent`, `bg`, `rule-heavy`, `tab`, `space-3`, `space-5`.
