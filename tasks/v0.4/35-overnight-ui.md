# 35 — Overnight UI (A1 + B1)

- **Status:** IN REVIEW (Claude, PR #45; manual BOATS-window check passed 2026-07-13)
- **Owner:** Claude
- **Blocked by:** 32, 34
- **Allowed new deps:** none

## Why

Tasks 32–34 put live overnight values in `Quote` during the BOATS window; this
task makes them visible. The owner signed off `docs/overnight-design.md` §4 on
2026-07-13 with the set **A1 + B1 + C2**: this task implements A1 + B1; C2 (night
dressing) is follow-up task 37 and must not ride along here. C1's plane behavior
(parks where the post line ends) remains in effect — this task adds no plane or
chart-geometry changes.

## Scope (signed-off set A1 + B1)

- in:
  - Session labeling grows the third state (DESIGN.md "Session labeling"
    pattern): during `MarketSession.overnight`, watchlist rows show a tiny 夜盘
    line under the change pill and the detail hero shows a small inline 夜盘
    chip, both carrying `extChangePct`. Headline price and day-change pill keep
    the official regular-session values — the daily race stays frozen at the
    close (medals, order, pills untouched).
  - Rows/hero re-render as overnight ticks arrive (30s), silently — no loading
    states over existing data, no scroll jump (task 24's silent-update rules
    apply unchanged).
  - Symbols with no overnight value this tick (stale, missing, degraded, or the
    whole feed unreachable — e.g. mainland China, or a no-key build) simply show
    no 夜盘 line/chip. The app must be visually indistinguishable from pre-v0.4
    in that case.
  - i18n whole-set change (owner-approved 2026-07-13, but vetoable until
    implemented — keep it in its own commit or a clearly separable change): zh
    盘前/盘后/夜盘 ↔ en Pre / Post / Overnight; the 1D chart zone labels follow
    (Pre/Night → Pre/Post). Both ARB files move together; no mixed sets.
  - The 1D chart is otherwise untouched: no overnight drawing, plane keeps
    parking where the post line ends (C1).
- out: overnight mini-chart (A2 — not picked), night-theme dressing (C2 —
  picked as follow-up task 37, blocked by this task), index chips, search
  screen.

## Acceptance criteria

- [x] Widget tests: overnight session shows the 夜盘 line/chip with the right
      value and tint; missing overnight value shows nothing new; pre/post
      rendering is unchanged.
- [x] Widget test: race order, medals, and day-change pills are identical before
      and during overnight ticks.
- [x] zh and en label sets each render as a whole set (guard against mixing).
- [x] Manual (emulator during a live BOATS window): rows show 夜盘 moves
      updating hands-off; airplane-mode (or unreachable) run shows a normal
      quiet app with no error UI.
- [x] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard
      tests).
- [x] `format`/`analyze`/`test` clean.
