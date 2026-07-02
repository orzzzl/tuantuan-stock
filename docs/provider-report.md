# Provider spike report (task 04) — rev 2

Date: 2026-07-01. Probes run with plain `curl` from this machine; response snippets are
captured verbatim (trimmed). No app code was written for this task. Rev 2 addresses the
cross-review on PR #1 (evidence for all ranges, honest ToS/rate-limit framing, explicit
spec deviation).

## TL;DR recommendation

**Recommend Yahoo Finance's unofficial API as the provider — with one honest caveat the
owner must accept (see "Legal / ToS risk").** It is keyless, answers every data question
the app has, and is batch-friendly. The compliant alternative is Finnhub with a
registered free key, whose candle access could NOT be validated in this spike (see
"Deviation from the spec").

## Deviation from the spec (needs owner decision)

The task said "with a fresh free Finnhub key". Creating one requires an account signup,
which the agent cannot do on the owner's behalf. Keyless probing confirms only that a key
is mandatory (`{"error":"Please use an API key."}`); the free-tier candle doubt
(finnhubio/Finnhub-API#546) remains **untested**. Options:

- **(a)** Owner accepts the Yahoo recommendation → the Finnhub question is moot.
- **(b)** Owner registers a free key (2 minutes at finnhub.io) → I re-run the candle
  probes and amend this report before 05/06 start.

## The five questions

### 1. Can we draw the 1日 line (intraday series)? — YES

`GET query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1d&interval=5m&includePrePost=true`
(no key, browser `User-Agent` required) returns 5-minute bars **including pre/post
sessions** (observed: first bar 04:00 ET, last 19:59 ET) plus a rich `meta`:

```json
"meta": {"regularMarketPrice":294.38, "chartPreviousClose":289.36,
         "hasPrePostMarketData":true, "timezone":"EDT",
         "currentTradingPeriod":{"pre":{...},"regular":{...},"post":{...}}, ...}
```

`currentTradingPeriod` gives the exact pre/regular/post boundaries for session shading
and gap-open rendering.

### 2. Daily candles ≥ 1 year (and the per-range baseline)? — YES, verified per range

`chartPreviousClose` is the close of the last trading day **before the requested
window** — i.e. exactly the waterline baseline — verified across ranges, not assumed
from one example:

| range | first bar    | chartPreviousClose |
|-------|--------------|--------------------|
| 5d    | 2026-06-25   | 293.08             |
| 1mo   | 2026-06-02   | 306.31             |
| 3mo   | 2026-04-02   | 255.63             |
| ytd   | 2026-01-02   | 271.86 (= last year's final close) |
| 1y    | 2025-07-02   | 207.82             |

Cross-check: the 3mo daily series shows close(2026-06-01) = **306.31**, matching the 1mo
`chartPreviousClose` exactly (2026-06-01 is the trading day before the 1mo window's
first bar 2026-06-02). The YTD baseline therefore needs no manual year-boundary math.

### 3. Session labels (盘前/盘后) and extended-hours change? — YES, with null-handling rules

`GET .../v7/finance/quote?symbols=AAPL,NVDA&crumb=<crumb>` (crumb note below), captured
outside market hours:

```json
{"symbol":"AAPL","marketState":"PREPRE","regularMarketChangePercent":1.73,
 "postMarketChangePercent":0.088,"preMarketChangePercent":null,
 "marketCap":4323663937536,"regularMarketPreviousClose":289.36}
```

`marketState` enumerates PRE / REGULAR / POST / PREPRE / POSTPOST / CLOSED. **Important
semantics for the implementer (do not assume all fields are always set):** in the
captured PREPRE state (overnight, after post-close and before pre-open),
`preMarketChangePercent` is `null` while `postMarketChangePercent` still carries the
*previous* post-session's move. Mapping rule for tasks 05/06: pick the ext-change field
matching the state (PRE → pre field; POST/POSTPOST/PREPRE → post field), treat `null` as
"no extended data", and **capture real PRE/POST/CLOSED fixtures during implementation**
— this spike observed only the PREPRE state live. One batched call covers all watchlist
symbols (`symbols=` list), and `marketCap` rides along.

### 4. Index strip: real indices or ETF proxies? — REAL INDICES

`^GSPC`, `^IXIC`, `^DJI` work directly on the keyless chart endpoint:

```json
{"sym":"^GSPC","price":7483.23,"prev":7499.36}
{"sym":"^IXIC","price":26040.03,"prev":26213.72}
{"sym":"^DJI","price":52305.24,"prev":52319.20}
```

No ETF proxies needed; DESIGN.md's proxy fallback can be dropped.

### 5. Rate limits: is a ~10-symbol watchlist refresh feasible? — Shape is favorable; UNVERIFIED under load

Yahoo publishes no limits and this spike did **not** stress-test throttling — treat
capacity as unguaranteed. What the shape gives us:

- Watchlist refresh = **1 batched v7 quote request** (all symbols + three indices).
- Detail view = 1 chart request per range selection.
- Logos/profile = 1 `quoteSummary` call per symbol, cached forever locally.

Plan for 05: gentle cadence (refresh on open + pull-to-refresh, minimum-interval guard),
exponential backoff on HTTP 429/999, and **measure real responses during implementation**
rather than trusting this spike's optimism.

## Search — YES (keyless)

`GET .../v1/finance/search?q=apple&quotesCount=5` returns symbol, shortname, exchange
(`NMS`, `NYQ`, …) and `quoteType` (`EQUITY`/`ETF`) — enough to filter to US
equities/ETFs per DESIGN.md.

## Logos

`quoteSummary` module `assetProfile` returns the company `website`
(`https://www.apple.com`); the favicon pattern proven in the mockups
(`google.com/s2/favicons?domain=<domain>&sz=128`) turns that into a logo, cached
locally. Ticker-ring fallback per DESIGN.md when either hop fails.

## The crumb dance (a real dependency risk, not a cosmetic quirk)

`v8 chart` and `v1 search` are fully open (browser UA required). `v7 quote` and
`v10 quoteSummary` require a cookie + crumb:

1. `GET https://fc.yahoo.com` → sets a cookie.
2. `GET .../v1/test/getcrumb` with that cookie → short crumb string.
3. Append `&crumb=...` with the same cookie jar.

Verified working end-to-end today (marketCap `4.32T`, website returned). ~30 lines to
implement (fetch once, cache, refresh on 401) — but note this scheme was *introduced* by
Yahoo in 2023 as an access-tightening measure and can change again without notice; it is
part of the operational risk below, not just an implementation detail. Fallback if the
crumb scheme breaks: the keyless v8 chart meta still carries price/prevClose (enough for
a degraded watchlist without mcap/session tags).

## Legal / ToS risk (owner must accept explicitly)

Yahoo's Terms of Service restrict automated access/collection without prior permission
(legal.yahoo.com → "otos"). The unofficial API is nonetheless the de-facto backbone of
many open-source tools (yfinance et al.), and this is a personal, single-user, look-only
app with polite call volumes — but strictly speaking it is **unsanctioned use**. The
compliant alternative is a keyed provider (Finnhub free tier — pending option (b) above).
Sign-off on this trade-off is part of the owner gate for this report.

## What else was ruled out

- **Stooq** (keyless daily-CSV backup candidate) now sits behind a JavaScript
  proof-of-work anti-bot wall — not viable, scratched.

## Risk & mitigation summary

Unofficial API: endpoints, crumb scheme, or UA requirements can change without notice.
Mitigations: the domain seams keep the blast radius inside `lib/data` (provider swap is a
data-layer-only change by design); degraded keyless-chart fallback for quotes; fallback
providers if Yahoo breaks: Finnhub free (needs owner key + re-spike for candles) or
Alpha Vantage free (25 req/day — candles only). Client hygiene: browser UA, batched
calls, minimum-interval guard, backoff on 429/999.

## Proposed follow-ups (after owner sign-off, separate PRs)

1. DESIGN.md data section: replace the Finnhub-candidate paragraph with Yahoo (keyless,
   crumb note, real indices — drop the ETF-proxy sentence and `MARKET_API_KEY`), and
   record the accepted ToS trade-off.
2. Task 05: implement against v7 quote (batched) + v1 search + quoteSummary
   (profile/logo/mcap) with the crumb helper and the null-handling session rules above;
   no API key plumbing.
3. Task 06: v8 chart for all ranges; baseline = `chartPreviousClose` per range; session
   from `marketState` + the state-matched ext-change field.
