# 09 — Stock detail screen

- **Status:** BLOCKED (needs 04, 06, 07)
- **Owner:** —
- **Blocked by:** 04, 06, 07
- **Allowed new deps:** —

## Goal
The pushed detail page per DESIGN.md §Stock detail: price hero, range chips, the
sky/water chart with the plane rider, and the stats grid.

## Scope
- in:
  - Header: back arrow, logo avatar (ticker-ring fallback), name + 中文名 (no exchange
    suffix), search 🔍 top-right.
  - **Price hero**: matcha gradient when up / coral when down; `现价 (USD)`, huge tabular
    price, `▲/▼ +Δ +Δ% 今天`; outside regular hours append the small session chip
    (`盘前/盘后 ±x.x%`).
  - Range chips: zh set `1日 1周 1月 3月 今年 1年` (en set via i18n); selection loads
    candles for that `ChartRange`.
  - `SkyChart` (06) wired to real candles: baseline = prev close for 1日, period-start
    close otherwise; **baseline centered**; the line may open above/below it (gaps).
  - `PlaneRider` (07) pinned at the line tip; state from tip position + slope:
    climbing / diving / underwater.
  - Stats grid (3×2 `CandyCard`s): 今开 / 最高(up tint) / 最低(down tint) / 昨收 /
    成交量 / 市值 — compact formatting (48.2M, 3.46T).
  - ⭐ toggles watch membership.
- out:
  - No crosshair/scrubbing interactions in v0.1.

## Acceptance criteria
- [ ] Hero + chart + rider react correctly to up-day, down-day, gap-open, and underwater
      fixtures (widget tests with canned candles).
- [ ] Range switching re-baselines the chart (今年 baseline = last year's final close).
- [ ] `format`/`analyze`/`test` clean; all strings via ARB.
