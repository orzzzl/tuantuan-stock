# 37 — Night dressing (C2 theming follow-up)

- **Status:** READY (task 35 merged as of 2026-07-13, PR #45)
- **Owner:** Claude
- **Blocked by:** 35
- **Allowed new deps:** none

## Why

The owner's v0.4 design sign-off (2026-07-13, `docs/overnight-design.md` §4)
picked C2: during the overnight window the app should dress for the night. This
was deliberately scoped out of the A1/B1 data pipeline (tasks 32–36) so a
cosmetic change can never block or destabilize the data work — it lands after
task 35.

## Scope

- in:
  - During `MarketSession.overnight` only: the 1D chart's sun/rain decoration
    swaps to a moon + stars, and 团团 wears a nightcap.
  - Pure theming keyed off the session state from task 32's classifier — the
    same signal the 夜盘 chip uses. When the overnight session ends (or the
    feed degrades to no value and the session reads `closed`), the dressing
    reverts to the normal decoration.
  - Zero geometry changes: the plane keeps parking where the post-market line
    ends (C1 behavior); no axis, zone, or layout changes of any kind.
- out: any data-layer change, any new session logic, plane animation changes,
  night theming outside the overnight window, dark-mode/theme-wide work.

## Acceptance criteria

- [ ] Widget test: overnight session renders moon + stars decoration and the
      nightcap; non-overnight sessions render exactly the pre-task-37 visuals.
- [ ] Widget test: chart geometry (zones, dividers, plane position) is
      identical with and without the night dressing.
- [ ] Assets/painting follow the existing decoration pattern (CuteColors only,
      repo guard tests pass).
- [ ] No `Text('literal')` (ARB only) — the dressing is visual-only; no new
      user-facing strings expected.
- [ ] `format`/`analyze`/`test` clean.
