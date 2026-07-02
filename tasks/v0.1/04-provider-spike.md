# 04 — Provider spike: validate the market-data source

- **Status:** IN PROGRESS
- **Owner:** Claude
- **Blocked by:** — (no app code; curl / throwaway scripts only)
- **Allowed new deps:** none (nothing lands in `lib/`)

## Goal
De-risk the data layer **before** building it. The plan assumes Finnhub's free tier, but
free access to US stock candles is in doubt (see finnhubio/Finnhub-API#546 — free keys
reportedly get "no access" on `/stock/candle`). Verify what a free key can actually do,
and pick the provider plan tasks 05/06 will implement.

## Scope
- in:
  - With a fresh free Finnhub key, exercise and record (curl output snippets):
    - `/quote` (price, day change, prev close) — incl. behavior outside regular hours
      (does it move pre/post? is there a timestamp to derive the session from?)
    - `/stock/profile2` (logo URL, market cap)
    - `/search` (US equities/ETFs filtering)
    - `/stock/candle` — intraday resolution for 1日, daily for ≥1年 (the known risk)
  - Answer the data questions the app needs:
    1. Can we draw the 1日 line (intraday series)?
    2. Can we get daily candles ≥ 1 year (needed for 1周…1年 and the YTD baseline =
       last year's final close)?
    3. Can we tell pre/regular/post session and get an extended-hours change?
    4. Index strip: real index quotes or ETF proxies (SPY/QQQ/DIA)?
    5. Rate limits: is one refresh of a ~10-symbol watchlist feasible?
  - If Finnhub free can't cover candles: evaluate fallbacks (e.g. Alpha Vantage free,
    Twelve Data free, Stooq daily CSV) and propose a plan — possibly mixed (Finnhub for
    quote/search/logo + X for candles) — behind the same domain seams.
  - Deliverable: `docs/provider-report.md` with findings + a concrete recommendation,
    plus (if needed) proposed edits to tasks 05/06 assumptions.
- out:
  - No code in `lib/`, no dependency changes, no DESIGN.md edits (owner reviews the
    report first).

## Acceptance criteria
- [ ] `docs/provider-report.md` answers questions 1–5 with real responses captured.
- [ ] A clear provider recommendation (single or mixed) with rate-limit math.
- [ ] Owner has signed off on the recommendation before 05/06 start.
