# 24 — Session-aware auto-refresh: quotes + intraday chart

- **Status:** READY
- **Owner:** —
- **Blocked by:** —
- **Allowed new deps:** none

## Why

Owner report (2026-07-12): during regular trading hours every other stock app shows
the intraday line moving, but ours looks like a static image; pre/post-market numbers
don't update either. Root cause: `detailQuoteProvider`, `detailChartProvider`, and the
watchlist quote providers are all one-shot `FutureProvider`s — data is fetched once on
screen entry (or pull-to-refresh) and never again. The data sources are fine: Tencent
quotes and Sina 5-minute bars both update intraday; we just never re-ask.

## Goal

While a screen is visible and the market is in a live session, its numbers and the 1D
chart keep themselves current without user action — silently (no spinner flash, keep
showing the previous data until the new response lands). When the market is closed or
the app is backgrounded, the app is completely quiet.

## Polling cadence (owner-approved 2026-07-12)

These are unofficial free endpoints (Sina is referer-guarded); polling must stay
polite. Owner asked about 1s — rejected as too aggressive (throttling/IP-ban risk,
and the upstream tick granularity is ~3–5s anyway). Locked cadence, each a named
constant in one place so retuning is a one-line diff:

| What | Regular session | Pre/post market | Closed |
|------|-----------------|-----------------|--------|
| Detail screen: quote (single symbol) | 5s | 30s | off |
| Watchlist: batched quotes (one request) | 10s | 30s | off |
| Detail screen: 1D chart (Sina 5-min bars) | 60s | off | off |

## Scope

- in:
  - A single reusable polling mechanism (Riverpod-idiomatic: e.g. a timer that
    invalidates/refreshes the existing providers) — not a per-screen copy-paste.
  - Session awareness: pick the cadence from the current session (reuse the existing
    `MarketSession` / `cn_eastern_time.dart` logic; don't invent a second clock).
  - Lifecycle awareness: polling pauses when the app is backgrounded and resumes on
    foreground (`AppLifecycleState`); a screen that isn't mounted doesn't poll.
  - Silent updates: refreshes must not flip providers into `loading` visibly — the UI
    keeps the previous value until fresh data arrives (Riverpod's value-preserving
    refresh), no skeleton/shimmer replay, no scroll jump, no chart flicker.
  - Failure backoff: on consecutive fetch failures, back off (double the interval up
    to 5 min) and recover on the next success; never error the screen from a
    background refresh — keep showing the last good data.
  - Watchlist sort/rank updates from a background refresh must stay visually stable
    (rows may reorder, but no jank/flicker mid-scroll).
- out: websockets/push, tick-by-tick animation of the chart's last point (nice-to-have,
  split into its own task if wanted), any change to pull-to-refresh behavior, other
  chart ranges (5D/1M/…) which are fine as fetch-once.

## Acceptance criteria

- [ ] Provider/widget tests with a fake clock: regular session polls at the locked
      cadence; pre/post at 30s; closed → zero requests; backgrounded → zero requests
      until resume.
- [ ] Test: a refresh failure keeps the last good quote/chart on screen and backs off;
      next success restores the normal interval.
- [ ] Test: background refresh never renders a loading state over existing data.
- [ ] Manual (emulator, market open): detail screen 1D line visibly gains new points
      over a few minutes; watchlist prices change without touching the screen.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard tests).
- [ ] `format`/`analyze`/`test` clean.
