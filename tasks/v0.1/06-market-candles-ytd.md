# 06 — Market data: candles, YTD, session labeling

- **Status:** BLOCKED (needs 05)
- **Owner:** —
- **Blocked by:** 05
- **Allowed new deps:** — (extends the 05 client)

## Goal
Complete `QuoteRepository`: historical series for every `ChartRange`, the YTD change the
race ranking needs, and the pre/regular/post session fields — all per the 04 report's
provider plan.

## Scope
- in:
  - candles(symbol, range) for all `ChartRange`s: intraday series for `day`, daily
    candles for week/month/quarter/ytd/year.
  - `ytdChangePct`: current price vs last year's final close (derive from daily candles
    or the endpoint the 04 report chose; document it).
  - Session: derive pre/regular/post/closed from US market hours (America/New_York,
    DST-aware) + provider timestamps; fill `extChangePct` when outside regular hours.
    If the provider has no true pre/post quote, compute latest-trade vs regular close
    and document the limitation (per 04).
  - Baseline helper: given a range, return the baseline price (prev close for `day`,
    period-start close otherwise) so the chart (10) and detail screen (13) don't
    re-implement it.
- out:
  - No UI. No disk caching.

## Acceptance criteria
- [ ] Unit tests with mocked HTTP: candles per range, ytdChangePct math (incl. year
      boundary), session derivation for pre/regular/post/closed fixtures, baseline
      helper per range.
- [ ] `format`/`analyze`/`test` clean.
