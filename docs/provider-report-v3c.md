# Provider spike report v3c (task 31) — Alpaca Basic derived overnight feed

Live probes ran from a US network on **2026-07-13 06:53:54–06:54:11 UTC**
(**02:53:54–02:54:11 EDT**, Monday), inside Alpaca's documented BOATS overnight
window of Sunday–Thursday 20:00–04:00 ET. This report uses the owner-provisioned
Alpaca Basic credentials only at runtime. No credential value, account identifier, or
authentication header is recorded here, in git, PR text, or the activity journal.

> **Status: RESEARCH GO — owner approved 2026-07-13.** Alpaca Basic's
> documented `overnight` feed returned fresh, on-demand indicative quotes for every
> sampled symbol and a one-request batch result. It is a supported, account-backed
> research candidate—not authorization to add product code, retain credentials, or
> change task 30's no-data/no-error behavior in an unreachable region.

## 1. Contract examined

Alpaca documents the overnight session as 20:00–04:00 ET, with BOATS as the
underlying ATS. Its free plan exposes the derived `overnight` feed for latest bars,
real-time indicative latest quotes, 15-minute-delayed latest trades, and snapshots;
the direct `boats` latest feed is an Algo Trader Plus entitlement.
[Alpaca 24/5 trading](https://docs.alpaca.markets/us/docs/245-trading-for-trading-api)

The tested REST endpoints are documented to accept comma-separated `symbols` and
`feed=overnight`: [latest quotes](https://docs.alpaca.markets/us/reference/stocklatestquotes-1),
[latest trades](https://docs.alpaca.markets/us/v1.4.2/reference/stocklatesttrades-1),
and [snapshots](https://docs.alpaca.markets/us/reference/stocksnapshots-1). A REST
request returns the current stored value immediately; it is not a delta-only stream.

## 2. Live BOATS-window evidence

At 06:53:54 UTC, one `GET /v2/stocks/quotes/latest` request with
`symbols=AAPL,MSFT,SPY,TSLA,QQQ&feed=overnight` returned HTTP 200 and all five
symbols. Each quote carried bid/ask price (`bp`/`ap`), sizes (`bs`/`as`), venue codes
(`bx`/`ax`), conditions (`c`), timestamp (`t`), and tape (`z`). `B` was returned for
the bid/ask venues and `N` for tape in this sample.

| Symbol | Quote timestamp (UTC) | Bid / ask | Freshness at response | Result |
|---|---:|---:|---:|---|
| AAPL | 06:53:53.304512221 | 315.74 / 315.94 | ~1 s | Fresh |
| MSFT | 06:53:50.306467793 | 386.31 / 386.53 | ~4 s | Fresh |
| SPY | 06:53:54.723490338 | 750.64 / 751.08 | ~0 s | Fresh |
| TSLA | 06:53:53.032969489 | 399.20 / 399.62 | ~1 s | Fresh |
| QQQ | 06:53:54.463725268 | 715.48 / 716.16 | ~0 s | Fresh |

The matching batch latest-trades response was intentionally older: its five
timestamps were 06:37:28–06:38:50 UTC, about 15–16 minutes before the request. That
matches the Basic-plan 15-minute trade delay and must not be used as the overnight
freshness signal. The batch snapshot returned each symbol's `latestQuote`,
`latestTrade`, `minuteBar`, `dailyBar`, and `prevDailyBar`; its `latestQuote` values
matched the quote endpoint at the same probe instant. `GET .../bars/latest` also
returned derived overnight bars, though the latest bars lagged the quote sample and
are supplementary only.

The entitlement boundary was independently observed: the identical latest-quote
request with `feed=boats` returned HTTP 403, `subscription does not permit querying
BOATS data`. This is expected for Basic and confirms that the observed real-time
quotes were the documented derived `overnight` feed, not a mistaken direct-BOATS
claim.

### Snapshot-on-request and update behavior

The REST latest-quote request supplied a full batch immediately on every call—unlike
task 30's delta-only Yahoo experiment. The venue only changes a quote when market
data changes, so an immediate response is not a guarantee that every symbol timestamp
will advance on every polling tick:

| Probe | Wall time (UTC) | Observed result |
|---|---:|---|
| Initial batch | 06:53:54 | All five symbols fresh (0–4 s old). |
| +5 s batch | 06:54:00–01 | SPY, TSLA, and QQQ advanced to the request time; AAPL and MSFT retained their prior timestamp. |
| +15 s batch | 06:54:11 | All five had advanced since the initial batch; newest timestamps were 06:54:05–11. |

No owner-provided independent broker-app quote reference was available during this
probe. Therefore this report does not claim a cross-broker price match; the API's own
timestamp freshness and the documented Basic contract are the recorded evidence.

## 3. Cadence, batch, and streaming limits

The live response included `X-RateLimit-Limit: 200` and
`X-RateLimit-Remaining: 197` after the early sample requests. No request in this
small probe received HTTP 429. One whole-watchlist batch request per tick is enough
for the tested five symbols, so the locked polling schedules consume:

| Poll interval | Batch requests/min | Relation to observed 200/min limit |
|---|---:|---|
| 5 s | 12 | Within limit |
| 10 s | 6 | Within limit |
| 30 s | 2 | Within limit |
| 60 s | 1 | Within limit |

This proves the planned request shape, not an endurance or saturation guarantee.
Production work, if separately authorized, must read the rate-limit headers and
treat HTTP 429 or transport failure as no value. The documented endpoint describes
HTTP 429 and its `X-RateLimit-*` headers as the rate-limit contract.
[Latest quotes API](https://docs.alpaca.markets/us/reference/stocklatestquotes-1)

WebSocket availability on Basic was not needed to satisfy the locked polling
cadences and was not probed. Do not infer a Basic streaming entitlement from this REST
result; any future websocket choice requires a scoped, documented follow-up.

## 4. Session and product constraints

- Classify the overnight window in **America/New_York** time, not from a UTC date
  alone. Alpaca documents overnight as 20:00–04:00 ET; a session spanning midnight
  must not be split merely because the UTC calendar date changes.
- Use `latestQuote.t` as the real-time indicative freshness field. Basic
  `latestTrade.t` is expected to be delayed and is not an equivalent fallback.
- Regular/pre/post Alpaca behavior was not separately sampled here; Tencent/Sina
  remain the primary sources for those sessions, and their China-reachability
  requirement is unchanged.
- This US-network probe supplies **no mainland-China reachability evidence**. If the
  approved source is unavailable there—or returns a stale timestamp, malformed
  response, rate limit, or transport error—the future feature must yield **no
  overnight value and no user-visible error**, exactly as task 30 requires.

## 5. Recommendation and owner decisions

The research result is a **conditional GO for a future, separately approved
implementation task**: Alpaca Basic is a documented, credentialed way to obtain an
immediate batch snapshot of real-time indicative overnight quotes during BOATS. It is
not a replacement for the regular-session sources and does not establish China
availability, legal distribution rights beyond the selected plan, websocket support,
or a product design.

The owner approved both requested decisions on 2026-07-13:

1. retaining the Alpaca Basic account/credential model for the app's read-only data
   path; and
2. an implementation-specific validation of regional reachability, operational
   rate-limit handling, and the unchanged no-value/no-error degradation rule.

This research approval does not itself authorize app code, dependencies, UI, chart
behavior, or a credential-storage mechanism; those need a separately specified
implementation task.
