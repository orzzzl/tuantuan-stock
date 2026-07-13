# 35 — Overnight UI (per the owner-picked option set)

- **Status:** BLOCKED (owner pick of `docs/overnight-design.md` §4 + design sign-off)
- **Owner:** —
- **Blocked by:** 32, 34; owner decisions §4.1–§4.3
- **Allowed new deps:** none

## Why

Tasks 32–34 put live overnight values in `Quote` during the BOATS window; this
task makes them visible. The exact shape is an owner decision
(`docs/overnight-design.md` §4). **This spec is written for the recommended set
A1 + B1 + C1** — if the owner picks differently, this file gets amended (and, for
A2, a mini-chart sub-task split out) before the task flips READY.

## Scope (recommended set A1 + B1 + C1)

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
  - i18n whole-set change (pending owner OK in §4.1): zh 盘前/盘后/夜盘 ↔ en
    Pre / Post / Overnight; the 1D chart zone labels follow (Pre/Night →
    Pre/Post). Both ARB files move together; no mixed sets.
  - The 1D chart is otherwise untouched: no overnight drawing, plane keeps
    parking where the post line ends (C1).
- out: overnight mini-chart (only if the owner picks A2 — split into its own
  task then), night-theme dressing (C2 — separate follow-up if wanted), index
  chips, search screen.

## Acceptance criteria

- [ ] Widget tests: overnight session shows the 夜盘 line/chip with the right
      value and tint; missing overnight value shows nothing new; pre/post
      rendering is unchanged.
- [ ] Widget test: race order, medals, and day-change pills are identical before
      and during overnight ticks.
- [ ] zh and en label sets each render as a whole set (guard against mixing).
- [ ] Manual (emulator during a live BOATS window): rows show 夜盘 moves
      updating hands-off; airplane-mode (or unreachable) run shows a normal
      quiet app with no error UI.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard
      tests).
- [ ] `format`/`analyze`/`test` clean.
