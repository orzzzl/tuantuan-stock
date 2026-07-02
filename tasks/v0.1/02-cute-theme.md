# 02 — Cute theme foundation

- **Status:** IN PROGRESS
- **Owner:** Codex
- **Blocked by:** —
- **Allowed new deps:** google_fonts

## Goal
Port the "macaron" visual language from the locked mockup so every later widget pulls
color/shape/type from one place.

## Scope
- in:
  - `lib/app/cute_palette.dart` — `CuteColors`: the full palette from DESIGN.md §Visual
    language (cream/surface, matcha up family, coral down family, peach accents, text,
    borders, water blues, gradients). Single source of truth; no hex at call sites.
  - `lib/app/app_theme.dart` — `buildAppTheme()`: ColorScheme fully mapped (no Material
    lavender leaking through container roles), Card/Chip/Input/Dialog themes with fat
    radii + 2px warm borders, transparent scaffold.
  - `lib/app/cute_background.dart` — cream backdrop + three radial blobs.
  - Text theme: Baloo 2 + ZCOOL KuaiLe CJK fallback, weights w600–w900.
  - A small `CandyCard` container widget (white card, warm border, hard offset shadow) —
    the row/stat/chart cards all reuse it.
- out:
  - No screen content, no charts, no mascot.

## Acceptance criteria
- [ ] Placeholder screens render on the cream gradient with the rounded heavy font.
- [ ] `CandyCard` shows border + hard offset shadow per the mockup.
- [ ] No hard-coded hex outside `cute_palette.dart`.
- [ ] `format`/`analyze`/`test` clean.
