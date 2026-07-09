# 18 — Tencent/Sina data layer: charts + YTD baselines

- **Status:** READY (17 merged via PR #23 — client infra available; "All" range pinned to Tencent month kline, 2007+, per owner)
- **Owner:** —
- **Blocked by:** 16, 17
- **Allowed new deps:** none

## Goal

Reimplement `QuoteRepository.chart()` and the YTD baseline source on the endpoints
pinned in the 16 report, replacing the Yahoo v8 path. This is the other half of the
60s-first-paint fix: today every quote refresh fires **one YTD chart request per
watchlist symbol** through a serialized queue.

## Scope

- in:
  - All `ChartRange`s mapped per the 16 report (expected: Sina 5m bars for `day`,
    Tencent daily kline for week/month/quarter/ytd/year, Tencent weekly/monthly kline
    — or Sina full daily history — for 5Y/All).
  - Day chart keeps its contract: extended-hours bars when available (gap open),
    baseline = previous regular close so the waterline stays correct (`ChartSeries.baseline`).
  - **YTD baseline without a per-symbol chart storm**: last year's final close fetched
    from the daily kline, at most once per symbol per process (in-memory; 20 persists
    it). It must NOT block `quotes()` — return quotes immediately, let
    `ytdChangePct` resolve later (coordinate with 19's provider split; whichever
    lands second wires them together).
  - Chart requests may run in parallel (no global queue), each with the ~8s timeout.
- out: UI changes (19), disk persistence (20), Yahoo deletion (23).

## Acceptance criteria

- [ ] Unit tests against 16 fixtures for every range mapping, the baseline rule, the
      extended-hours day slice, and one malformed-payload path. No real network.
- [ ] `quotes()` no longer awaits YTD baselines (regression test: quotes resolve even
      when the baseline source hangs).
- [ ] `format`/`analyze`/`test` clean; only `lib/data` touched apart from any agreed
      provider seam adjustment.
