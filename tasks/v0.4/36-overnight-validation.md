# 36 — Overnight validation pass + fold the locked design into DESIGN.md

- **Status:** BLOCKED (design signed off by owner 2026-07-13; waiting on tasks 32–35)
- **Owner:** —
- **Blocked by:** 32, 33, 34, 35
- **Allowed new deps:** none

## Why

The owner's v3c §5 sign-off (2026-07-13) explicitly paired the data-source
approval with an **implementation-phase validation**: regional reachability
behavior, operational rate-limit handling, and the unchanged no-value/no-error
degradation rule. This task is that validation, run against the finished
feature, plus the docs closeout.

## Scope

- in:
  - **Live BOATS-window run** (emulator, Sun–Thu 20:00–04:00 ET): watchlist 夜盘
    values update hands-off at 30s; background/foreground behaves like the
    task-24 check (zero background requests, immediate resume); values are
    plausible against the owner's broker app when the owner can supply a
    reference glance.
  - **Degradation runs**: (a) airplane-mode / unreachable-host during the
    window — normal quiet app, no error UI, no retry storm (verify backoff via
    request counting in tests, not by log-watching); (b) a **no-key build** —
    provably zero Alpaca traffic and a pre-v0.4-identical UI; (c) forced 429
    and timeout paths covered by automated tests if not already in 33/34.
  - **Rate-limit posture**: confirm observed request volume is one batch per
    tick (2 req/min) on a realistic watchlist; confirm `X-RateLimit-Remaining`
    is read and a 429 feeds the backoff as a no-value tick.
  - **Docs closeout**: fold the owner-locked decisions (§4 picks + §5 mechanics
    as built) into `DESIGN.md` as the overnight section; update
    `docs/overnight-design.md` status from PROPOSAL to folded/locked; tick the
    board.
  - Mainland-China reachability remains **unverifiable from here**: record the
    expected behavior (no overnight, no error) in DESIGN.md and flag it for the
    owner's next real-world China session, the task-23 pattern (deferred,
    non-blocking).
- out: new features, cadence retuning (one-line diffs are fine if the owner asks
  later), any change to CN providers.

## Acceptance criteria

- [ ] The live-window, unreachable, and no-key runs above are performed and
      their outcomes recorded on the board row (date + result), with failures
      filed as bug rows instead of silently fixed.
- [ ] Automated coverage exists for 429/timeout/no-key/outside-window somewhere
      in 33/34/36 — no gaps among the four.
- [ ] DESIGN.md contains the locked overnight section; proposal doc updated;
      board rows 32–36 closed out.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard
      tests).
- [ ] `format`/`analyze`/`test` clean.
