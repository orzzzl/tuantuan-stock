# 34 — Overnight polling wiring

- **Status:** BLOCKED (owner design sign-off on `docs/overnight-design.md`)
- **Owner:** —
- **Blocked by:** 32, 33; owner sign-off on the v0.4 design
- **Allowed new deps:** none

## Why

Task 33 gives us an overnight quote source; this task makes the app actually ask
it on a clock — reusing task 24's polling machinery, lifecycle gating, and
backoff, extended with the one new session state.

## Scope

- in:
  - The refresh-interval ladder in `lib/data/market/live_market_refresh.dart`
    learns `overnight`: quotes poll at the existing 30s extended-session
    constant; the 1D chart poller stays **off** overnight (nothing new is drawn
    on the day axis). All cadence values stay named constants in that one file.
  - One batched request per tick for **watchlist symbols ∪ the open detail
    symbol** — never a second concurrent Alpaca request; the detail screen must
    not add its own faster overnight poll (design §5.3; 2 req/min total against
    the observed 200/min limit).
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

- [ ] Fake-clock provider tests: inside the window quotes tick at 30s and the
      day-chart poller is silent; outside the window zero Alpaca requests;
      backgrounded zero requests; resume refreshes immediately.
- [ ] Boundary tests: 19:59→20:01 starts, 03:59→04:01 stops, Friday night never
      starts.
- [ ] Batch-composition test: detail screen open on a non-watchlist symbol ⇒
      exactly one request containing watchlist ∪ that symbol.
- [ ] Backoff test: failures double up to 5 min, success restores 30s, CN
      pollers unaffected throughout.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard
      tests).
- [ ] `format`/`analyze`/`test` clean.
