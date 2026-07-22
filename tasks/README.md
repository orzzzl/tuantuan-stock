# tasks/

Each `NN-slug.md` is a self-contained, reviewable unit of work. The implementer claims any
task whose **Status** is `READY` (its blockers are all DONE). Numbers increase across the
whole project. See [`../AGENTS.md`](../AGENTS.md) for the working agreement and
[`../docs/DESIGN.md`](../docs/DESIGN.md) for the locked v3 design.

## v0.1 — cute US-stock price viewer (MVP)

| #  | Task | Status | Blocked by |
|----|------|--------|-----------|
| 01 | [Flutter scaffold (single-page shell)](v0.1/01-flutter-scaffold.md) | DONE (Codex, PR #2) | — |
| 02 | [Cute theme foundation](v0.1/02-cute-theme.md) | DONE (Codex, PR #8) | — |
| 03 | [Domain models + repository seams](v0.1/03-domain-seams.md) | DONE (Claude, PR #5) | — |
| 04 | [Provider spike: validate the data source](v0.1/04-provider-spike.md) | DONE (Claude, PR #1) | — |
| 05 | [Market data: quotes / search / profile](v0.1/05-market-quotes-search.md) | DONE (Claude, PR #7) | 03, 04 |
| 06 | [Market data: candles / YTD / session](v0.1/06-market-candles-ytd.md) | DONE (Claude, PR #13) | 05 |
| 07 | [Watchlist local persistence](v0.1/07-watchlist-persistence.md) | DONE (Claude, PR #14) | 03 |
| 08 | [i18n (zh + en) — do early](v0.1/08-i18n.md) | DONE (Codex, PR #6) | — |
| 09 | [CI: format + analyze + test — do early](v0.1/09-ci.md) | DONE (Codex, PR #4) | — |
| 10 | [Sky/water chart widget](v0.1/10-sky-chart-widget.md) | DONE (Codex, PR #10) | 02, 03 |
| 11 | [Plane-rider mascot widget](v0.1/11-plane-rider-widget.md) | DONE (Codex, PR #11) | 02 |
| 12 | [Watchlist screen (daily race)](v0.1/12-watchlist-screen.md) | DONE (Claude, PR #16) | 02, 05, 06, 07, 08, 10 |
| 13 | [Stock detail screen](v0.1/13-detail-screen.md) | DONE (Claude, PR #17) | 05, 06, 07, 08, 10, 11 |
| 14 | [Search screen](v0.1/14-search-screen.md) | DONE (Claude, PR #15) | 02, 05, 07, 08 |
| 15 | [App icon](v0.1/15-app-icon.md) | DONE (Codex, PR #12) | — |

## Order of attack

- **Start now, in parallel:** 01 (scaffold) and 04 (provider spike — no code, de-risks
  the whole data plan; owner signs off on the report before 05/06).
- **Right after 01:** 09 (CI gate first, so every later PR is checked), then 08 (i18n —
  it blocks all screens), 02, 03 in any order.
- **Data track:** 03 + 04 → 05 → 06; 03 → 07.
- **UI track:** 02 → 10, 11.
- **Screens last:** 12 / 13 / 14 when their rows above are DONE. 15 anytime after 01.

## v0.2 — reachable from China + fast first paint

Driven by two owner field reports (2026-07-07): the app is completely unreachable from
mainland China (Yahoo/Google hosts are GFW-blocked), and even from the US the first
list takes ~1 minute (serialized request storm: ~`8 + 3N` requests before first paint).
Owner decision: **Tencent/Sina become the primary data source everywhere** (each
feature pinned to the better of the two — not runtime failover, not a China-only
fallback), and the first paint must be fast regardless of provider.

| #  | Task | Status | Blocked by |
|----|------|--------|-----------|
| 16 | [Provider spike v2: Tencent/Sina](v0.2/16-provider-spike-v2.md) | DONE (Claude, PR #20; owner signed off 2026-07-08) | — |
| 17 | [CN data layer: quotes / search / identity](v0.2/17-cn-quotes-search-identity.md) | DONE (Claude, PR #23) | 16 |
| 18 | [CN data layer: charts + YTD baselines](v0.2/18-cn-charts-ytd-session.md) | DONE (Codex, PR #25) | 16, 17 |
| 19 | [Progressive first paint](v0.2/19-progressive-first-paint.md) | DONE (Codex, PR #19) | — |
| 20 | [Persistent market cache](v0.2/20-persistent-market-cache.md) | DONE (Codex, PR #22) | 19 |
| 21 | [China-safe logos](v0.2/21-china-safe-logos.md) | DONE (Claude, PR #24) | 16, 17 |
| 22 | [Bundled fonts](v0.2/22-bundled-fonts.md) | DONE (Codex, PR #21) | — |
| 23 | [Yahoo removal + on-device verification](v0.2/23-yahoo-removal.md) | DONE (Claude, PR #26; US verified by owner 2026-07-12, China check deferred as non-blocking) | 17, 18, 20, 21 |

## Order of attack (v0.2)

- **Start now, in parallel:** 16 (spike — owner signs off on the report before 17/18),
  19 and 22 (provider-agnostic, no reason to wait).
- **Data track:** 16 → 17 → 18; 16 + 17 → 21.
- **Speed track:** 19 → 20 (20 builds on 19's provider restructure).
- **Last:** 23 sweeps Yahoo out and gates on real-device checks in both the US and
  China (the two original reports are the acceptance test).

## v0.3 — live data

Owner report (2026-07-12): during regular hours the chart looks like a static image
while every other stock app shows the intraday line moving, and pre/post-market
numbers never update either. Root cause: every quote/chart provider is a one-shot
`FutureProvider` — nothing in the app re-polls.

| #  | Task | Status | Blocked by |
|----|------|--------|-----------|
| 24 | [Session-aware auto-refresh (quotes + intraday chart)](v0.3/24-session-aware-auto-refresh.md) | DONE (Codex, PR #27; market-open check passed 2026-07-13) | — |
| 25 | [Short display names (recognizable list at a glance)](v0.3/25-short-display-names.md) | DONE (Claude, PR #28) | — |
| 26 | [1D chart: fixed day axis + 盘前/盘后 zones, 团团 flies left→right](v0.3/26-day-progress-chart.md) | DONE (Codex, PR #29) | — |
| 27 | [Extended-hours chart data (spike + fill 26's zones)](v0.3/27-extended-hours-chart-data.md) | DONE (Claude, PR #30; post-market zone check passed 2026-07-13; pre-market zone check passed 2026-07-14) | — |
| 28 | [ETF short display names (task 25 follow-up)](v0.3/28-etf-short-names.md) | DONE (Claude, PR #31) | — |

## Order of attack (v0.3)

- **Codex track:** 24 (auto-refresh) → 26 (day-axis chart; geometry stands alone,
  its pre/post zones start empty).
- **Claude track:** 25 (short names) → 27 (spike ext-hours minute source; fallback =
  accumulate from 24's polling into 26's seam).
- 24 and 25 run in parallel (polling wiring vs identity/presentation — disjoint).

## v0.4 — overnight session (夜盘)

Owner report (2026-07-12): broker applications show Blue Ocean ATS activity Sunday
night through the week, while the app stays frozen after post-market. Task 29 closed
the strict, cross-region search with a no-go. The follow-up permits a US-only source,
but it must degrade silently when unreachable from mainland China. The source
(Alpaca Basic `overnight` feed) is owner-signed as of 2026-07-13, and the product
design [`docs/overnight-design.md`](../docs/overnight-design.md) is **signed off
(owner, 2026-07-13): A1 + B1 + C2** — implementation is unblocked.

| #  | Task | Status | Blocked by |
|----|------|--------|-----------|
| 29 | [Provider spike v3: US overnight-session data source](v0.4/29-provider-spike-v3-overnight.md) | DONE (Codex, PR #32; owner signed off 2026-07-12) | — |
| 30 | [Provider spike v3b: US-only overnight-session data source](v0.4/30-overnight-spike-relaxed.md) | DONE (Codex, PR #33; owner signed off 2026-07-12) | — |
| 31 | [Provider spike v3c: Alpaca Basic overnight feed](v0.4/31-alpaca-overnight-spike.md) | DONE (Codex; owner signed off 2026-07-13) | — |
| 32 | [Overnight session model + ET window classifier](v0.4/32-overnight-session-model.md) | DONE (Codex, PR #41) | — |
| 33 | [Alpaca overnight quote source](v0.4/33-alpaca-overnight-source.md) | DONE (Codex, PR #43) | 32 |
| 34 | [Overnight polling wiring](v0.4/34-overnight-polling.md) | DONE (Claude, PR #44) | 32, 33 |
| 35 | [Overnight UI (A1 + B1)](v0.4/35-overnight-ui.md) | DONE (Claude, PR #45) | 32, 34 |
| 36 | [Overnight validation pass + DESIGN.md fold-in](v0.4/36-overnight-validation.md) | DONE (Codex, 2026-07-13: live, no-key, and unreachable runs passed) | — |
| 37 | [Night dressing (C2 theming follow-up)](v0.4/37-overnight-night-dressing.md) | DONE (Claude, PR #48) | 35 |

## Order of attack (v0.4)

- Spikes 29/30/31 are complete and owner-signed (31's §5 items approved 2026-07-13:
  the Alpaca Basic account/credential model and the implementation-phase
  validation). The product design
  [`docs/overnight-design.md`](../docs/overnight-design.md) is **signed off
  (owner, 2026-07-13): A1 + B1 + C2** — the gate is open.
- Pipeline: 32 → 33 → 34 → 35 → 36, then 37 (C2 theming — must not block or
  destabilize the data work). Split: Codex takes 32 then 33; Claude takes 34
  then 35. 36 (validation + DESIGN.md fold-in) and 37 get assigned when their
  blockers are close to done. Cross-review as always (`AGENTS.md`).
- The A1 i18n whole-set label change (Pre / Post / Overnight; 1D zone labels
  Pre/Night → Pre/Post) is owner-approved but vetoable until implemented: task
  35 keeps it in its own commit (or a clearly separable change).

## v0.5 — post-launch data quality (owner field reports, 2026-07-21)

Owner report (2026-07-21): Forward P/E never shows a value; the extended-session
tag sometimes reads stale/confusing (screenshot showed a **Post** tag matching the
day change while the device was offline, deep into the overnight window); the 1D
chart's pre/post zones are empty "most of the time." Diagnosed (no fix yet)
against the current code + fresh live provider checks:

| #  | Task | Status | Blocked by |
|----|------|--------|-----------|
| 38 | [Suppress stale pre/post/overnight tags when the cache is old](v0.5/38-stale-ext-session-tag.md) | READY (assigned: Claude) | — |
| 39 | [Pre/post chart coverage: revisit the task-27 trade-off](v0.5/39-ext-hours-chart-coverage-decision.md) | BLOCKED (owner decision) | — |
| 40 | [Forward P/E: no free source; decide hide-vs-spike](v0.5/40-forward-pe-decision.md) | BLOCKED (owner decision) | — |

## Order of attack (v0.5)

- 38 is a normal implementation task (root cause already diagnosed: cached
  `Quote.session`/`extChangePct` render with no staleness check) — pick it up
  like any other `READY` task.
- 39 and 40 are decision write-ups, not code: both lay out options and a
  recommendation, but need an explicit owner pick (mirrors the
  `docs/overnight-design.md` §4 sign-off pattern) before any implementation task
  gets filed under them.
