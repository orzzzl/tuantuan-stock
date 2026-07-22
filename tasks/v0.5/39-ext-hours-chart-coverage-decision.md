# 39 — Pre/post chart coverage: revisit the task-27 trade-off

- **Status:** BLOCKED (owner decision needed)
- **Owner:** —
- **Blocked by:** —
- **Allowed new deps:** none (until a decision picks otherwise)

## Why

Owner field report (2026-07-21): the 1D chart's 盘前/盘后 zones are empty "most of
the time" in daily use. Task 27 (2026-07-13, `tasks/v0.3/27-extended-hours-chart-
data.md`) already spiked this and found no free Tencent/Sina endpoint returns a
pre/post **minute-series** — only a single latest-quote point (Sina `gb_` fields
21-25) or a regular-session-only 1-minute series (Tencent `UsMinute`, confirmed
still exactly 391 bars / 09:30-16:00 ET on a fresh re-check today, 2026-07-21, no
change since the original spike). The shipped fallback (`_recordExtPoints` /
`_extZoneCandles` in `cn_quote_repository.dart`) accumulates its own points only
while the app is foregrounded and polling **during** the actual 04:00-09:30 and
16:00-20:00 ET windows — accepted at the time as an "honest limitation."

In practice, for a Beijing-based user those windows land at roughly 16:00-21:30
and 04:00-08:00 local time. Unless the app happens to be open in one of those two
narrow local-time bands, the day's pre/post zones never accumulate a single point,
which is why they read as empty far more often than the task-27 write-up
anticipated.

## Decision needed (owner)

This is a product/cost decision, not a bug fix — writing code before the decision
would be guessing. Options:

- **D1 — accept the gap, make it visibly intentional.** Cheapest: when a zone has
  no accumulated points for the current trading day, render an explicit "no
  pre/post data" affordance instead of a blank zone, so it reads as "nothing
  happened to be captured" rather than "the chart is broken." No new data source.
- **D2 — find/pay for a real minute-series pre/post feed.** Same shape of
  trade-off as the v0.4 overnight work (task 29-31 spikes): would need its own
  provider spike (reachability from mainland China, rate limits, cost) before any
  implementation. Only worth spiking if D1's visible-gap isn't good enough for the
  owner.
- **D3 — poll during the ext-hours windows even while the app is backgrounded.**
  Technically the most complete fix for the *existing* free data (Sina's latest-
  quote point would at least get sampled more densely), but needs a background-
  fetch mechanism per platform (iOS background modes / Android WorkManager-style
  scheduling) — meaningfully more complexity and battery cost than anything else
  in this app so far, for a look-only side project. Flagged, not recommended
  without owner sign-off.

Recommendation: D1 now (cheap, immediate, honest), D2 only if D1 turns out to
still feel broken after living with it. D3 not recommended.

## Next step

Owner picks D1 / D2 / D3 (or a mix); file the implementation task(s) once picked,
following the `docs/overnight-design.md` sign-off pattern (record the decision in
this file or a follow-up doc, then flip this task's status to unblock the real
implementation task).
