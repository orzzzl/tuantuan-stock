# 07 — Watchlist local persistence

- **Status:** BLOCKED (needs 03)
- **Owner:** —
- **Blocked by:** 03
- **Allowed new deps:** shared_preferences

## Goal
`WatchlistRepository` backed by on-device storage: saved symbols survive restarts.
Local-first, no account, no network.

## Scope
- in:
  - `lib/data/watchlist/`: impl storing the symbol set (JSON in shared_preferences).
  - add / remove / contains; expose the list as a Riverpod-watchable stream so UI updates
    live. No manual ordering (the UI sorts by race rules).
  - First run: empty list (screens handle the empty state).
- out:
  - No quote data, no UI.

## Acceptance criteria
- [ ] Symbols persist across restart; add/remove reflect immediately in a watcher.
- [ ] Unit tests with an in-memory prefs fake cover add/remove/persist/duplicate-add.
- [ ] `format`/`analyze`/`test` clean.
