# 21 — China-safe logos

- **Status:** BLOCKED (needs the 16 logo recommendation + 17 client)
- **Owner:** —
- **Blocked by:** 16, 17
- **Allowed new deps:** none expected (bundled asset map is the likely answer; anything
  else must be OK'd in the 16 report)

## Why

Logos today = Yahoo v10 `quoteSummary` (website) → `google.com/s2/favicons`. Both hosts
are GFW-blocked: in China every row's logo lookup hangs to timeout. And even in the US
it's one serialized authenticated request per symbol on first sight.

## Goal

Logos resolve without Yahoo or Google, never block anything, and fail fast to the
designed ticker-ring fallback when unavailable.

## Scope

- in:
  - Implement the strategy pinned in the 16 report — expected shape: a bundled
    symbol→domain (or symbol→asset) map covering the top ~200 US tickers, favicon
    fetched from a China-reachable service or bundled outright; ticker-ring fallback
    for everything else (already the designed degraded state, zero new visual language).
  - Hard timeout + negative-result caching so an unreachable logo host costs at most
    one quick failed attempt per symbol per session (never a hang, never a retry storm).
  - Replace `YahooCompanyProfiles` usage in `StockRepository`/search results.
  - Logo URL persistence lands in 20 — coordinate the cache key shape.
- out: any redesign of the avatar look (white round avatar + ring fallback are locked).

## Acceptance criteria

- [ ] Unit tests: mapped symbol → logo URL; unmapped symbol → null fallback without a
      network call (when the bundled-map strategy is chosen); lookup failure caches
      negative and does not retry within the session.
- [ ] No references to `query1.finance.yahoo.com/v10` or `google.com/s2/favicons`
      remain outside the (soon-dead) Yahoo layer.
- [ ] `format`/`analyze`/`test` clean.
