# Provider spike report v3 (task 29) — US overnight session

Live probes: 2026-07-13 03:28:52–03:29:05 UTC (Sunday 23:28–23:29 EDT), inside the
BOATS 20:00–04:00 Eastern session. Probes were plain `curl` from the US, without a
broker login or API key. This is report-only: no app code or fixtures were added.

> **Status: IN PROGRESS — owner decision required.** **No eligible free,
> documented, cross-region overnight quote source was found.** Tencent/Sina are
> production-ready for regular/pre/post quotes but were frozen at Friday's close
> during BOATS. Sources that model overnight data require credentials, an account,
> paid/non-display entitlement, or unsupported web scraping.

## 1. Method and baseline

A candidate passes freshness only when its live response has a post-20:00-EDT
timestamp and an overnight price; documentation or a logged-in broker display alone
does not pass. BOATS runs 20:00–04:00 Eastern, Sunday–Thursday, and Webull says its
overnight executions/quotes are provided by BOATS. [Webull overnight hours](https://www.webull.com/help/faq/10988-All-about-overnight-trading%3D)

## 2. Results

| Candidate | Live result in the BOATS window | Access/cadence and China result | Verdict |
|---|---|---|---|
| **Tencent** | `qt.gtimg.cn/q=usAAPL,usMSFT,usSPY`: HTTP 200, 0.76 s. AAPL price `315.32`; timestamp `2026-07-10 16:00:01` Eastern. | No key; v2 already sustained 20 rapid calls. China-safe in v2, but no overnight field or fresh price. | **NO-GO** for overnight; retain for regular quotes. |
| **Sina `gb_`** | Referer-enabled batch: HTTP 200, 0.71 s. AAPL price `315.3200`; ext price `314.9700`; ext time `Jul 10 07:59PM EDT`. | No key; v2 rate and China evidence apply. Its fields 21–25 stop after post-market, about 55.5 h stale here. | **NO-GO**; retain for pre/post chip. |
| **Nasdaq public quote** | HTTP 200, 2.12 s. `lastSalePrice=$315.32`, `isRealTime=false`, `marketStatus=Closed`. | No key, but no overnight/minute data. Mainland reachability not verified. | **NO-GO**. |
| **Eastmoney push2** | HTTP 302 to `push2delay.eastmoney.com`; following it timed out after 15 s. | No data body/freshness proof; cannot meet locked polling cadence. | **NO-GO**. |
| **Webull** | Unauthenticated ticker page was Friday-stale (`tradeTime=2026-07-10T23:59:58.894+0000`, `close=315.32`); former `tickerRealTime/get` returned HTTP 417 `API_DISABLED`. | Official snapshot has `overnight_required`, but needs signed app credentials and a separate OpenAPI non-display entitlement. Mainland suitability unverified. | **NO-GO**. |
| **Futu / moomoo** | Direct symbol URLs redirected to generic `/quote`, with no unauthenticated quote payload. | Supported schema includes overnight price/high/low/volume/turnover/change and `OVERNIGHT`, but API uses local OpenD and can require an account/quotation card. | **NO-GO** under free/no-account rule. |
| **Tiger** | Public ticker page loaded but gave no documented unauthenticated quote endpoint or BOATS value. | Official SDK is free only after opening and funding a Tiger account. | **NO-GO**. |
| **Blue Ocean / TradingView** | `BOATS:AAPL` resolves on the TradingView symbol page; public scanner query returned `totalCount:0,data:[]`. Blue Ocean's site offered no retail quote API. | Real-time chart display is announced, but no supported keyless REST/WebSocket polling contract; China availability is not safe to assume. | **NO-GO**. |

## 3. Evidence and interpretation

### Tencent and Sina: definitive negative

The existing China-safe providers agree on Friday's $315.32 AAPL close. Sina's last
extended value is $314.97 at Friday 19:59 EDT; Tencent's last trade is Friday
16:00:01. Neither updated while BOATS was open Sunday. A parser change cannot create
the missing overnight feed. Existing field maps, referer/rate measurements, and China
evidence remain in [provider report v2](provider-report-v2.md).

### Webull: correct product capability, wrong access model

Webull's documented Data API has an `overnight_required` snapshot option but requires
signed `x-app-key`, timestamp, nonce, and signature headers. Its market-data overview
says US stock/ETF overnight access needs the separate OpenAPI non-display entitlement;
retail app subscriptions do not transfer. [Snapshot authentication](https://developer.webull.com/apis/docs/market-data-api/data-api/), [market-data permissions](https://developer.webull.com/apis/docs/market-data-api/overview/).
The disabled browser endpoint is not an acceptable product integration.

### Futu/moomoo and Tiger: fields exist, free app access does not

Futu documents `overnight_price`, high/low, volume, turnover, and change fields, plus
the `OVERNIGHT` session. [Futu quote fields](https://openapi.futunn.com/futu-api-doc/en/quote/get-stock-quote.html), [sessions and rights](https://openapi.futunn.com/futu-api-doc/quote/quote.html).
Its own OpenAPI material says a quotation card may be required. Tiger's supported SDK
says access is free only after an account is opened and funded. [Tiger SDK](https://github.com/tigerfintech/openapi-python-sdk).

### BOATS / TradingView: discovery surface, not a data contract

Blue Ocean says its BOATS symbols are visible in TradingView in real time for analysis.
[TradingView announcement](https://www.blueocean-tech.io/2025/08/01/tradingview-blog-access-markets-whenever-blue-ocean-ats-data-now-on-tradingview/)
does not grant a stable polling API; Blue Ocean describes quote data as subscriber
data in its [FAQ](https://www.blueocean-tech.io/wp-content/uploads/2025/01/Blue-Ocean-Technologies-FAQ_compressed-1.pdf).
The live scanner failure and no documented API make chart scraping unsuitable at
5/10/30/60-second product cadence.

## 4. Recommendation

**NO-GO: do not add free scraped overnight data in v0.4.** The only proven
China-safe feeds are stale in the BOATS window. The sources with overnight schemas or
BOATS executions fail the no-key/no-account/no-paid-entitlement requirement.

The owner can either acquire/approve a licensed or account-backed BOATS source (then
run a credentialed freshness/rate and mainland-reachability spike), keep the present
closed-session behavior, or explicitly authorize a separate unsupported scraping
experiment. The last option must not be represented as reliable market data.

## 5. Implications of a future approved source (not a design)

`MarketSession` currently has only `pre`, `regular`, `post`, and `closed`; live
refresh is only 04:00–20:00 Eastern. A later source needs an `overnight` state,
source-price/timestamp semantics, refresh/cache rules, and localization. It must not
reuse Sina pre/post fields by assumption.

The current 1D chart reserves 15% / 70% / 15% for pre / regular / post. Overnight
20:00–04:00 crosses calendar dates, so it cannot simply be inserted into the existing
day axis. Trading-day boundary, zones, baseline, and minute-series treatment are
owner decisions; this report intentionally does not design them.

## 6. Limits

- Probes originated in the US. Tencent/Sina mainland evidence is v2's accepted result;
  failed candidates received no separate mainland test.
- A broker UI showing BOATS data is not evidence of a redistributable unattended feed.
- The in-app browser was unavailable in this headless ticker session; TradingView was
  tested through its public HTTP symbol page and scanner. The absence of a supported
  polling contract is independently decisive.
