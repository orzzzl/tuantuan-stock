# 34 — Overnight polling wiring

- **Status:** IN REVIEW (Claude, PR #44; blockers 32, 33 merged 2026-07-13)
- **Owner:** Claude
- **Blocked by:** 32, 33
- **Allowed new deps:** none

## Why

Task 33 gives us the `OvernightQuoteCoordinator` core; this task puts it on a
clock — reusing task 24's polling machinery, lifecycle gating, and backoff.
The coordinator's schedule reads only task 32's ET window classifier and the
app lifecycle, never `Quote.session`: on a degraded tick the merged quote
falls back to the CN quote whose session is `closed`, and a session-driven
schedule would sleep until pre-market instead of noticing Alpaca recover
(design §5.2a).

## Scope

- in:
  - The coordinator's tick loop: inside the ET overnight window, one batched
    request per tick for the registered union (**watchlist ∪ the open detail
    symbol**) at the existing 30s extended-session constant from
    `lib/data/market/live_market_refresh.dart` — the detail screen never adds
    its own overnight poll, it only registers its symbol (design §5.3; 2
    req/min total against the observed 200/min limit). The 1D chart poller
    stays **off** overnight (nothing new is drawn on the day axis). All
    cadence values stay named constants in that one file.
  - **No-value path (design §5.2a)**: the loop keeps ticking at 30s (stretched
    only by the failure backoff below) while inside the window, whether or not
    ticks return values. The schedule reads the window classifier + lifecycle
    only — never `Quote.session` or the merged quotes.
  - Provider wiring: watchlist keeps its symbol set registered; detail screens
    register/unregister on open/dispose; quote providers watch the snapshot so
    a new snapshot re-merges and re-renders without a CN refetch; the CN quote
    pollers keep their existing closed-session behavior throughout.
  - Lifecycle: backgrounded ⇒ zero requests until resume; foreground resume
    inside the window refreshes immediately (same behavior the market-open
    check verified for task 24 on 2026-07-13).
  - Window edges: crossing 20:00 ET starts polling without a restart; crossing
    04:00 ET stops it and the session classification falls back to `closed`
    (the existing closed-session wake-up delay logic extends to the next
    overnight/pre boundary, whichever is sooner).
  - Failure backoff: consecutive overnight failures double the interval up to
    5 min (task 24 pattern) and recover on next success — per-source, so an
    Alpaca outage never slows the CN pollers.
- out: UI (task 35), any new fetch the chosen UI option might add (that belongs
  to 35), changes to regular/pre/post cadences.

## Acceptance criteria

- [ ] Fake-clock provider tests: inside the window the coordinator ticks at
      30s and the day-chart poller is silent; outside the window zero Alpaca
      requests; backgrounded zero requests; resume inside the window refreshes
      immediately.
- [ ] Boundary tests: 19:59→20:01 starts, 03:59→04:01 stops, Friday night never
      starts.
- [ ] Batch-composition test (end-to-end): detail screen open on a
      non-watchlist symbol ⇒ exactly one request per tick containing
      watchlist ∪ that symbol; never a second concurrent request.
- [ ] No-value continuity test: ticks returning empty/stale payloads (merged
      quotes stay `closed`) do NOT stop or reschedule the loop to pre-market —
      it keeps ticking at 30s/backoff and a later successful tick re-lights
      the overnight values without a restart.
- [ ] Backoff test: failures double up to 5 min, success restores 30s, CN
      pollers unaffected throughout.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard
      tests).
- [ ] `format`/`analyze`/`test` clean.
