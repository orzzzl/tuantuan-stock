# 20 — Persistent market cache: instant stale paint + no cold-start refetch storm

- **Status:** READY
- **Owner:** —
- **Blocked by:** 19
- **Allowed new deps:** none (reuse shared_preferences, already in the tree for the
  watchlist)

## Why

All market caches today are process-lifetime in-memory (YTD baselines, logos,
identities), and quotes aren't stored at all. Every cold start re-fetches everything
from zero, and until the network answers the user stares at a spinner.

## Goal

Launch paints the last-known list instantly (visibly stale-marked), then refreshes.
Stable facts (YTD baselines, identities, logo URLs) survive restarts.

## Scope

- in:
  - Disk persistence (prefs JSON blobs are fine at watchlist scale) for:
    - last successful quote batch + fetch timestamp — served synchronously at startup
      as a stale board; a refresh kicks off immediately.
    - YTD baselines keyed by (symbol, calendar year) — constant all year; never
      refetch within the year.
    - identity (names, exchange) and logo URLs keyed by symbol — refresh opportunistically,
      not on the critical path.
  - A visible "as of <time>" staleness cue on the stale board consistent with the cute
    theme (ARB strings; zh + en), cleared when fresh data lands.
  - Cache versioning + corrupt-entry tolerance (drop and refetch; never crash on bad
    JSON).
- out: provider/HTTP changes (17/18), watchlist storage itself (untouched).

## Acceptance criteria

- [ ] Tests: cold start with a warm cache paints a board with zero network calls
      (mock client asserts); stale cue shown then cleared; corrupt cache entries are
      dropped silently; YTD baseline for the current year is never refetched.
- [ ] Startup with an empty cache behaves exactly as 19 left it (no regression).
- [ ] `format`/`analyze`/`test` clean; ARB-only strings.
