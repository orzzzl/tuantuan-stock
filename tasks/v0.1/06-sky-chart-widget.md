# 06 — Sky/water chart widget

- **Status:** BLOCKED (needs 02)
- **Owner:** —
- **Blocked by:** 02
- **Allowed new deps:** — (CustomPaint only; no chart package)

## Goal
The signature chart from DESIGN.md §sky/water chart: a `SkyChart` widget that renders a
candle/price series with the 0% baseline pinned to the vertical center — sky above,
water below.

## Scope
- in:
  - `lib/features/chart/sky_chart.dart` — input: `List<Candle>` (or points), a `baseline`
    price, direction (up/down/flat vs baseline). Rendering:
    - **Baseline exactly at 50% height**; y-scale symmetric so equal % moves are equal
      pixels above/below. The series may start above or below it (gap opens).
    - Water: light-blue fill from baseline to bottom, dashed waterline, small wave arcs,
      a fish glyph; localized `0% 昨收` label placed to avoid the line.
    - Sky: dotted cream gridlines; sun + cream clouds (up day) or rain cloud + drops
      (down day).
    - Line: thick rounded stroke, direction-tinted gradient, candy hard offset shadow,
      white button nodes at sampled points; gain-area gradient fill between line and
      baseline when above it.
  - A `MiniSpark` variant for list rows: thick rounded line only, no scenery.
  - Leave a positioned anchor (offset of the line tip) exposed so 07 can pin the plane.
- out:
  - No data fetching; no mascot (07); no touch interactions yet.

## Acceptance criteria
- [ ] Golden/widget tests: up-day, down-day, gap-up open, gap-down open — baseline always
      at half height.
- [ ] All colors from `CuteColors`.
- [ ] `format`/`analyze`/`test` clean.
