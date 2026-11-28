# Product page header and search results

| File | Slot | Size | Art safe area (x, y, w, h from top-left) |
|---|---|---|---|
| universal-5244x2950.png | **Universal** (header and search results in one), recommended | 5244 × 2950 (16:9) | 1921, 660, 1402 × 962 |
| header-3840x1646.png | Header only | 3840 × 1646 (21:9) | 1097, 493, 1646 × 661 |

Specs from Apple's "Creative assets specifications" page (checked 2026-11-27): PNG, no alpha; keep key art in the
safe area (the rest may be cropped); one short phrase at most; no pricing, URLs, ©, awards or other platforms.
English only, so localize the phrase if more languages are added later.

Design: "Your workouts, in hippos!" with the hippo badge in the safe area; the walk and strength screenshots,
an elephant, a giraffe and confetti in the auxiliary area. Made with `scripts/screenshots/header.swift`:

    swiftc -O header.swift -o header
    header <out.png> <W> <H> <safeX> <safeY> <safeW> <safeH> <left.png> <right.png> [--guides]

`--guides` draws the safe area in red, for checking only. Use App Store Connect's Preview button to check the crops.
