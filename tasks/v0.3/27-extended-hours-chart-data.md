# 27 — Extended-hours chart data: fill 26's 盘前/盘后 zones

- **Status:** DONE (Claude, PR #30; manual pre-market zone check deferred to Monday)
- **Owner:** —
- **Blocked by:** 26 (the `ChartSeries` pre/post seam), 24 (only for the
  accumulate-from-polling fallback)
- **Allowed new deps:** none

## Why

Task 26 gives the 1D chart pre/post zones with a data seam; this task makes
data actually appear there. Owner ask (2026-07-12): the day chart should show
盘前/盘后 segments, not just the regular session.

## What we already know (manager probes, 2026-07-12, market closed/weekend)

No known free Tencent/Sina endpoint returns pre/post **minute series**:

- Sina `US_MinKService.getMinK` — regular session only (provider-report-v2 §8).
- Tencent `web.ifzq.gtimg.cn/appstock/app/UsMinute/query?code=usAAPL.OQ` —
  **works, and is 1-minute granularity** (391 bars `0930…1600`, `date`,
  survives the weekend with the last session's data — unlike
  `appstock/app/minute/query`, which is wiped when closed). Its `pandata`
  block is only the LATEST ext quote (`last/pct/netchange/volume/time/
  tag=pre|after/season=EDT|EST`), not a series. Param variants
  `type=pre|after`, `period=pre`, `pre=1`, `ext=1`, `session=pre` are all
  ignored (391 regular bars regardless).
- Sina `gb_` fields 21–25 = latest ext quote only (already used for the chips).

## Two-step plan

**Step 1 — timeboxed spike (half a day max):** hunt for a real ext-hours
minute-series endpoint before building the fallback. Look where the data
visibly exists: Tencent 自选股 H5 / gu.qq.com US pages and Sina's US-stock
page 盘前 chart — network-inspect what they call. Record findings (endpoints,
fixtures) in `docs/provider-report-v2.md` as a new section, same style as the
07-08 probes. If a series endpoint exists: use it, done (skip the fallback).

**Step 2 — fallback if the spike comes up empty: accumulate our own series.**
While task 24's extended-session polling is live (30s cadence), append each
distinct ext quote (Sina gb_ price + its EDT timestamp field 24, or
`UsMinute.pandata`) to a per-symbol, per-day point list persisted in the
existing market cache (keyed by ET trading date; wiped on date change).
The 1D chart's pre/post zones draw whatever has been accumulated. Honest
limitation, accepted by design: points only accumulate while the app is open —
sparse/gappy segments are fine and render as-is (26's geometry advances x with
time). Never fetch faster than 24's locked cadence for this.

## Also in scope (spike bonus, small)

`UsMinute` gives 1-minute regular-session bars vs the 5-minute Sina feed we
chart today. If the spike confirms it's stable (headers/referer needs, CORS,
weekday behavior), switch the 1D regular-session source to it — finer line,
one fewer JSONP/GBK parser in the hot path. Separate commit within the PR;
drop it if anything looks flaky (it must not block the ext-hours goal).

## Acceptance criteria

- [ ] Spike findings written into `docs/provider-report-v2.md` (endpoint(s),
      fixtures under `test/fixtures/`, GO/NO-GO verdict) — even if negative.
- [ ] Pre/post points flow into 26's seam: unit tests for the chosen path
      (parser tests if an endpoint was found; accumulate/persist/date-rollover
      tests if fallback).
- [ ] Ext points never error the chart: source failure → zones stay empty,
      regular line unaffected.
- [ ] Manual (device or emulator during a live pre/post session): 盘前 or 盘后
      zone visibly gains points over a few minutes.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo
      guard tests).
- [ ] `format`/`analyze`/`test` clean.
