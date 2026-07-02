# 11 — Plane-rider mascot widget

- **Status:** DONE (PR #11)
- **Owner:** Codex
- **Blocked by:** 02
- **Allowed new deps:** — (CustomPaint/widgets only)

## Goal
团团 in a tiny plane, to be pinned at the chart line tip: happy climbing, cutely
panicking on the way down, suffocating with bubbles underwater.

## Scope
- in:
  - `lib/features/chart/plane_rider.dart` — `PlaneRider(state, size)` with three states:
    - `climbing`: orange plane tilted up, happy round face (dot eyes + highlights, pink
      cheeks, smile), sparkle, contrail puffs.
    - `diving`: red plane tilted down; **cute panic** per DESIGN.md — round face
      unchanged, soft worried brows, tiny "wah" mouth, wind-bent sprout. Never distort
      the face.
    - `underwater`: diving pose + rising bubbles (replaces sweat/contrail).
  - Faithful to the mockup SVGs in `mockups/design.html` (they are the spec).
- out:
  - No animation yet (static per state); no chart logic — the chart decides the state
    (tip above/below baseline, slope sign) and position.

## Acceptance criteria
- [ ] Widget test pumps all three states; sizes scale cleanly at 40–80px widths.
- [ ] Colors from `CuteColors`.
- [ ] `format`/`analyze`/`test` clean.
