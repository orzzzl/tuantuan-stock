# 32 — Overnight session model + ET window classifier

- **Status:** READY (design signed off by owner 2026-07-13: A1 + B1 + C2)
- **Owner:** Codex
- **Blocked by:** —
- **Allowed new deps:** none

## Why

v0.4 (`docs/overnight-design.md`) adds the BOATS overnight session
(Sun–Thu 20:00–04:00 ET) to the app. Everything downstream — the Alpaca source,
the polling gate, the UI label — keys off one question the domain cannot answer
today: "are we in the overnight window right now?". This task adds that answer
in one place so tasks 33–35 never invent their own clock.

## Scope

- in:
  - `MarketSession` gains `overnight` (semantics per design §5.1).
  - A pure function classifying an instant as inside/outside the overnight
    window, computed in `America/New_York` — reuse the existing eastern-time
    helpers; the session crosses midnight and must never be derived from a UTC
    calendar date. Sunday 20:00 → Monday 04:00 counts; Friday/Saturday nights do
    not.
  - `Quote.extChangePct` doc updated: it carries the overnight move when
    `session == overnight` (same field pre/post already use).
  - Exhaustive-switch fallout: every `switch` on `MarketSession` compiles and
    behaves sensibly with the new value (default = behave like `closed` until
    tasks 34/35 wire real behavior).
- out: any network code, polling changes, UI strings/widgets, holiday calendar
  (deliberately unmodeled — design §5.1).

## Acceptance criteria

- [ ] Unit tests: window boundaries (19:59/20:00/03:59/04:00 ET), the
      cross-midnight case, Sunday-start and Thursday-end edges, Friday and
      Saturday nights excluded, and a DST transition date.
- [ ] Adding the enum value breaks no existing behavior: regular/pre/post/closed
      classification and all current screens are unchanged (existing tests stay
      green, new switch arms are inert).
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard
      tests).
- [ ] `format`/`analyze`/`test` clean.
