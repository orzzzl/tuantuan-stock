# tasks/

Each `NN-slug.md` is a self-contained, reviewable unit of work. The implementer claims any
task whose **Status** is `READY` (its blockers are all DONE). Numbers increase across the
whole project. See [`../AGENTS.md`](../AGENTS.md) for the working agreement and
[`../docs/DESIGN.md`](../docs/DESIGN.md) for the locked v3 design.

## v0.1 — cute US-stock price viewer (MVP)

| #  | Task | Status | Blocked by |
|----|------|--------|-----------|
| 01 | [Flutter scaffold (single-page shell)](v0.1/01-flutter-scaffold.md) | READY | — |
| 02 | [Cute theme foundation](v0.1/02-cute-theme.md) | BLOCKED | 01 |
| 03 | [Domain models + repository seams](v0.1/03-domain-seams.md) | READY | — |
| 04 | [Market data source (quotes/candles/search/logos)](v0.1/04-market-data-source.md) | BLOCKED | 03 |
| 05 | [Watchlist local persistence](v0.1/05-watchlist-persistence.md) | BLOCKED | 03 |
| 06 | [Sky/water chart widget](v0.1/06-sky-chart-widget.md) | BLOCKED | 02 |
| 07 | [Plane-rider mascot widget](v0.1/07-plane-rider-widget.md) | BLOCKED | 02 |
| 08 | [Watchlist screen (daily race)](v0.1/08-watchlist-screen.md) | BLOCKED | 02, 04, 05 |
| 09 | [Stock detail screen](v0.1/09-detail-screen.md) | BLOCKED | 04, 06, 07 |
| 10 | [Search screen](v0.1/10-search-screen.md) | BLOCKED | 04, 05 |
| 11 | [i18n (zh + en)](v0.1/11-i18n.md) | BLOCKED | 01 |
| 12 | [App icon](v0.1/12-app-icon.md) | BLOCKED | 01 |
| 13 | [CI: format + analyze + test](v0.1/13-ci.md) | BLOCKED | 01 |

Two tracks can start immediately in parallel: **01** (app shell) and **03** (pure-Dart
domain). UI track: 01 → 02 → 06/07 → 09; data track: 03 → 04/05 → 08/10.
