# 29 — Provider spike v3: US overnight-session data source

- **Status:** IN PROGRESS (Codex)
- **Owner:** Codex
- **Blocked by:** —
- **Allowed new deps:** none (report-only spike)

## Goal

Produce `docs/provider-report-v3.md` with live-session evidence for realistic free
provider candidates. A candidate must be reachable from mainland China and the US,
need neither a paid key nor brokerage account, return a fresh BOATS overnight quote,
and sustain the app's 5 s / 10 s / 30 s / 60 s refresh cadences. The owner signs off
before any product work begins.

## Scope

- In: live endpoint probes, access/freshness findings, recommendation, and a
  high-level impact note for a possible `overnight` state.
- Out: app code, dependencies, credentials, subscriptions, and UI/chart design.

## Acceptance criteria

- [ ] Report records probes inside a BOATS session with timestamps and results.
- [ ] Every candidate covers fields, freshness, access/cadence, and China evidence or
      limitation.
- [ ] Report gives a plainly supported source recommendation or no-go.
- [ ] `tasks/README.md` includes this row while the spike is in progress.
