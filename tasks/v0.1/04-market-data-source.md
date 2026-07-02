# 04 — Market data source (quotes / candles / search / logos)

- **Status:** BLOCKED (needs 03)
- **Owner:** —
- **Blocked by:** 03
- **Allowed new deps:** http (or dio — pick one, note it in the PR), cached_network_image (logo caching)

## Goal
Implement `QuoteRepository` and `SearchRepository` against a free US market-data provider
(default: Finnhub free tier), fully behind the domain seams.

## Scope
- in:
  - `lib/data/market/`: provider client + JSON→domain mapping (only this layer knows the
    HTTP shapes):
    - quote(symbol) → `Quote`, including `ytdChangePct` (current vs last year's final
      close — derive from candles or the provider's metric endpoint; document the choice),
      `marketCap` (profile endpoint), and the **session + extended-hours change**
      (pre/regular/post/closed, derived from US market hours in ET; if the free tier has
      no pre/post quote, compute from the latest trade vs the regular close and document
      the limitation).
    - candles(symbol, range) for all `ChartRange`s incl. ytd.
    - search(query) → US equities/ETFs only, with `logoUrl` from the profile.
  - Index strip data: expose the three headline indices via ETF proxies (SPY/QQQ/DIA) or
    the provider's index quotes — document which, keep it behind the same seam.
  - API key via `--dart-define=MARKET_API_KEY`; missing/invalid key → typed failure.
  - Rate-limit friendliness: batch/stagger watchlist refresh; simple in-memory TTL cache.
  - Riverpod providers exposing the repos.
- out:
  - No UI. No disk cache beyond logo image caching.

## Acceptance criteria
- [ ] Unit tests with mocked HTTP cover quote (incl. ytd + market cap), candles per range,
      search mapping, and one failure path. No real network in tests.
- [ ] Only `lib/data` imports the HTTP client.
- [ ] `format`/`analyze`/`test` clean.
