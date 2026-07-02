# 12 — Watchlist screen (daily race)

- **Status:** READY
- **Owner:** —
- **Blocked by:** 02 (theme), 05 (quotes/logos/index), 06 (ytdChangePct for 今年 #N +
  session tags), 07 (watchlist store), 08 (ARB strings), 10 (`MiniSpark`)
- **Allowed new deps:** —

## Goal
The app's home screen per DESIGN.md §Watchlist: index strip + the daily race list, with
medals, YTD rank, sort toggle, and session tags. This is the root route; no tab bar.

## Scope
- in:
  - Top bar: brand `团团看盘 🌱`; **only** a search 🔍 button top-right (pushes `/search`).
  - Index strip: 标普500 / 纳斯达克 / 道琼斯 chips (value + day %, up/down tinted bg).
  - Race list (compact `CandyCard` rows, ~6 visible):
    - logo avatar with **medal badge** (🥇🥈🥉 for today's top-3 gainers; muted number
      badge for 4+); ticker-ring fallback when no logo.
    - name + subtitle `<中文名> · 今年 #N` (YTD-gain rank within the watchlist, integer).
    - `MiniSpark` (from 10), price, tinted day-change pill.
    - **Session tag**: when pre/post market, a tiny `盘前/盘后 ±x.x%` line under the pill.
  - Sort header: `今日排位赛 🏁` + toggle chips `涨跌幅` (default) / `市值`. Medals stay
    with today's top gainers regardless of sort.
  - Tap row → `/stock/:symbol`; swipe left → remove (with undo snackbar).
  - Empty state: friendly nudge to tap 🔍 and add stocks.
  - Footer hint: `按当日涨幅自动排序 · 左滑删除`.
- out:
  - Pull-to-refresh cadence/auto-refresh tuning can be minimal (manual pull is enough).

## Acceptance criteria
- [ ] Rows sorted by day change by default; toggle re-sorts by market cap; medals stay on
      the top-3 gainers in both orders.
- [ ] `今年 #N` ranks match ytdChangePct ordering (ties → same order stable).
- [ ] Widget tests: medal assignment, sort toggle, empty state, session tag rendering.
- [ ] `format`/`analyze`/`test` clean; all strings via ARB.
