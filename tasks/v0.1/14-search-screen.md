# 14 — Search screen

- **Status:** READY
- **Owner:** —
- **Blocked by:** 02 (theme), 05 (search repo), 07 (watchlist store), 08 (ARB strings)
- **Allowed new deps:** —

## Goal
The pushed search page: find a US ticker by symbol or name, add/remove it from the
watchlist in place.

## Scope
- in:
  - Pushed route from the 🔍 button; `‹ 搜股票` back affordance; autofocused cream input
    (`输入代码或名称，如 AAPL 或「苹果」`), debounced queries via `SearchRepository`.
  - Result rows: logo avatar (ticker-ring fallback), name + 中文名, exchange mini-tag
    (纳斯达克/NYSE), and a trailing button: green ＋ (adds) ↔ mint ✓ (already in list,
    tap removes). Updates `WatchlistRepository` immediately.
  - Empty query: a small curated `热门` list (hardcoded handful: e.g. META, SPY…).
  - Loading / no-results / error states in the cute voice (no design-rationale copy).
- out:
  - No search history, no filters.

## Acceptance criteria
- [ ] Typing searches (debounced); ＋/✓ toggles membership live and is reflected back on
      the watchlist screen without restart.
- [ ] Widget tests: result add/remove toggle, empty query shows 热门, error state.
- [ ] `format`/`analyze`/`test` clean; all strings via ARB.
