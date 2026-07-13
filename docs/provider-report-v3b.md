# Provider spike report v3b (task 30) — US-only overnight session

Live probes ran from a US network on 2026-07-13 04:58:32–05:02:48 UTC
(Sunday 00:58–01:02 EDT), within the BOATS 20:00–04:00 Eastern session. They used no
broker login, API key, or credential. This report changes only task 29's
mainland-China requirement: it does not permit bypassing access controls, using an
unsupported source as though it were licensed, or adding product code.

> **Status: IN PROGRESS — owner decision required.** The Yahoo Finance streamer is a
> **technical US-only discovery**, not a product-ready data-source GO. It accepted an
> unauthenticated subscription and emitted fresh BOATS-window price events. However,
> it is an undocumented, reverse-engineered protocol with no guaranteed initial
> per-symbol snapshot and material terms/licensing risk. CNBC remained Friday-stale;
> TradingView's unauthenticated socket handshake was rejected.

## 1. Method and freshness bar

An overnight event passes the probe only when its decoded timestamp falls after
20:00 EDT and is close to the probe wall clock. BOATS is the overnight venue between
20:00 and 04:00 Eastern; the earlier strict-candidate results remain in
[provider report v3](provider-report-v3.md).

The test intentionally used a normal WebSocket handshake with no Yahoo cookie, header,
or account, then sent `{"subscribe":["AAPL","MSFT","SPY"]}` to
`wss://streamer.finance.yahoo.com/?version=2`. Received JSON envelopes carry a
base64-encoded protobuf `PricingData` payload. The field layout is independently
documented by the open-source yfinance client, including `id`, `price`, signed
millisecond `time`, `market_hours`, and price change fields. [yfinance WebSocket
reference](https://ranaroussi.github.io/yfinance/reference/api/yfinance.WebSocket.html)

## 2. Live results

| Candidate | US live result | Access and cadence | Verdict |
|---|---|---|---|
| **Yahoo Finance streamer** | Connection succeeded without credentials. A `SPY` event decoded to price **750.65997**, time **2026-07-13 05:02:28 UTC / 01:02:28 EDT**, `market_hours=4`, and change **-4.29004**—20 seconds before the probe completed. Earlier events included SPY at 00:59:50/00:59:53 EDT and MSFT at 00:59:53 EDT. This is live activity inside BOATS, unlike Friday's regular close. | Server pushes deltas, so it can exceed the app's 5/10/30/60-second polling cadence without polling. A 12-second AAPL-only subscription emitted no forced snapshot; a consumer cannot assume a first value exists until a qualifying event arrives. The wire protocol and reliability/rate contract are not publicly supported. | **Technical discovery only; not a product GO.** |
| **CNBC quote webservice** | With a browser user agent and CNBC referer, `restQuote` returned AAPL `last=315.32`, `last_timedate=07/10/26 EDT`, and `curmktstatus=POST_MKT`; no overnight field or fresh timestamp appeared. | The direct unauthenticated request is edge-protected without browser-like headers and has no documented app contract. Its Friday-stale response also fails freshness. | **NO-GO.** |
| **TradingView public data socket** | A guest WebSocket attempt to `data.tradingview.com/socket.io/websocket` for `BOATS:AAPL` failed the handshake before a quote session could be created. The earlier public scanner result was empty. | No authenticated, documented, keyless application datafeed contract was found. Do not work around the rejection. TradingView's own library docs describe an integration where the app supplies its datafeed, rather than granting one. [TradingView data integration](https://www.tradingview.com/charting-library-docs/latest/connecting_data/) | **NO-GO.** |
| **Webull mobile-app surface** | Task 29 already observed the public web endpoint disabled (`HTTP 417`) and official Webull Data API requires signed credentials. This follow-up did not attempt to impersonate or reverse-engineer the mobile app. | The official API's `overnight_required` snapshot requires an app key, signature, and entitlement, so it fails the no-key/no-account condition. [Webull Data API](https://developer.webull.com/apis/docs/market-data-api/data-api/) | **NO-GO.** |

## 3. What the Yahoo result proves—and does not prove

The result proves a US-network, no-account WebSocket can receive fresh nighttime
events today. It does **not** prove that Yahoo offers a supported or redistributable
market-data API, that every watched symbol has an immediate snapshot, that the service
will remain available, or that its data may be embedded in this app.

The source is especially unsuitable to silently promote into a product: Yahoo's public
terms prohibit using its data to create a mobile application or aggregated data source
that competes with or materially substitutes for its services or data providers, absent
express permission. That text warrants an owner/legal rights decision before any
implementation; this is not legal advice. [Yahoo Terms of Service](https://legal.yahoo.com/us/en/yahoo/terms/otos/index.html?ncid=mbr_idnedulnk00000001)

Its delta-only behavior is a separate functional risk. The probe received no AAPL
event in a 12-second AAPL-only subscription; that may simply mean no qualifying trade,
but it rules out treating subscription as a guaranteed latest-quote request. An app
would need an explicitly approved freshness rule, a stale/no-value state, reconnect
backoff, and a source whose usage rights support the feature.

## 4. Account-backed fallback and price

No paid fallback is required to explain the technical result, but the lowest published
supported route found is **Alpaca** if the owner later waives the no-account/no-key
constraint. Its free Basic plan requires API credentials and offers the derived
`overnight` feed for real-time indicative latest quotes; exact BOATS latest/historical
data is on Algo Trader Plus at **$99/month**. Both are outside this task's constraint
because authentication and an account are required. [Alpaca 24/5 market-data
plans](https://docs.alpaca.markets/us/docs/245-trading-for-trading-api), [Alpaca market
data pricing](https://docs.alpaca.markets/us/docs/about-market-data-api)

## 5. Recommendation and future graceful degradation

**NO-GO for product implementation under the present source rules.** Record Yahoo as
the first technically successful free/keyless US-only probe, but do not integrate an
uncontracted feed with unresolved rights and no snapshot guarantee. The owner may
either explicitly authorize a rights-reviewed, timeboxed Yahoo experiment, or waive
the no-account rule and select a supported provider. Either path needs a new,
implementation-specific task and owner sign-off.

If a future task is authorized, its non-negotiable behavior in an unreachable region
(including mainland China) is:

1. Attempt no overnight fetch outside the 20:00–04:00 ET window.
2. Treat connection failure, handshake rejection, timeout, malformed event, or stale
   event as **no overnight value**—not as an error and not as a fallback regular quote.
3. Leave regular/pre/post data and cache behavior intact; show no overnight session
   indicator when no fresh overnight value exists.
4. Use bounded reconnect backoff with no retry storm, telemetry, or user-visible error.

These are requirements for a later approved implementation, not design or code added
by this report.
