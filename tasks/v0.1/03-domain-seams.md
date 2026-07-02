# 03 — Domain models + repository seams

- **Status:** READY
- **Owner:** —
- **Blocked by:** —
- **Allowed new deps:** freezed, freezed_annotation; dev: build_runner

## Goal
Pure-Dart domain: data shapes and the three repository interfaces everything else depends
on. No HTTP, no Flutter, no provider specifics.

## Scope
- in:
  - `lib/domain/models/`:
    - `Stock` (symbol, name, zhName?, exchange, logoUrl?)
    - `Quote` (price, dayChange, dayChangePct, open, high, low, prevClose, volume,
      marketCap, **ytdChangePct**, asOf, **session** enum pre/regular/post/closed,
      **extChangePct?** — the extended-hours move when session is pre/post)
    - `Candle` (time, open, high, low, close), `ChartRange` enum
      (day / week / month / quarter / **ytd** / year) with a `baseline` doc note:
      day → prev close; others → period-start close.
  - `lib/domain/repositories/`:
    - `QuoteRepository`: `quote(symbol)`, `candles(symbol, range)`.
    - `SearchRepository`: `search(query)` → `List<Stock>`.
    - `WatchlistRepository`: watch/add/remove the saved symbols (stream + snapshot).
  - A typed failure model for data errors (network / rate-limit / bad key / not found).
- out:
  - No implementations (04, 05). Zero `package:flutter` imports in `lib/domain`.

## Acceptance criteria
- [ ] `lib/domain` has no Flutter imports; interfaces documented with one-line contracts.
- [ ] `ChartRange` includes `ytd`; `Quote` includes `ytdChangePct`, `marketCap`, and the
      session fields (needed by the race screen's sort/rank and the 盘前/盘后 tags).
- [ ] `format`/`analyze`/`test` clean (simple model tests).
