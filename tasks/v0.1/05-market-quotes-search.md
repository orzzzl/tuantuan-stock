# 05 — Market data: quotes, search, profile (logo / market cap)

- **Status:** BLOCKED (needs 03; 04 is DONE — provider decided: Yahoo, see
  docs/provider-report.md)
- **Owner:** —
- **Blocked by:** 03
- **Allowed new deps:** http (or dio — per the 04 report; note it in the PR)

## Goal
Implement the quote/search/profile half of the data layer against **Yahoo's unofficial
API** (the 04 decision), behind the domain seams. Candles/YTD/session come in 06.

## Scope
- in:
  - `lib/data/market/`: provider client + JSON→domain mapping (only this layer knows the
    HTTP shapes):
    - quote(symbols) → `Quote` core fields via **batched v7 `quote`** (price, day
      change/±%, open/high/low/prevClose, volume, marketCap). Leave `ytdChangePct` and
      session fields null/default with a `// TODO(06)`.
    - search(query) → `List<Stock>` via v1 `search`, filtered to US equities/ETFs;
      `logoUrl` from v10 `quoteSummary` `assetProfile.website` → favicon URL, cached.
  - The **cookie+crumb helper** for v7/v10 (fetch once, cache, refresh on 401) — see the
    report's "crumb dance" section; typed failure when the crumb flow itself breaks.
  - Index strip via real `^GSPC`/`^IXIC`/`^DJI` quotes, behind the same seam.
  - **No API key** (keyless provider). Rate-limit hygiene: browser UA, batched calls,
    minimum-interval guard, backoff on HTTP 429/999; measure real responses while
    implementing (the spike did not stress-test).
  - Riverpod providers exposing the repos.
- out:
  - No candles, no YTD, no session logic (06). No UI.

## Acceptance criteria
- [ ] Unit tests with mocked HTTP: quote mapping, search mapping, profile (logo/mcap),
      index strip source, crumb refresh-on-401, one failure path. No real network in tests.
- [ ] Only `lib/data` imports the HTTP client.
- [ ] `format`/`analyze`/`test` clean.
