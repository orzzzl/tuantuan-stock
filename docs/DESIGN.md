# 团团看盘 (TuanTuan Stocks) — Design (v3.1, LOCKED)

> v3.1 (2026-07-02, owner): the detail hero's change line now follows the selected
> range (Robinhood mode) instead of always showing today; the waterline label shows
> only on 1日 (other ranges' baselines aren't 昨收, and spelling it out is noise);
> ranges gain 5年/全部 (chips wrap onto two rows); the watchlist sort toggle gains
> 今年 and the row's numbers follow the active sort. Everything else unchanged from v3.

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
- **Sort toggle** in the section header (`今日排位赛 🏁` + chips right-aligned):
  `涨跌幅` (default) / `市值` / `今年` (今年 added v3.1). Switching re-orders rows;
  medals stay with their stocks. **The row's numbers follow the active sort** (v3.1):
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

### Session labeling (盘前 / 盘后)

Every displayed change % states its session — never let a number be misread:
- During regular hours the pill/hero reads as `今天`.
- Outside regular hours, show the extended move with a small tag: **盘前 (pre)** before
  open, **盘后 (night)** after close — on watchlist rows (tiny line under the pill) and
  in the detail hero (small inline chip). The regular-day change stays visible; the tag
  carries the extended-session change.
- zh/en label sets: 盘前/盘后 ↔ Pre/Night (whole-set swap, per the i18n rule).

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
- **Stats grid** (3×2): 今开 / 最高 / 最低 / 昨收 / 成交量 / 市值.

### The sky/water chart 🌊 (the signature widget)

- **The 0% baseline sits exactly at the vertical center** of the chart. For 1D the
  baseline is **昨收** (prev close); for longer ranges it is the **closing price at the
  period start** (今年 = last year's final close).
- Above the baseline is **sky**, below is **water** (light blue fill up to the baseline;
  the baseline itself is a dashed light-blue waterline). On 1日 a tiny `0% 昨收` label
  sits on the waterline where it won't collide with the line; other ranges show **no
  label** (their baseline is the period-start close, and spelling that out is noise —
  v3.1).
- Because of extended-hours trading the line's first point can start **above or below**
  the waterline (gap up / gap down) — never assume it starts at 0%.
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
  **session** — pre/regular/post/closed — with the extended-hours change when outside
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
