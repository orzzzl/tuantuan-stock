# 40 — Forward P/E: no free source; decide hide-vs-spike

- **Status:** BLOCKED (owner decision needed)
- **Owner:** —
- **Blocked by:** —
- **Allowed new deps:** none (until a decision picks otherwise)

## Why

Owner field report (2026-07-21): the detail screen's Forward P/E stat never shows
a value, always rendering `—`. This is not a mapping bug: `cn_quote_repository.
dart:402` sets `forwardPe: null` unconditionally, with the comment "Not in the
Tencent payload," matching `docs/provider-report-v2.md` §4.1 (field 39 = trailing
P/E only; fields 41/43/50-67 are documented as deliberately unmapped — nothing our
models need). Re-verified live today (2026-07-21) against `web.ifzq.gtimg.cn`'s
current AAPL quote: field 39 is still trailing P/E; no field carries a forward
figure. Sina's `gb_` quote (fields 13/14 = EPS / trailing P/E, per §4.2) has no
forward P/E either. Neither of our two providers has ever exposed it — this has
been a known, permanent gap since the original v0.2 provider switch, not a
regression.

## Decision needed (owner)

- **D1 — hide the stat row.** A stat cell that can never populate ("—" forever)
  reads as broken rather than as "unavailable." Cheapest, immediate: drop the
  Forward P/E cell from the detail screen's stat grid
  (`lib/features/detail/stock_detail_screen.dart` around the `statForwardPeLabel`
  cell) until/unless a real source exists. Trailing P/E (which does work) stays.
- **D2 — spike a third data source for forward P/E only.** Would need its own
  provider spike (mainland-China reachability is the recurring constraint that
  drove the whole Tencent/Sina switch in v0.2 — a new provider must clear the same
  bar). Meaningful new integration surface for a single stat field in a look-only
  app; only worth it if the owner cares about this specific number enough to carry
  that cost.

Recommendation: D1. Forward P/E is a nice-to-have stat, not core to the "cute
price viewer" scope, and the cost of D2 (a third provider, re-litigating
reachability) is disproportionate to one field.

## Next step

Owner picks D1 or D2; file the implementation task once picked (D1 is small
enough to fold directly into whichever task picks it up, D2 needs its own spike
task following the provider-report-v2/v3 pattern).
