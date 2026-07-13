# 30 — Provider spike v3b: US-only overnight-session data source

- **Status:** DONE (Codex, PR #33; owner signed off 2026-07-12)
- **Owner:** —
- **Blocked by:** —
- **Allowed new deps:** none (report-only spike)

## Goal

Produce `docs/provider-report-v3b.md` for a **free, keyless, no-account** overnight
quote source usable from US networks. Mainland-China reachability is deliberately not
a source criterion: when the overnight source is unavailable there, the eventual app
must show no overnight value and no error.

The owner must sign off on the result before implementation work is specified. This
spike does not authorize product code, credentials, subscriptions, or scraping.

## Scope

- In: live BOATS-window endpoint and streaming probes; freshness, access, protocol,
  cadence, and licensing/contract-risk findings; an explicit recommendation; and the
  graceful-degradation constraints for a future task.
- Out: app code, dependencies, credentials, subscriptions, UI/chart design, and any
  attempt to bypass authentication or access controls.

## Acceptance criteria

- [ ] The report records US-network probes inside a BOATS session, including a fresh
      overnight timestamp or a clear negative result for every investigated candidate.
- [ ] A keyless candidate, if technically reachable, has its wire contract,
      per-symbol snapshot behavior, cadence, and support/licensing risks recorded.
- [ ] The report states whether the relaxed requirement has a product-ready GO, a
      conditional research GO, or a NO-GO; a paid/account-backed fallback includes
      current published pricing when relevant.
- [ ] The report states the future no-data/no-error behavior required when the source
      is unreachable from mainland China.
- [ ] `tasks/README.md` records task 29 as DONE and this task while the spike is in
      progress.
