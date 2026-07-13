# v0.4 overnight session (夜盘) — design proposal

> **Status: PROPOSAL — owner sign-off required before any implementation task
> starts.** The data source is decided (owner approved both provider-report-v3c §5
> items on 2026-07-13: the Alpaca Basic account/credential model for the read-only
> overnight path, and implementation-phase validation of reachability, rate-limit
> handling, and silent degradation). What still needs an owner pick is the product
> shape — §4 below presents the options. Once signed off, the locked decisions get
> folded into `DESIGN.md` (task 36) and tasks 32–35 flip READY.

## 1. What we are building

Broker apps show Blue Ocean ATS (BOATS) activity from Sunday evening through the
week; our app freezes after post-market. v0.4 makes the app show **overnight
indicative prices** during the BOATS window — Sunday–Thursday **20:00–04:00 ET** —
sourced from Alpaca Basic's derived `overnight` feed (spike evidence:
`provider-report-v3c.md`).

Everything outside that window, and every other session (regular/pre/post), is
unchanged: Tencent/Sina stay the primary providers everywhere else, and their
mainland-China reachability requirement is untouched. Alpaca is overnight-only.

## 2. Locked constraints (owner-approved, not up for redesign)

- **Source**: Alpaca Basic, REST **latest-quotes batch** with `feed=overnight`.
  Quotes are the freshness signal — Basic's latest *trades* are 15-minute delayed
  and must never gate freshness (v3c §2). One batched request per tick covers the
  whole watchlist (plus the open detail symbol, §5.3).
- **Session window**: Sun–Thu 20:00–04:00 ET, classified in `America/New_York`
  (never from the UTC date — the session crosses midnight). No fetch outside it.
- **Degradation** (task 30 rule, owner-locked): unreachable / timeout / HTTP error /
  rate limit / stale or malformed payload ⇒ **no overnight value shown, no error
  UI, no retry storm**. Regular/pre/post behavior and the market cache are
  untouched. Mainland China simply shows no overnight data.
- **Credentials**: read at build time via `--dart-define` (per `AGENTS.md`); dev
  values come from `~/agents/secrets/alpaca.env` at build invocation. Never in
  git, PR text, logs, or `ACTIVITY.log`.
- **Cadence**: reuse the owner-locked ladder (5s/10s/30s/60s named constants from
  task 24). Proposal: overnight polls at **30s** — the existing extended-session
  cadence — i.e. 2 batch requests/min against the observed 200/min limit (§5.4).

## 3. Open point flagged for the owner: key provisioning

The provisioned keys are currently **paper-account** credentials. That is fine for
market data (the data API is the same), but the shipped APK needs a decision:

- **Proposed**: bake the key pair into the owner's personal builds via
  `--dart-define` (same acceptance as the Yahoo ToS trade-off in v0.1 — this is a
  personal, look-only app; the key is extractable from the APK but it is a free,
  data-only, revocable key). Rotation stays manual: regenerate at Alpaca, update
  `~/agents/secrets/alpaca.env`, rebuild.
- Alternative: ship without a key (overnight feature silently off unless the
  build provides one). This is the natural behavior of the proposed wiring anyway
  — a build with no key behaves exactly like an unreachable region.

## 4. Product shape — OWNER DECISION

Three decisions, each with options and a recommendation. They are independent,
but the recommended set (A1 + B1 + C1) is designed to fit together as a minimal,
honest v0.4.

### 4.1 How overnight appears in the UI

**Option A1 — the 夜盘 chip, no chart drawing (recommended).**
Extend the existing 盘前/盘后 session-labeling pattern (DESIGN.md "Session
labeling") with a third state: during the overnight window, watchlist rows show a
tiny 夜盘 line under the change pill and the detail hero shows a small inline 夜盘
chip, each carrying the **overnight move vs the latest regular close**. The
headline price and day-change pill keep showing the official regular-session
numbers, exactly like pre/post today. The 1D chart is untouched — its Night zone
still means 16:00–20:00 post-market; overnight is deliberately not on the day
axis.
- Cost: small (one new session state through existing seams).
- Honesty: high — indicative quote midpoint, labeled as its own session.
- Limitation: no overnight *line* anywhere, only the latest value.

**Option A2 — A1 plus a dedicated overnight mini-chart in the detail screen.**
Everything in A1, plus a slim separate strip below the 1D chart (visible only
when overnight data exists for the current ET trading day) drawing the 20:00–04:00
window as its own left-to-right mini-axis. Data: Alpaca's overnight minute *bars*
endpoint if an implementation probe confirms full-session history on Basic
(v3c only probed `bars/latest`); otherwise accumulate points from our own polling,
the task-27 fallback pattern (persisted per ET trading day, honest gaps).
- Cost: medium (new widget + a data probe; the geometry problem is solved by NOT
  touching the day axis).
- Value: an actual overnight line, on its own honest axis.

**Option A3 — draw overnight into the existing 1D day axis. NOT recommended.**
The locked 15/70/15 axis maps 04:00–20:00 of one ET day; overnight (20:00–04:00)
crosses the date boundary, so this needs a four-zone axis and a redefinition of
"the trading day" (both v3b and v3c flagged this). It breaks locked v3 chart
geometry for a session with thin, indicative liquidity. Listed for completeness.

> Within A1/A2, one small i18n consequence: the English session label set is
> currently Pre/Night (盘前/盘后). Adding overnight, the industry term "Overnight"
> collides with "Night". Proposed whole-set change: **盘前/盘后/夜盘 ↔
> Pre / Post / Overnight** (the 1D chart zone labels follow: Pre/Night →
> Pre/Post). Chinese labels unchanged. Needs owner OK (it renames a v3 label).

### 4.2 Do watchlist rows update during overnight?

**Option B1 — yes, live 夜盘 tags; frozen race (recommended).** Rows keep their
day-race order, medals, and official day-change pills exactly as frozen at the
close; only the 夜盘 tag (and detail hero chip) updates at the overnight cadence.
The race stays a *daily* race; overnight is commentary, not ranking.

**Option B2 — fully static watchlist at night; overnight only in the detail
screen.** Cheaper still, but the list looks dead — which is the exact owner
complaint that started v0.4.

### 4.3 What 团团 / the plane does at night

**Option C1 — nothing new (recommended).** With A1/A2 the day chart isn't
extended, so the plane keeps parking where the post-market line ended. No new
art, no new states, nothing to get wrong.

**Option C2 — night dressing (cheap cosmetic bonus).** During the overnight
window only: the chart's sun/rain decoration swaps to a moon + stars, and 团团
gets a nightcap. Pure theming keyed off the session state — no geometry changes.
If wanted, this is a separate small follow-up task, not part of v0.4's gate.

## 5. Technical design (applies to any option set)

### 5.1 Domain

- `MarketSession` gains **`overnight`**. Semantics: the BOATS window is in
  progress *and* we may have overnight data. Session classification for
  overnight uses a pure ET-clock function (Sun–Thu 20:00–04:00) — reuse the
  existing eastern-time logic; don't invent a second clock. US market holidays
  are deliberately not modeled: on a holiday night BOATS is simply quiet and the
  stale-quote guard (§5.2) yields no value, which degrades silently by design.
- `Quote.extChangePct` carries the overnight move when `session == overnight`
  (same field the pre/post chips already read); `Quote.session` tells the UI
  which label to show. No new fields unless implementation finds it needs a
  separate `overnightAsOf` timestamp for staleness display — flag in PR if so.

### 5.2 Data layer (`lib/data`, provider-swap stays data-only)

The watchlist and the detail screen poll `QuoteRepository` through independent
streams today, so a decorator that fetched Alpaca on the quote path would see
two separate requests and could not form their union. The overnight fetch is
therefore owned by a single shared coordinator; the quote path never talks to
Alpaca at all.

- **`OvernightQuoteCoordinator`** (new, `lib/data/market/`, one Riverpod-owned
  instance): the *only* component that ever calls the new
  `AlpacaOvernightClient`.
  - **Symbol registry**: consumers register interest — the watchlist provider
    keeps the watchlist symbol set registered; a detail screen registers its
    symbol while open and unregisters on dispose. The coordinator polls the
    **union** of registered symbols.
  - **Tick loop**: while the ET clock is inside the overnight window (task
    32's classifier), the app is foregrounded, and the client is enabled
    (keys present), it fires **exactly one batched latest-quotes request per
    tick** for the whole union. The loop is driven by the window classifier
    and lifecycle — never by `Quote.session` (see §5.2a).
  - **Single-flight invariant**: at most one Alpaca request in flight, ever.
    A registry change mid-tick does not fire a parallel request; the
    coordinator may pull the *next* tick forward for a newly registered
    symbol, but always as one batched request covering the whole union.
  - **Output**: an immutable `OvernightSnapshot` — per-symbol midpoint +
    quote timestamp, plus the tick's fetch time — published through a
    provider. Failed/stale/absent symbols are simply missing from it.
- **Merge seam (request-free)**: the overnight "decorator" over the repository
  path does no I/O — it merges the coordinator's *current* snapshot into the
  Tencent/Sina quote (which still supplies close/prevClose/identity — those
  endpoints keep working at night): a snapshot hit sets `session = overnight`
  and `extChangePct`; a miss returns the underlying quote untouched
  (`session` stays `closed`). Watchlist and detail quote providers also watch
  the snapshot provider, so a new snapshot re-merges the already-fetched CN
  quotes and re-renders without any CN refetch. `QuoteRepository` consumers
  still see plain `Quote`s.
- **Displayed value = quote midpoint** `(bid + ask) / 2` from the latest-quotes
  response — the only real-time field on Basic. Overnight change % = midpoint vs
  the latest regular close already shown in the app (Sunday night = Friday's
  close), so the chip is consistent with the numbers on screen.
- **Staleness guard**: a quote whose `latestQuote.t` is older than a named
  constant (proposal: 20 minutes) is treated as no value for that symbol. Thin
  BOATS liquidity means old-but-valid quotes exist; 20 min separates "quiet
  symbol" from "dead feed" without flapping. Retuning is a one-line diff.
- **Auth**: `ALPACA_KEY_ID` / `ALPACA_SECRET_KEY` via `--dart-define`; a build
  without them disables the overnight path entirely (compile-time empty string →
  the coordinator never ticks and the merge is a pass-through). No secret ever
  logged.
- **Failure = absence**: timeout (short, ~8s), non-200, HTTP 429, parse error,
  empty payload — all yield no overnight value for that tick, log-free and
  UI-error-free. On consecutive failures, back off (double up to 5 min, the
  task-24 pattern) and recover on next success.

### 5.2a No-value path (explicit)

Degradation must not stop the clock. Inside the overnight window:

- The coordinator keeps ticking at the 30s cadence (stretched by backoff, max
  5 min, restored on next success) **regardless of whether any tick returns a
  value**. Its schedule reads only the ET window classifier and app lifecycle.
  In particular it must never key off `Quote.session`: on a degraded tick the
  merged quote falls back to the CN quote whose session is `closed`, and if
  that fallback drove the schedule the poller would sleep until pre-market and
  never notice Alpaca recovering.
- A no-value tick leaves the merged quote exactly equal to the underlying CN
  quote (`session = closed`, no chip/tag) — the owner-locked silent
  degradation. The next successful tick re-lights the overnight UI without a
  restart.
- The CN quote pollers are untouched by any of this: overnight they keep
  their existing closed-session behavior (`closedSessionRefreshDelay`),
  whether or not Alpaca is healthy.

### 5.3 Polling (reuse task 24's machinery)

- The coordinator's tick loop *is* the overnight polling: one batched
  latest-quotes request per tick for the union of registered symbols
  (**watchlist ∪ the open detail symbol**), at the 30s extended cadence, only
  while the app is foregrounded and the ET clock is inside the overnight
  window (§5.2/§5.2a). The detail screen never adds its own overnight poll —
  opening it just registers one more symbol into the next batch.
- Window edges: crossing 20:00 ET starts the loop without a restart; crossing
  04:00 ET stops it. The existing closed-session wake-up delay extends to the
  next overnight/pre boundary, whichever is sooner.
- The 1D chart poller stays off overnight (nothing new is drawn on the day
  axis; under A2 the mini-chart consumes the same snapshot ticks or its own
  bars fetch, never a faster cadence).

### 5.4 Rate-limit posture (validation item, owner-approved)

Observed limit 200 req/min (v3c §3); planned load is 2 req/min. Implementation
must still read `X-RateLimit-Remaining` and treat 429 as a normal no-value tick
feeding the backoff — never a retry storm. The implementation-phase validation
(task 36) exercises: a live overnight-window run, a forced-429/timeout path
(faked in tests), and confirms the no-key and unreachable builds show a normal
app with no overnight artifacts.

## 6. Out of scope for v0.4

Websocket streaming (not probed on Basic, not needed at 30s), index chips
overnight (indices don't trade; SPY/QQQ proxies would lie about the index),
search/add flows learning about overnight, any trading-adjacent feature, and any
change to pre/post behavior.

## 7. Task map

| # | Task | Depends on |
|---|------|-----------|
| 32 | Overnight session model + ET window classifier | design sign-off |
| 33 | Alpaca overnight quote source (client, auth, staleness, degradation) | 32 |
| 34 | Overnight polling wiring (cadence, lifecycle, batch composition) | 32, 33 |
| 35 | Overnight UI per the owner-picked option set | 32, 34, sign-off on §4 |
| 36 | Validation pass + fold locked design into DESIGN.md | 32–35 |
