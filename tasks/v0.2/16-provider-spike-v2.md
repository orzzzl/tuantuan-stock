# 16 — Provider spike v2: Tencent/Sina as the primary data source

- **Status:** DONE (PR #20; owner signed off 2026-07-08: §12 risks accepted, "All" range pinned to Tencent month/2007+)
- **Owner:** —
- **Blocked by:** —
- **Allowed new deps:** none (spike is curl + docs + fixtures; the GBK decoder dep is
  *chosen* here, *added* in 17)

## Why

Two field reports (owner, 2026-07-07):

1. **Mainland China: the app cannot connect at all.** Everything rides on Yahoo
   (`query1.finance.yahoo.com`, `fc.yahoo.com`) plus `google.com/s2/favicons` and
   google_fonts runtime fetch — all GFW-blocked. Not a bug; a provider decision.
2. **US: first list paint takes ~1 minute.** Partly our request storm (see 19/20),
   partly Yahoo's crumb dance and 429 backoffs.

Owner decision: switch to **Tencent + Sina as the primary source everywhere** (both are
reachable in China AND fast from the US), not as a China-only fallback tier. "Dual
source" means each feature is pinned to whichever of the two serves it best — NOT
runtime failover.

## Goal

A `docs/provider-report-v2.md` that pins every data need to a concrete
Tencent/Sina endpoint with a field-by-field mapping to our domain models, plus live
captured fixtures under `test/fixtures/` for the mapping tests in 17/18. Owner signs
off on the report before 17/18 start (same gate as the 04 report).

## Verified head start (probed from the US, 2026-07-07, market closed)

All four endpoint families work; exact findings to fold into the report:

- **Sina batch quote** — `GET https://hq.sinajs.cn/list=gb_aapl,gb_msft`.
  **Requires `Referer: https://finance.sina.com.cn`**; body is GBK. Rich: zh name,
  price, change %, local timestamp, change, open, high, low, 52wk hi/lo, volume,
  market cap, PE, **explicit pre/post-market price + % + EDT timestamps** ("Jul 07
  07:59PM EDT" / "Jul 07 04:00PM EDT"), prev close. Exact positional field table TBD.
- **Tencent batch quote** — `GET https://qt.gtimg.cn/q=usAAPL,usMSFT` (note: **no
  exchange suffix in the query**; `q=usAAPL.OQ` returns `v_pv_none_match`). GBK,
  `~`-separated. Has zh name, **full code `AAPL.OQ`** (the exchange suffix needed for
  the kline endpoint), price, prev close, open, volume, change/%, high/low, currency,
  market cap, PE, **English name "Apple Inc."**, 52wk hi/lo.
- **Tencent kline** —
  `GET https://web.ifzq.gtimg.cn/appstock/app/usfqkline/get?param=usAAPL.OQ,day,,,320,qfq`
  → JSON daily OHLCV, count-limited. `week`/`month` granularities to verify. Needs the
  `.OQ`/`.N` suffix (obtainable from the Tencent quote).
- **Sina 5-min bars** —
  `GET https://stock.finance.sina.com.cn/usstock/api/jsonp.php/cb/US_MinKService.getMinK?symbol=aapl&type=5`
  (Referer required) → JSONP, multi-day history of 5m OHLCV.
- **Sina daily** — same base, `US_MinKService.getDailyK?symbol=aapl` → full history
  since IPO (AAPL back to 1984). Serves 5Y/All ranges; payload is heavy — measure.
- **Search** — `GET https://suggest3.sinajs.cn/suggest/type=41&key=apple` (Referer,
  GBK) returns US matches incl. tickers.
- **Indices** — Tencent `q=usDJI,usIXIC` works (full quote format). **Sina
  `int_dji/int_nasdaq/int_sp500` respond but disagreed with Tencent by ~13% the same
  minute — presumed badly stale; do not use without a freshness proof.**

## Open questions the report must answer

- [ ] **Freshness/delay of every chosen endpoint, measured during US market hours**
      (Tencent's kline response embeds a `"delay"` marker — is the quote delayed?).
      Cross-check Tencent vs Sina vs a known-live reference. A price viewer cannot
      ship on quietly-delayed quotes without the owner knowing.
- [ ] Exact positional field maps for Sina `gb_` and Tencent `q=` payloads (all fields
      our `Quote`/`Stock` need, incl. `marketState`-equivalent for the mandatory
      盘前/盘后 session chips — derive from the pre/post timestamps if needed).
- [ ] S&P 500 index symbol on Tencent (`usINX`? `.INX`?) — ^GSPC/^IXIC/^DJI equivalents.
- [ ] Do the 5m bars include extended hours, and how do we slice "today" for the day
      chart (which needs the gap open)?
- [ ] Batch size limits and rate-limit behavior of `hq.sinajs.cn` / `qt.gtimg.cn`
      (do we still need a serialized queue at all? Target: NO global serialization).
- [ ] GBK decoding dep for Dart: `fast_gbk` vs `charset_converter` — pick one, justify.
- [ ] JSONP/`var x=...` stripping strategy per endpoint.
- [ ] Symbol mapping table: app symbol `AAPL` ↔ Sina `gb_aapl` ↔ Tencent `usAAPL` ↔
      kline `usAAPL.OQ`; and how BRK.B-style dotted tickers map on each.
- [ ] Logo strategy reachable from China (feeds 21): bundled symbol→domain map for the
      top ~N US tickers + ticker-ring fallback? An accessible favicon service? Pick a
      recommendation.

## Scope

- in: the report; live fixture captures (this also retires the v0.1 note about
  synthetic candle fixtures, PR #13); a go/no-go recommendation per feature.
- out: any `lib/` code change (17/18 do that).

## Acceptance criteria

- [ ] `docs/provider-report-v2.md` answers every open question above with evidence
      (captured payloads, timestamps of freshness probes).
- [ ] Fixtures for: Sina batch quote (multi-symbol), Tencent batch quote, Tencent
      daily/weekly/monthly kline, Sina 5m bars, Sina daily history, search suggest,
      index quotes — captured live, GBK preserved as bytes where relevant.
- [ ] Owner has signed off on the per-feature provider pinning before 17/18 start.
