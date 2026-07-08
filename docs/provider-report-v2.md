# Provider spike report v2 (task 16) — Tencent + Sina as the primary source

Date: initial probes 2026-07-08 05:15–05:25 UTC (US market closed); pre-market,
regular-hours, and post-market probes 2026-07-08 04:12 / 10:04–14:25 / 16:15 EDT.
Probes run with plain `curl` from the US; raw payloads are committed under
`test/fixtures/provider_v2/` (GBK preserved as bytes). No `lib/` code was written for
this task.

> **Status: COMPLETE — ready for owner sign-off.** The market-hours freshness probe
> ran 2026-07-08 during the US regular session (§2.2): **both Tencent and Sina US
> quotes are real-time** (median price-track lag 0 s vs a live Yahoo reference; no
> 15-min delay anywhere). Session-token derivation was verified across all three
> states live: pre (04:12 EDT), regular (10:05 EDT), post (16:15 EDT) — see §6.

## 1. TL;DR — per-feature pinning (recommendation)

"Dual source" = each feature pinned to whichever provider serves it best. No runtime
failover, no serialized request queue (§7: neither host throttled us).

| Feature | Pin to | Endpoint | Go? |
|---------|--------|----------|-----|
| Batch quotes (price, OHLC, prev close, volume, mcap, PE, 52wk, currency) | **Tencent** | `qt.gtimg.cn/q=usAAPL,...` | GO |
| Identity (en name, zh name, exchange, kline symbol) | **Tencent** | same call, fields 46 / 1 / 2 | GO |
| Extended-hours chip (盘前/盘后 price + %) | **Sina** | `hq.sinajs.cn/list=gb_aapl,...` fields 21–25 | GO, gap: no BRK.B (§5) |
| Session state (`MarketSession`) | **Tencent** market-state feed + Sina EDT timestamps | §6 | GO — all tokens confirmed live (pre/regular/post) |
| Day chart 1D/5D (5-min bars) | **Sina** | `US_MinKService.getMinK?symbol=aapl&type=5` | GO, regular session only (§8) |
| 1M/3M/YTD/1Y charts + YTD baseline | **Tencent** | `usfqkline/get?param=usAAPL.OQ,day,,,320,qfq` | GO |
| 5Y chart | **Tencent** | same, `week` | GO |
| All chart | **Tencent** | same, `month` (2007+) — owner call vs Sina 1984+ (§8) | GO |
| Search (en + zh queries) | **Sina** | `suggest3.sinajs.cn/suggest/type=41&key=...` | GO |
| Indices ^DJI/^IXIC/^GSPC | **Tencent** | `q=usDJI,usIXIC,usINX` | GO |
| Sina `int_` indices | — | **NEVER** — proven months-stale (§2.1) | NO-GO |
| Logos | neither | bundle assets at build time + ticker-ring fallback (§11) | GO |

Both hosts answered a **50-symbol batch in one sub-second request** and took 20
rapid-fire sequential hits without a single non-200 (§7). The v0.1 global request
queue can be deleted; the watchlist becomes ~2 requests total (one Tencent batch, one
Sina batch), vs Yahoo's `8 + 3N`.

## 2. Freshness (the ship-blocker question)

### 2.1 Closed-market evidence (2026-07-08 ~05:16 UTC)

- **Tencent, Sina `gb_`, and Yahoo (reference) agree to the cent** on AAPL:
  price 310.66, prev close 312.66. Tencent's timestamp field 30
  (`2026-07-07 16:00:01`) equals Yahoo's `regularMarketTime` (1783454401) **to the
  second**. Same story for MSFT (388.84 / 386.74) and BRK.B (Tencent 504.00).
- Sina `gb_` also carries yesterday's post-market close (311.42 at
  `Jul 07 07:59PM EDT`) — one minute before the 8 PM post-session end, i.e. the feed
  tracked the extended session to its final minute.
- **Sina `int_dji` said 46247.29 while Tencent `.DJI` said 52925.15** in the same
  minute (fixture `sina_int_indices.gbk.txt`) — ~13% low; that is a months-old Dow
  level. `int_*` is a dead/stale feed. Do not use it for anything, ever.
- The kline endpoint embeds a quote block whose field 0 is the literal string
  `"delay"`, whereas the same field from `qt.gtimg.cn` is `"200"`. Reading: the
  *chart* endpoint's embedded quote is flagged delayed; the *quote* host is a
  different (likely real-time) class. We never read prices from the kline's embedded
  quote, but the marker semantics get verified live.

### 2.2 Market-hours measurement — RESULT: both hosts real-time (2026-07-08)

Method: 33 sample rounds at ~30 s spacing across three regular-session windows
(10:04–10:07, 12:08–12:09, 14:11–14:25 EDT), each round fetching AAPL + SPY
back-to-back from Yahoo `v8/finance/chart` meta (live reference), `qt.gtimg.cn`
(Tencent quote), and `hq.sinajs.cn` `gb_` (Sina quote). Per provider we measured
(a) same-sample absolute price deviation vs the reference, and (b) **price-track
lag**: the smallest k ≥ 0 such that the provider's price matches the reference price
from k samples (30 s each) earlier, tolerance $0.06 AAPL / $0.12 SPY.

| Metric (n=33 rounds) | AAPL Tencent | AAPL Sina | SPY Tencent | SPY Sina |
|---|---|---|---|---|
| price-track lag, median | **0 s** | **0 s** | **0 s** | **0 s** |
| price-track lag, max (matched) | 60 s | 60 s | 60 s | 30 s |
| samples unmatched in 4-min window* | 6 | 2 | 1 | 0 |
| \|price − ref\|, median | $0.040 | $0.015 | $0.050 | $0.006 |
| \|price − ref\|, max | $0.199 | $0.116 | $0.490 | $0.135 |

\* All unmatched samples cluster at the volatile 10:04–10:07 post-open window or at
look-back boundaries (first samples of a window can't look back); worst deviation was
$0.49 on a $744 SPY = 0.066% — tick-level quote-vs-trade noise, not staleness. A
15-min-delayed feed would trail by ~30 samples; both hosts track the live reference
within one sample.

Supporting observations from the same session:

- Tencent field 30 (last-trade time) ran median 11–12 s (max 22 s) behind wall clock —
  trade-print latency only; its *price* was current (see track lag). Yahoo's own
  `regularMarketTime` ran median ~1 s behind wall clock.
- Marker semantics (closing §2.1's open question): `qt.gtimg.cn` field 0 read `200`
  on every sample all session; the kline's *embedded* quote marker read `real` both
  in-session (10:05 EDT fixture) and just after the close (16:15 EDT fixture) — the
  `delay` value appeared only in the overnight probe. Informational only; we never
  read prices from the embedded quote.
- Sina's 5-min bar feed includes the **current in-progress interval** (bar end-stamped
  `10:05:00` was already present when captured at 10:05:11) — the 1D chart's right
  edge is live (fixture `sina_min5_regular.jsonp.txt`).

**Verdict: the freshness ship-blocker is cleared.** Tencent and Sina US quotes are
real-time during regular hours. Ext-hours prices come from Sina only (§6).

## 3. Endpoint catalog

All bodies from `qt.gtimg.cn`, `hq.sinajs.cn`, and `suggest3.sinajs.cn` are **GBK**.
`hq.sinajs.cn`, `suggest3.sinajs.cn`, and `stock.finance.sina.com.cn` require
`Referer: https://finance.sina.com.cn` (403/garbage without it). Tencent hosts need no
special headers. All are plain GET, no key, no crumb dance.

| Endpoint | Envelope | Fixture |
|----------|----------|---------|
| `GET https://qt.gtimg.cn/q=usAAPL,usMSFT,usBRK.B` | `v_usAAPL="~-separated";` per line | `tencent_quote_batch.gbk.txt` |
| `GET https://hq.sinajs.cn/list=gb_aapl,gb_msft` | `var hq_str_gb_aapl=",-separated";` per line | `sina_quote_batch.gbk.txt` |
| `GET https://web.ifzq.gtimg.cn/appstock/app/usfqkline/get?param=usAAPL.OQ,day,,,320,qfq` | JSON | `tencent_kline_{day,week,month}.json` |
| `GET https://stock.finance.sina.com.cn/usstock/api/jsonp.php/cb/US_MinKService.getMinK?symbol=aapl&type=5` | anti-hotlink comment + `cb([...])` JSONP | `sina_min5.jsonp.txt` |
| same base, `US_MinKService.getDailyK?symbol=aapl` | JSONP | `sina_daily_full.jsonp.txt` |
| `GET https://suggest3.sinajs.cn/suggest/type=41&key=apple` | `var suggestvalue="...";` | `sina_suggest_apple.gbk.txt` |

## 4. Field maps

### 4.1 Tencent quote (`~`-separated; index → meaning; ✓ = cross-checked)

Verified against Sina and Yahoo values for AAPL/MSFT/BRK.B:

| idx | value (AAPL) | meaning |
|-----|--------------|---------|
| 0 | `200` | quote-class marker (kline's embedded copy reads `real` in-session, `delay` overnight; §2.2) |
| 1 | `苹果` | zh name → `Stock.zhName` ✓ |
| 2 | `AAPL.OQ` | full code with exchange suffix → kline symbol + `Stock.exchange` ✓ |
| 3 | `310.66` | last price → `Quote.price` ✓ (= Yahoo to the cent) |
| 4 | `312.66` | prev close → `Quote.prevClose` ✓ |
| 5 | `315.29` | open → `Quote.open` ✓ |
| 6 | `42490002` | volume → `Quote.volume` ✓ (= Sina exactly) |
| 9/10, 19/20 | | bid/bid-size, ask/ask-size (unused) |
| 30 | `2026-07-07 16:00:01` | last-trade time, **US Eastern** → `Quote.asOf` ✓ (= Yahoo epoch to the second) |
| 31 / 32 | `-2.00` / `-0.64` | change / change% → `dayChange` / `dayChangePct` ✓ |
| 33 / 34 | `315.48` / `310.15` | day high / low ✓ |
| 35 | `USD` | currency |
| 37 / 38 | | turnover (USD) / turnover rate % |
| 39 | `37.61` | trailing P/E (= price ÷ field 47) → `Quote.trailingPe` ✓; `forwardPe` → null, not provided |
| 44 / 45 | `45599.6` / `45627.7` | float / total market cap in **亿 USD** → `marketCap` = field 45 × 1e8 ✓ (matches Sina's 4562774014960) |
| 46 | `Apple Inc.` | English name → `Stock.name` ✓ |
| 47 | `8.26` | EPS (TTM) |
| 48 / 49 | `317.40` / `200.72` | 52-week high / low |
| 62 | `14687356000` | shares outstanding ✓ (= Sina exactly) |

Indices return the same shape (`usDJI` → `.DJI` 道琼斯, `usIXIC` → `.IXIC`, `usINX` →
`.INX` 标普500); `marketCap`/PE positions are 0/empty there → map to null. Unlisted
symbols return `v_pv_none_match`. Unmapped positions (41, 43, 50–61, 63–67) are left
undocumented on purpose — nothing our models need; do not guess at them in 17.

### 4.2 Sina `gb_` quote (`,`-separated)

| idx | value (AAPL) | meaning |
|-----|--------------|---------|
| 0 | `苹果` | zh name |
| 1 | `310.6600` | last price ✓ |
| 2 / 4 | `-0.64` / `-2.0000` | change% / change ✓ |
| 3 | `2026-07-08 08:14:40` | update time in an **inconsistent/unidentified timezone** (MSFT said 09:38:52 in the same response) — **do not use**; use fields 24/25 |
| 5 / 6 / 7 | open / day high / day low ✓ |
| 8 / 9 | 52wk high / low |
| 10 / 11 | volume ✓ / avg volume |
| 12 | `4562774014960` | market cap, **USD units** ✓ |
| 13 / 14 | EPS / trailing P/E |
| 17 | `0.27` | dividend (quarterly) |
| 19 | shares outstanding ✓ |
| **21** | `311.4210` | **extended-hours price** ✓ (21 = 1 + 23) |
| **22** | `0.24` | **extended-hours change %** → `Quote.extChangePct` ✓ |
| **23** | `0.76` | extended-hours change ✓ |
| **24** | `Jul 07 07:59PM EDT` | extended-session timestamp (EDT/EST, `MMM dd hh:mmA z`) |
| **25** | `Jul 07 04:00PM EDT` | regular-close timestamp |
| 26 | `312.6600` | prev close ✓ |
| 27 | `2509883` | extended-hours volume |

Fields 15/16/18/20/28–35: unidentified, unused. Empty body (`=""`)/dead rows are how
Sina reports unknown symbols — see §5.

### 4.3 Tencent kline JSON

`data.<symbol>.qfq<gran>` = array of `[date, open, close, high, low, volume]`
(strings; **close is index 2, high is 3** — not OHLC order). Coverage measured:
`day,,,320` → 320 bars (2025-03-27→今), `week` → 320 (2020-05-29→), `month` → 233
(2007-03-30→, i.e. all Tencent has). The trailing bar is the current in-progress
period. `data.<symbol>.qt.market` is the market-state feed (§6). `m5`-style
granularities are rejected (`bad params`) — minute data comes from Sina.

### 4.4 Sina 5-min / daily JSON (after JSONP strip)

Array of `{"d","o","h","l","c","v","a"}` (strings; `a` = dollar amount, `0` in old
daily rows). 5-min: 14 trading days × regular session only, bars stamped at interval
**end** (first `09:35:00`, last `16:00:00`), timezone = US Eastern, no date gaps
within a day. Daily: full history since IPO (AAPL: 1984-09-07), **934 KB** for AAPL —
usable but heavy; see §8 for the All-range recommendation.

### 4.5 Sina suggest

`var suggestvalue="entry;entry;...";` — entries are `,`-split: field 0 display name
(zh when Sina has it, else en), field 2/3 lowercase symbol, field 1 = type (41 = US
equity). Works for English (`apple`), Chinese (`苹果`), and ticker-prefix queries.
Names come back zh-or-en unpredictably → after a pick, fetch identity from the Tencent
quote (which always has both names) rather than trusting the suggest name.

## 5. Symbol mapping

| App (`Stock.symbol`) | Sina quote | Tencent quote | Tencent kline | Sina minK |
|-----------|------------|---------------|---------------|-----------|
| `AAPL` | `gb_aapl` (lowercase) | `usAAPL` (**no suffix** — `usAAPL.OQ` → `v_pv_none_match`) | `usAAPL.OQ` (suffix from Tencent quote field 2) | `symbol=aapl` |
| `BRK.B` | **none — no working form** (`gb_brk.b` → empty; `gb_brkb` → dead 2019 listing; `gb_brk$b` → empty) | `usBRK.B` ✓ → `BRK.B.N` | `usBRK.B.N` ✓ | `symbol=brk.b` ✓ |
| `^GSPC` / `^IXIC` / `^DJI` | int_* stale — never | `usINX` / `usIXIC` / `usDJI` | n/a for v0.2 | n/a |
| `SPY` (ETF) | `gb_spy` ✓ | `usSPY` → `SPY.AM` ✓ | `usSPY.AM` | `symbol=spy` |

Exchange suffixes observed: `.OQ` = NASDAQ, `.N` = NYSE, `.AM` = NYSE American/Arca.
Rule for 17: app symbol → Tencent = `us` + symbol as-is (dots kept); → Sina quote/minK
= lowercase (dots kept); kline symbol is **never derived** — always read field 2.

**Consequence of the BRK.B gap:** everything Sina-pinned still works for dotted
tickers **except the extended-hours chip** (Sina `gb_` is its only source). Dotted
tickers therefore show no 盘前/盘后 chip (`extChangePct` = null — already a legal
state in the model, same as Yahoo's null). Owner should confirm this is acceptable.

## 6. Session state (`MarketSession`) derivation

Two independent signals, no device-clock guessing:

1. **Tencent market-state feed**: `data.*.qt.market[0]` on any kline response, e.g.
   `2026-07-08 13:16:28|...|US_close_未开盘|...` (Beijing-stamped). Parse the `US_`
   token — but see the pre-market finding below (a `param=usAAPL.OQ,day,,,1,qfq` call
   is ~1 KB, cheap to poll).
2. **Sina timestamps** (fields 24/25): if the extended timestamp is morning
   (before 09:30 ET) → `pre`; 16:00–20:00 ET → `post`; else `closed`/`regular` per
   field 25 vs field 3 freshness.

**Pre-market probe (2026-07-08 04:12 EDT; fixtures `*_premarket.*`):**

- The `US_` token does **not** flip for pre-market — it reads `US_close_未开盘` both
  when fully closed and during pre. The pre state lives in a separate token:
  `USB_close_未开盘` (closed) → `USB_open_盘前交易` (pre). `USB_` = US before-hours,
  `USA_` = US after-hours — **confirmed live across all three sessions** (regular
  10:05 EDT and post 16:15 EDT probes, fixtures `*_regular.*` / `*_postmarket.*`):

  | Wall clock (EDT) | `US_` | `USB_` | `USA_` |
  |---|---|---|---|
  | 04:12 (pre) | `US_close_未开盘` | `USB_open_盘前交易` | `USA_close_未开盘` |
  | 10:05 (regular) | `US_open_交易中` | `USB_close_已收盘` | `USA_close_未开盘` |
  | 16:15 (post) | `US_close_已收盘` | `USB_close_已收盘` | `USA_open_盘后交易` |

- Tencent's quote host has **no post-market price either** (16:15 EDT probe: fields
  3/30 frozen at the 16:00:01 close) — symmetric with the pre-market finding below;
  ext-hours prices are Sina-only in both directions. Sina's post-market ext quote was
  again live to the minute (field 21 = 313.39, field 24 = `Jul 08 04:15PM EDT`).
- Tencent's quote host carries **no pre-market price**: field 3 / field 30 stay at the
  last regular close (310.66 / `2026-07-07 16:00:01`). Only bid/ask (field 9 = 311.40)
  move. Ext-hours prices must come from Sina.
- Sina `gb_` pre-market ext quote is **live to the minute**: field 21 = 311.1988 with
  field 24 = `Jul 08 04:12AM EDT` — the very minute of the sample. Field 25 stays at
  the last regular close time (`Jul 07 04:00PM EDT`).

Recommendation for 17 (final): session = Tencent tokens, reading `US_` **and**
`USB_`/`USA_`: `US_open→regular`, `USB_open→pre`, `USA_open→post`, all-close→`closed`
(all six spellings now captured in fixtures — see table above). Sina 24/25 then only
picks *which* ext figure the chip shows — and supplies the ext price itself, since
Tencent has none — mirroring the v0.1 Yahoo PREPRE rule (a stale post figure must not
render as a live pre chip).

## 7. Batch size & rate limits — no serialization needed

- 50 symbols in one call: Tencent 200 OK, 0.99 s, all 50 filled; Sina 200 OK, 0.65 s,
  49 filled (the 50th is BRK.B, §5). Fixtures: `*_batch50.gbk.txt`.
- 20 back-to-back sequential single-symbol requests per host: 20×200 OK each, flat
  ~0.7 s latency (that's the US↔CN round-trip), no 429, no backoff, no cooldown.
- Target confirmed: **no global serialized queue.** Watchlist first paint = 1 Tencent
  batch (+1 Sina batch for ext chips). Charts fetch on demand per detail view.

## 8. Charts: slicing and range coverage

- **1D**: Sina 5-min bars, filter `d` startsWith the trading date taken from Tencent
  quote field 30. Bars are end-stamped regular-session only (09:35…16:00). The gap
  open is preserved: waterline = `prevClose` from the quote, first bar already sits at
  the gapped price. **Deviation vs Yahoo/v0.1: no pre/post segment in the 1D line**
  (Yahoo drew 04:00–20:00). The pre/post *chip* still works via Sina quote. Owner must
  accept this before 18.
- **5D**: same payload (14 days deep) — zero extra requests.
- **1M/3M/YTD/1Y**: Tencent `day` (320 bars ≈ 15 months). YTD baseline = close of the
  last bar dated ≤ Dec 31 of the previous year; verified in-range (bars reach back to
  2025-03-27, and month/week go further).
- **5Y**: Tencent `week` (320 ≈ 6.1 y). ✓
- **All**: recommend Tencent `month` — 16 KB, back to 2007 (all Tencent keeps).
  Alternative is Sina `getDailyK` (true IPO-to-date, AAPL 1984+) at **934 KB per
  symbol**; not worth it for a decorative All view. **Owner call.**
- Baselines: chart endpoints carry no `chartPreviousClose` equivalent; each range's
  waterline = the close of the last bar *before* the window, which the same payload
  already contains (320 bars > any window we draw). No extra request.

## 9. GBK decoding — pick: `fast_gbk` (added in 17, not here)

- `fast_gbk` 1.0.0: pure Dart, **zero dependencies**, works in plain `dart test` with
  the committed fixture bytes. SDK bound `>=2.12 <3.0.0` is null-safe, which pub
  auto-extends to Dart 3 — resolves fine.
- `charset_converter` 2.4.0: a Flutter **platform-channel plugin** (delegates to
  iOS/Android native decoders) — cannot run in host unit tests at all, which alone
  disqualifies it for a data layer whose mapping tests are the point.

## 10. Envelope stripping per endpoint (for 17/18)

| Endpoint | Rule |
|----------|------|
| `qt.gtimg.cn` | per line: `v_<query>="<body>";` → regex `^v_(.+?)="(.*)";$`, split body on `~`; `pv_none_match` in body = unknown symbol |
| `hq.sinajs.cn` | per line: `var hq_str_<query>="<body>";` → same shape, split on `,`; empty body = unknown symbol |
| Sina minK/dailyK | drop the leading `/*<script>location.href='//sina.com';</script>*/` anti-hotlink line, then take the JSON inside `cb( ... )` |
| `suggest3.sinajs.cn` | `var suggestvalue="<entries>";`, entries split `;` then `,` |
| Tencent kline | plain JSON, `code != 0` = error (`bad params` observed) |

All GBK decoding happens **before** regex/splitting (fixture bytes → `fast_gbk` →
string). Only Sina quote/suggest actually contain non-ASCII; Tencent zh names do too.

## 11. Logos reachable from China (feeds task 21)

Every runtime logo service is a liability: Google s2 favicons is GFW-blocked (a
v0.2 trigger), Clearbit/other Western favicon CDNs are unverifiable from here and can
vanish or get blocked any day. Recommendation: **no network logos at all** —
build-time-bundled asset pack (symbol → logo image committed to the repo) for a
curated top-~100 US tickers + the existing ticker-ring fallback for everything else.
Local-first, zero runtime requests, works identically in CN/US, and the fallback ring
is already shipped. Task 21 then = curate the pack + a lookup table; no new deps.

## 12. Open risks for the owner to accept at sign-off

1. ~~Freshness numbers pending~~ — **resolved** (§2.2): both hosts real-time during
   regular hours; no delayed-quote risk.
2. Unofficial, undocumented endpoints (same class of risk as Yahoo v0.1): no SLA, no
   ToS blessing for third-party apps; format can change silently. Mitigation stays the
   same — fixtures + mapping tests fail loudly, provider swap is contained in
   `lib/data` behind the v0.1 seams.
3. Dotted tickers (BRK.B) get no pre/post chip (§5).
4. 1D chart shows regular session only (§8) — visible product change vs v0.1.
5. "All" range starts at 2007 if pinned to Tencent month (§8).
