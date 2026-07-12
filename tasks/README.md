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
| 24 | [Session-aware auto-refresh (quotes + intraday chart)](v0.3/24-session-aware-auto-refresh.md) | DONE (Codex, PR #27; manual market-open check deferred to Monday) | — |
| 25 | [Short display names (recognizable list at a glance)](v0.3/25-short-display-names.md) | DONE (Claude, PR #28) | — |
| 26 | [1D chart: fixed day axis + 盘前/盘后 zones, 团团 flies left→right](v0.3/26-day-progress-chart.md) | DONE (Codex, PR #29) | — |
| 27 | [Extended-hours chart data (spike + fill 26's zones)](v0.3/27-extended-hours-chart-data.md) | IN PROGRESS (Claude) | 24, 26 |

## Order of attack (v0.3)

- **Codex track:** 24 (auto-refresh) → 26 (day-axis chart; geometry stands alone,
  its pre/post zones start empty).
- **Claude track:** 25 (short names) → 27 (spike ext-hours minute source; fallback =
  accumulate from 24's polling into 26's seam).
- 24 and 25 run in parallel (polling wiring vs identity/presentation — disjoint).
