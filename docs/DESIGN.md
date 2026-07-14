# 团团看盘 (TuanTuan Stocks) — Design (v4.0, LOCKED)

> v4.0 (2026-07-13, owner): the app adds the owner-locked US-only Blue Ocean ATS
> overnight path described below. v3.1 (2026-07-02, owner): the detail hero's change line
> now follows the selected
> range (Robinhood mode) instead of always showing today; the waterline text label is
> gone on every range (noise); ranges gain 5年/全部 (chips wrap onto two rows); the
> watchlist sort toggle gains 今年 and the row's numbers follow the active sort; the
> stats grid gains 市盈率/预期市盈率; percents show two decimals. Everything else
> unchanged from v3.

A cute US-stock **price viewer**. Look only — never trade. It carries over the visual
language and the mascot 团团 from the sister project `nudge`.

Visual reference (approved by the owner): [`mockups/design.html`](../mockups/design.html),
rendered to `mockups/design.png`. The mockup is the source of truth for look & feel; this
document is the source of truth for behavior.

## Product scope

- **In:** a personal watchlist of US tickers with a daily "race" ranking; per-stock detail
  (price hero, sky/water chart, key stats); ticker search to add/remove.
- **Out:** trading, accounts, portfolios, P&L, alerts, news, recommendations, analytics.
- Markets: **US equities/ETFs** (NASDAQ / NYSE) only.
- Color convention: **green = up, red = down** (US style; up = 团团's matcha green).

## Structure — single page, no tab bar

1. **Watchlist** is the app. It opens directly; there is no bottom navigation.
   - Top bar: brand `团团看盘 🌱` left; **one** button top-right: search 🔍.
     No settings button, no notification button anywhere.
   - Index strip: three chips — 标普500 / 纳斯达克 / 道琼斯 (value + day %, tinted
     up/down), fed by real index quotes (^GSPC / ^IXIC / ^DJI — verified in the task-04
     spike; no ETF proxies needed).
   - **The daily race list** (see below).
2. **Stock detail** — pushed by tapping a row. Back arrow top-left, search 🔍 top-right.
3. **Search** — pushed by the 🔍 button. `‹ 搜股票` back; results with ＋/✓ add state;
   a "热门" list when the query is empty.

## Watchlist — the daily race 🏁

- **Default sort: today's change %, descending.** Every day is a race.
- **Medals**: 🥇🥈🥉 badges pinned to the **top-left corner of the logo avatar** of today's
  top-3 gainers. Ranks 4+ get a small muted number badge. Medals always belong to the
  day-change race regardless of the active sort.
- **Sort toggle** (a right-aligned chip row, no section title — with 市值/今年 sorts
  the list isn't only today's race, so the `今日排位赛 🏁` header was dropped in v3.1):
  `涨跌幅` (default) / `市值` / `今年`. Switching re-orders rows; medals stay with
  their stocks. **The row's numbers follow the active sort** (v3.1):
  under `市值` the headline figure is the compact market cap instead of the price;
  under `今年` the pill shows the YTD change % instead of today's (unresolved YTD →
  muted `—`). Unknown values sink to the bottom of their sort.
- **YTD rank**: each row's subtitle shows `<中文名> · 今年 #N` — the stock's
  **year-to-date gain rank within this watchlist** (integer, 1 = best). Computed live:
  YTD % = current price vs last year's closing price; rank among watchlist members.
- **Compact rows** (~6+ visible): logo avatar (34px) with medal badge, name + subtitle,
  mini thick sparkline (green/red by day direction), price + tinted change pill.
- Row actions: tap → detail; swipe left → remove. No manual reorder (sorting is automatic).
- Footer hint: `按当日涨幅自动排序 · 左滑删除`.

### Loading

The watchlist paints progressively in this order: one batched quote snapshot first,
then row decorations, then sparklines. Before the quote snapshot resolves, rows use
fixed-size cute skeleton cards so the list footprint is already stable. The quote
snapshot is enough to render ticker fallbacks, medals, day-change sorting, prices, and
session tags. Identity (name/logo) and YTD ranks fill into the existing row layout when
their futures resolve; missing YTD remains a muted `—` under the YTD sort. Row
sparklines are always per-row async decoration and never block row layout.

### Session labeling (盘前 / 盘后 / 夜盘)

Every displayed change % states its session — never let a number be misread:
- During regular hours the pill/hero reads as `今天`.
- Outside regular hours, show the extended move with a small tag: **盘前 (pre)** before
  open, **盘后 (post)** after close, or **夜盘 (overnight)** in the Blue Ocean window — on
  watchlist rows (tiny line under the pill) and
  in the detail hero (small inline chip). The regular-day change stays visible; the tag
  carries the extended-session change.
- zh/en label sets: 盘前/盘后/夜盘 ↔ Pre/Post/Overnight (whole-set swap, per the i18n
  rule).

### Overnight session (v4.0)

- **Window and source:** during the Blue Ocean ATS window, Sunday–Thursday 20:00–04:00
  America/New_York, the app may show Alpaca Basic `overnight` latest-quote midpoints.
  All other sessions retain Tencent/Sina as the primary quote source. The ET clock—not
  the UTC date—defines the cross-midnight window; holidays are simply quiet.
- **Polling:** one shared coordinator owns the only Alpaca request path. In the foreground
  it sends one batched request every 30 seconds for the union of the watchlist and any
  open detail symbol (two requests per minute); the 1D chart makes no overnight request
  or drawing. Backgrounding makes zero requests and foreground resumption refreshes
  immediately. Failures back off per source to five minutes and recover on success.
- **Presentation (A1 + B1):** a usable midpoint creates a small 夜盘/Overnight tag in
  watchlist rows and an inline detail-hero chip, showing its percent move versus the
  latest regular close. The headline price, official day-change pill, day-race order,
  medals, and chart geometry remain frozen at the regular close. C2 night dressing is a
  separate task-37 cosmetic follow-up, not part of this data path.
- **Silent degradation:** missing build-time credentials, unreachable/timeout/HTTP/429,
  malformed or stale data, and unavailable mainland-China access all show no overnight
  tag and no error UI; regular/pre/post behavior and cached CN quotes remain intact. A
  build reads `ALPACA_KEY_ID` and `ALPACA_SECRET_KEY` only through `--dart-define`; no
  credential belongs in source, logs, or docs.
- **Operational posture:** the client records `X-RateLimit-Remaining`; a 429 is a normal
  no-value tick, never a retry storm. The 2026-07-13 emulator validation observed live
  hands-off tags during the BOATS window, a normal no-key build, and a normal
  app-network-unreachable run. Mainland-China reachability remains deferred for the
  owner's next real-world China session; its expected behavior is the same quiet
  no-overnight state.

## Company logos

- Rows, detail header, and search results show the **real company logo** in a white round
  avatar (cream ring). Logos: Yahoo `quoteSummary` `assetProfile.website` → favicon
  service (`google.com/s2/favicons?domain=<domain>&sz=128`), cached locally.
- **Fallback** when no logo is available: the same round avatar with a brand-tinted ring
  and the ticker code as text (see SPY in the mockup).

## Stock detail

- Header: logo avatar, `Name` + `中文名` subtitle (no exchange suffix — it's noise),
  ⭐ watch state.
- **Price hero**: gradient candy card — matcha gradient when up, coral-red gradient when
  down — with `现价 (USD)`, a huge tabular price, and a change line that **follows the
  selected range** (Robinhood mode, v3.1): `1日` shows the official day change
  (`▲/▼ +Δ +Δ% 今天`); longer ranges show current price vs the range baseline with the
  range's own label (e.g. `▲ +38.20 +12.0% 今年`). Gradient and arrow follow the
  displayed change. While a range's candles are still loading, fall back to the day
  change rather than showing nothing.
- **Range chips**, one language set, never mixed (see i18n): zh
  `1日 1周 1月 3月 今年 1年 5年 全部` / en `1D 1W 1M 3M YTD 1Y 5Y All` (5年/全部 added
  v3.1). Eight chips don't fit a phone-width row — they wrap onto a second row; never
  hide chips behind a horizontal scroll.
- **Stats grid** (3-per-row): 今开 / 最高 / 最低 / 昨收 / 成交量 / 市值 / 市盈率 /
  预期市盈率 (P/E pair added v3.1; `—` when there is no meaningful multiple —
  indices, ETFs, loss-makers).

### The sky/water chart 🌊 (the signature widget)

- **The 0% baseline sits exactly at the vertical center** of the chart. For 1D the
  baseline is **昨收** (prev close); for longer ranges it is the **closing price at the
  period start** (今年 = last year's final close).
- Above the baseline is **sky**, below is **water** (light blue fill up to the baseline;
  the baseline itself is a dashed light-blue waterline, **no text label** on any range —
  v3.1 removed the `0% 昨收` bubble as noise; the waterline itself says it all).
- Because of extended-hours trading the line's first point can start **above or below**
  the waterline (gap up / gap down) — never assume it starts at 0%.
- On **1D only**, x is the US-Eastern trading day rather than candle index:
  04:00–09:30 pre-market occupies 15% of the width, 09:30–16:00 regular
  session occupies 70%, and 16:00–20:00 after-hours occupies 15%. Subtle
  vertical dividers mark the 09:30 and 16:00 seams; pre/post labels live inside
  those zones. Extended-hour zones stay plain sky/water until data is supplied.
- The price line: **thick rounded stroke** (gradient along its direction color), a candy
  hard offset shadow underneath, and fat white button nodes at sampled points.
- Sky decorations: dotted cream gridlines; on an up day a small sun ☀️ + cream clouds; on
  a down day a grey-lavender rain cloud 🌧 with drops. Fish 🐟 swim in the water.
- **团团 flies a tiny plane at the line tip** (intraday it tracks the latest price):
  - **Up / climbing**: orange plane tilted up, happy face, sparkle ✨, contrail puffs.
  - **Down / diving**: red plane tilted down. 团团 keeps its **round face** — cute panic
    only: dot eyes with highlights, pink cheeks, soft worried brows, a tiny "wah" open
    mouth, wind-bent sprout. Never distort the face.
  - **Underwater** (price below baseline): panic face + **bubbles** 🫧 instead of sweat —
    it is suffocating (adorably).
- Same visual grammar for the mini sparklines in the list (thick rounded line, no scenery).

## Visual language (ported from nudge)

- Backdrop: cream `#FFF7EF` + three soft radial blobs (peach/matcha/lavender).
- Cards: near-white `#FFFDFA`, 2px warm borders, **hard offset shadows**
  (`box-shadow: 0 Npx 0 <darker>`), fat radii (13–26px).
- Type: rounded heavy (Baloo 2 + ZCOOL KuaiLe CJK fallback), w600–w900, tabular numerals
  for all prices.
- Palette anchors: matcha `#3F7D5C` / gradient `#8AD6A3→#5CC78F` / shadow `#4FB87F`;
  up-vivid `#2E9E6B`, up-bg `#EAFAF0`; down `#FF9D86→#E0604A` / shadow `#CF5440`,
  down-bg `#FDEEEB`; peach accent `#FFB07C→#FF9B6A` / shadow `#F08A55`; text brown
  `#5A4A3F`; water `#DCEFFA`, waterline `#8ECAE6`. Port the full `CuteColors` set from
  the mockup CSS — one Dart file, no hex at call sites.

## i18n

- UI languages: zh + en via ARB. **No mixed-language strings**: the range chips swap as a
  whole set per locale (`1日/1周/1月/3月/今年/1年` ↔ `1D/1W/1M/3M/YTD/1Y`).
- No design rationale in UI copy — labels say what the user needs, nothing more.

## Architecture seams

- `QuoteRepository` — quote (incl. day change, market cap, **ytdChangePct**, and the
  **session** — pre/regular/post/overnight/closed — with the extended-hours change when outside
  regular hours) + candles for a symbol/range.
- `SearchRepository` — symbol/name search → matches.
- `WatchlistRepository` — local-first CRUD of saved symbols.
- Concrete provider code lives only in `lib/data`; swapping providers touches nothing else.
  Provider (decided by the task-04 spike, `provider-report.md`; **owner accepted the ToS
  trade-off 2026-07-01**): **Yahoo Finance's unofficial API, keyless** —
  - v8 `chart`: intraday incl. pre/post bars; daily candles per range;
    `chartPreviousClose` = the per-range baseline (incl. YTD) — the waterline for free.
  - v7 `quote` (batched, one call per watchlist refresh) + v10 `quoteSummary`
    (profile → market cap + website → favicon logo), both behind a small cookie+crumb
    helper (cache, refresh on 401).
  - v1 `search` for symbol lookup; real index quotes via `^GSPC`/`^IXIC`/`^DJI`.
  No API key, no `--dart-define`. It is unsanctioned use of an unofficial API — accepted
  for this personal look-only app; the seams keep a provider swap data-layer-only if
  Yahoo ever breaks. Risks, fallbacks, and session/null semantics: `provider-report.md`.
  Quotes may be delayed — fine for a "瞄一眼" app.

## Tech

Flutter (iOS + Android), Riverpod + go_router, shared_preferences for the watchlist
(may move to drift later). English code/comments/docs; user strings via ARB only.
