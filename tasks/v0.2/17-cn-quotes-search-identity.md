# 17 — Tencent/Sina data layer: quotes, search, identity

- **Status:** BLOCKED (needs 16 sign-off)
- **Owner:** —
- **Blocked by:** 16
- **Allowed new deps:** the GBK decoder chosen in the 16 report (`fast_gbk` or
  `charset_converter`)

## Goal

Reimplement `QuoteRepository.quote/quotes`, `SearchRepository`, and `StockRepository`
(identity: names, exchange code) against the Tencent/Sina endpoints pinned in
`docs/provider-report-v2.md`, behind the existing domain seams. Charts/YTD/session
baselines move in 18. Yahoo code stays in place until 23 removes it.

## Scope

- in:
  - `lib/data/market/`: a low-level CN client (GBK decode, JSONP/`var` stripping,
    required Referer headers, browser UA) + one repository implementation per seam.
  - **Fail fast**: every request has a hard timeout (~8s). No cookie/crumb dance, no
    auth state.
  - **No global request serialization** unless the 16 rate-limit findings force it —
    the v0.1 YahooClient's serialized queue + 400ms min-interval is one of the two
    causes of the 60s first paint. Batched quotes must be ONE request per refresh.
  - Session mapping: `marketState` equivalent + extended-hours change % per the 16
    field map, so the mandatory 盘前/盘后 chips keep working (`Quote.session`,
    `Quote.extChangePct`).
  - Symbol mapping helper (app `AAPL` ↔ `gb_aapl` ↔ `usAAPL` ↔ `usAAPL.OQ`) in one
    place, unit-tested, incl. dotted tickers (BRK.B) per the 16 table.
  - `Stock` gains an optional zh display name (both providers return one); watchlist /
    detail / search titles use it when the app locale is zh, ticker fallback unchanged.
  - Index strip via the Tencent index symbols pinned in 16.
  - Riverpod wiring in `market_providers.dart` switches these three seams to the CN
    implementations.
- out:
  - `chart()` / YTD baselines / logo fetching (18 and 21). While 18 is pending the
    provider may keep delegating `chart()` to the Yahoo implementation — mark
    `// TODO(18)`.

## Acceptance criteria

- [ ] Unit tests against the 16 fixtures (GBK bytes in, domain models out): quote
      mapping incl. pre/post session, search mapping, identity/zh-name mapping, symbol
      mapping table, index strip, one malformed-payload failure path. No real network.
- [ ] `formatPercent` convention audited: our formatter expects FRACTIONS — document
      and test what the CN payloads deliver (the Yahoo percent-points mismatch was a
      known footgun).
- [ ] One watchlist refresh = one quote request (assert via the mocked client).
- [ ] Only `lib/data` knows the HTTP shapes; `format`/`analyze`/`test` clean.
