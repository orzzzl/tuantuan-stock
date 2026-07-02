# 05 — Market data: quotes, search, profile (logo / market cap)

- **Status:** BLOCKED (needs 03, 04)
- **Owner:** —
- **Blocked by:** 03, 04
- **Allowed new deps:** http (or dio — per the 04 report; note it in the PR)

## Goal
Implement the quote/search/profile half of the data layer against the provider chosen in
the 04 spike, behind the domain seams. Candles/YTD/session come in 06.

## Scope
- in:
  - `lib/data/market/`: provider client + JSON→domain mapping (only this layer knows the
    HTTP shapes):
    - quote(symbol) → `Quote` core fields (price, day change/±%, open/high/low/prevClose,
      volume). Leave `ytdChangePct`/session fields null/default with a `// TODO(06)`.
    - search(query) → `List<Stock>` (US equities/ETFs only), with `logoUrl` + market cap
      from the profile endpoint (fetch/caching strategy per the 04 report).
  - Index strip data for 标普500/纳斯达克/道琼斯 via the approach the 04 report chose
    (index quotes or ETF proxies), behind the same seam.
  - API key via `--dart-define=MARKET_API_KEY`; missing/invalid key → typed failure.
  - Rate-limit friendliness per the 04 report (stagger watchlist refresh, simple
    in-memory TTL cache).
  - Riverpod providers exposing the repos.
- out:
  - No candles, no YTD, no session logic (06). No UI.

## Acceptance criteria
- [ ] Unit tests with mocked HTTP: quote mapping, search mapping, profile (logo/mcap),
      index strip source, one failure path. No real network in tests.
- [ ] Only `lib/data` imports the HTTP client.
- [ ] `format`/`analyze`/`test` clean.
