The card-pack reveal shown when a milestone unlocks: the new card with rays behind it, Keep Going and Share.

**Maps to:** `MilestoneView` (confetti, haptics, reduce-motion handling).

**Consumer provides**
- The unlocked `milestone`, its rarity and position, `badgesToNextRank`, `onKeepGoing`, `onShare`.

**Do**
- Motion: card scales from 0.9 and flips once (0.6s spring), rays fade in. Haptic success as today.
- Reduce Motion: show the finished static frame (this preview) with no rays, flip or confetti.

**Don't**
- Don't chain multiple reveals with sound; one card per unlock.

**Tokens:** `surface`, `rarity-*`, `glow`, `accent`, `shadow-neon`, `title`, `body`.
