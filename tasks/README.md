# tasks/

Each `NN-slug.md` is a self-contained, reviewable unit of work. The implementer claims any
task whose **Status** is `READY` (its blockers are all DONE). Numbers increase across the
whole project. See [`../AGENTS.md`](../AGENTS.md) for the working agreement and
[`../docs/DESIGN.md`](../docs/DESIGN.md) for the locked v3 design.

## v0.1 — cute US-stock price viewer (MVP)

| #  | Task | Status | Blocked by |
|----|------|--------|-----------|
| 01 | [Flutter scaffold (single-page shell)](v0.1/01-flutter-scaffold.md) | DONE (Codex, PR #2) | — |
| 02 | [Cute theme foundation](v0.1/02-cute-theme.md) | READY | — |
| 03 | [Domain models + repository seams](v0.1/03-domain-seams.md) | READY | — |
| 04 | [Provider spike: validate the data source](v0.1/04-provider-spike.md) | DONE (Claude, PR #1) | — |
| 05 | [Market data: quotes / search / profile](v0.1/05-market-quotes-search.md) | BLOCKED | 03, 04 |
| 06 | [Market data: candles / YTD / session](v0.1/06-market-candles-ytd.md) | BLOCKED | 05 |
| 07 | [Watchlist local persistence](v0.1/07-watchlist-persistence.md) | BLOCKED | 03 |
| 08 | [i18n (zh + en) — do early](v0.1/08-i18n.md) | READY | — |
| 09 | [CI: format + analyze + test — do early](v0.1/09-ci.md) | DONE (Codex, PR #4) | — |
| 10 | [Sky/water chart widget](v0.1/10-sky-chart-widget.md) | BLOCKED | 02, 03 |
| 11 | [Plane-rider mascot widget](v0.1/11-plane-rider-widget.md) | BLOCKED | 02 |
| 12 | [Watchlist screen (daily race)](v0.1/12-watchlist-screen.md) | BLOCKED | 02, 05, 06, 07, 08, 10 |
| 13 | [Stock detail screen](v0.1/13-detail-screen.md) | BLOCKED | 05, 06, 07, 08, 10, 11 |
| 14 | [Search screen](v0.1/14-search-screen.md) | BLOCKED | 02, 05, 07, 08 |
| 15 | [App icon](v0.1/15-app-icon.md) | READY | — |

## Order of attack

- **Start now, in parallel:** 01 (scaffold) and 04 (provider spike — no code, de-risks
  the whole data plan; owner signs off on the report before 05/06).
- **Right after 01:** 09 (CI gate first, so every later PR is checked), then 08 (i18n —
  it blocks all screens), 02, 03 in any order.
- **Data track:** 03 + 04 → 05 → 06; 03 → 07.
- **UI track:** 02 → 10, 11.
- **Screens last:** 12 / 13 / 14 when their rows above are DONE. 15 anytime after 01.
