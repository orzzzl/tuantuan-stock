# 31 — Provider spike v3c: Alpaca Basic overnight feed

- **Status:** BLOCKED (Codex; live probe complete; owner data-source sign-off required)
- **Owner:** Codex
- **Blocked by:** Owner sign-off before any implementation task
- **Allowed new deps:** none (report-only, credentialed spike)

## Goal

Produce `docs/provider-report-v3c.md` with live BOATS-session evidence for Alpaca
Basic's derived `overnight` feed. The owner explicitly selected Alpaca's free Basic
plan and waived the project's no-account rule for this research only; no funding is
authorized. The owner must sign off on the finding before any implementation work is
specified.

The spike cannot begin until the owner locally provisions `ALPACA_KEY_ID` and
`ALPACA_SECRET_KEY` in `~/agents/secrets/alpaca.env`. Those credentials are runtime
input only and must never be copied into the repository, a PR, terminal output,
`ACTIVITY.log`, or the report.

## Scope

- In: a live Sunday–Thursday 20:00–04:00 ET BOATS-window probe of the documented
  derived `overnight` feed; fields, freshness, snapshot-on-request behavior, and
  plan/rate-limit evidence; and a high-level note of the approved future-feature
  constraints.
- In: comparison of a fresh observed value with an owner-provided broker-app reference
  when available; Basic-plan support for the locked 5 s / 10 s / 30 s / 60 s cadences;
  and whether one key can retrieve the whole watchlist in one tick (batch endpoint or
  Basic websocket, if supported).
- In: regular/pre/post Alpaca results only as a supplementary data point. Tencent/Sina
  remain primary for those sessions and China reachability remains required there.
- Out: product code, dependencies, broker funding, credential storage, credential
  logging, UI/chart design, and any new data-source decision or implementation design.

## Acceptance criteria

- [ ] The report records a BOATS-window probe of Alpaca Basic's derived `overnight`
      field, including returned fields and a fresh/stale result for each sampled symbol.
- [ ] The report establishes whether a documented REST latest-quote request supplies
      an immediate snapshot, rather than relying on delta-only events, and records the
      observed behavior against a broker-app reference when one is available.
- [ ] The report documents the Basic-plan contract for the locked 5 s / 10 s / 30 s /
      60 s cadences and for whole-watchlist retrieval, including any rate-limit,
      websocket, or batch-endpoint constraint.
- [ ] The report keeps any credentials redacted and records no secret material in git,
      PR text, logs, or `ACTIVITY.log`.
- [ ] The report preserves task 30's rule: an unavailable overnight source (including
      from mainland China) yields no overnight value and no user-visible error; it
      flags owner decisions rather than designing the implementation.
- [ ] `tasks/README.md` records task 30 as DONE and this task as IN REVIEW pending
      owner sign-off.
