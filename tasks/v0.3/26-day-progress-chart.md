# 26 — 1D chart: fixed day axis, 团团 flies left → right through the day

- **Status:** READY
- **Owner:** —
- **Blocked by:** — (code-independent of 24, but the live effect only shows once
  24's refresh lands; coordinate merges if both touch the detail screen)
- **Allowed new deps:** none

## Why

Owner clarification (2026-07-12, refining the report behind task 24): the ask was
never "a static picture that refetches". On the 1D range he wants the day itself
to be the canvas — at the open 团团 starts at the far LEFT, and over the trading
day the line grows rightward under the plane until the close lands at the far
right. Today `SkyChartGeometry.resolve` stretches whatever candles exist across
the full width (`step = width / (closes.length - 1)`, sky_chart.dart), so the
chart always looks "finished" and 团团 is pinned to the right edge all day.

## Goal

On the **1D range only**, x is time, not index. The axis is the full US trading
day **including extended hours, split into three zones with visible 盘前/盘后
boundaries** (owner addition 2026-07-12): pre-market 04:00–09:30 ET, regular
09:30–16:00, after-hours 16:00–20:00 (ET from the existing
`cn_eastern_time.dart` helpers — do not invent a second clock). Each candle
sits at its true time-of-day position, the line ends at the latest bar, and
团团 rides the tip: at the open of the day the plane is at the far left, and it
crosses the screen as the day goes on. All other ranges keep the current
stretch-to-fit behavior.

## Design decisions (locked)

- **Zone widths are compressed, not proportional to wall-clock time**: pre 15% /
  regular 70% / post 15% of the chart width (real proportions would shrink the
  regular session to ~40%). Time maps linearly *within* each zone.
- **Boundaries**: a subtle vertical divider at 09:30 and 16:00 (CuteColors,
  hairline — decoration, not data), with small 盘前 / 盘后 zone labels (ARB,
  localized) inside the extended zones. Regular zone gets no label.
- **Data per zone**: regular zone = the minute-bar line (today's Sina 5-min
  feed; task 27 may upgrade the source). Pre/post zones render a line from
  extended-hours points **when the series provides them** and stay empty
  sky/water when it doesn't — the geometry/UI must be complete and correct
  either way. Providing ext-hours points is task 27's job, not this task's.
- **团团 tracks time, not just data**: the plane's x position is "now" on the
  day axis. Before any bar exists (e.g. pre-open), it flies level on the
  waterline (昨收 baseline) at the current-time position — so it starts at the
  left in the early morning and drifts right even before the line begins. With
  data, it rides the latest point as today. After 20:00 / closed days: full
  line, plane at the right edge (matches today's closed-market view).
- The unfilled remainder of the day renders as the normal sky/water background
  with the centered waterline continuing to the right edge — no placeholder
  line, no dimming, no "future" hatching.
- Non-trading gaps inside a zone (halts, missing bars) just advance x with
  time — the line connects available bars as it does now.
- Baseline stays 昨收 for all three zones (one waterline all day).
- `docs/DESIGN.md` signature-chart section: document the zoned 1D time axis
  (it's a behavior change to the signature element).

## Scope

- in: `SkyChartGeometry.resolve` (or a 1D-specific path) takes the day-axis
  windows and maps candle `time` → zoned x; zone dividers + labels; plane
  time-tracking anchor + empty-state behavior; detail screen passes
  range/session info; a seam in `ChartSeries` (or alongside it) for optional
  pre/post point lists so 27 can plug data in without touching geometry again;
  DESIGN.md update; tests.
- out: other ranges' geometry, the mini sparkline (watchlist rows keep
  stretch-to-fit), *sourcing* pre/post data (task 27), tick animation of the
  last point (still a possible future task), anything in task 24's polling
  wiring.

## Acceptance criteria

- [ ] Geometry unit tests with fixed clocks: bar at 09:30 → x = 15% of width
      (regular-zone left edge); 12:45 → zone midpoint (50% of width); 16:00 →
      85%; pre bar at 04:00 → left edge; post bar at 20:00 → right edge; empty
      candle list at a fixed "now" → plane on the baseline at the current-time
      x; full day → line spans full width.
- [ ] Zone dividers render at exactly the 09:30/16:00 boundaries; 盘前/盘后
      labels come from ARB in both locales.
- [ ] Pre/post zones with no ext points render as plain sky/water (no crash,
      no zero-anchored artifacts).
- [ ] 5D/1M/…/All geometry unchanged (regression test: same points in, same
      offsets out as before this task).
- [ ] Manual (emulator, market open, with 24 merged if available): mid-session
      1D chart shows the line partway across the regular zone with 团团 at the
      tip, dividers visible, empty sky ahead.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard
      tests).
- [ ] `format`/`analyze`/`test` clean.
