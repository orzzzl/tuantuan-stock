# 38 — Suppress stale pre/post/overnight tags when the cache is old

- **Status:** DONE (Claude, PR #51)
- **Owner:** Claude
- **Blocked by:** —
- **Allowed new deps:** none

## Why

Owner field report (2026-07-21, screenshot): watchlist rows showed a **Post** tag
with a change % close to (sometimes identical to) the day-change pill, at a time
that maps to roughly 01:10 America/New_York — deep in the Blue Ocean overnight
window, hours after real post-market hours end. The screenshot's status bar shows
airplane mode on.

Root cause, confirmed by reading the code (no fix attempted yet):
`MarketCacheStore` persists a `Quote` including its `session` and `extChangePct`
verbatim, and every quote refresh path (`lib/data/market/cn_quote_repository.dart`,
`overnight_quote_repository.dart`) degrades to returning the last-known quote on
any fetch failure (network unreachable, airplane mode, etc.) — this is correct and
intentional for the regular/day-change numbers (task 19/20's fast-first-paint
design). But nothing in `lib/features/` or the cache layer checks whether a
**cached extended-session tag is still temporally valid**: if the last successful
fetch happened during real post-market hours and the device then went offline, the
`post` session and its `extChangePct` keep rendering, unchanged, for as long as the
device stays offline — including well into the following overnight/closed windows,
where they read as if they were live nighttime data.

This is not a math bug — `_extChangePct` and the overnight merge (`overnight_quote_
repository.dart:71`) both compute correctly relative to the regular close when they
run. It is a missing staleness check on the **cached** value.

## Scope

- in: before rendering a `pre`/`post`/`overnight` tag (watchlist row tiny line +
  detail hero chip, both switch on `MarketSession` today — see
  `lib/features/watchlist/watchlist_screen.dart:599` and
  `lib/features/detail/stock_detail_screen.dart:347`), check that the session the
  cached `Quote` claims is still one the **current** ET clock would actually
  produce (reuse the existing ET-window classifiers already used for pre/post
  bounds in `cn_quote_repository.dart` and for overnight in task 32's classifier).
  If the cached session no longer matches the current ET window (e.g. cached
  `post` but the ET clock now reads deep into the overnight window, or reads
  `closed`), treat the tag as absent — same rendering as `MarketSession.closed`
  today (no chip, no line). This must be a pure, local, synchronous check (current
  wall clock vs. session window) — no new network call, no new failure mode.
  Regular/day-change numbers, and quotes fetched fresh and successfully, are
  untouched.
- out: any "last updated at HH:MM" UI, any connectivity/offline indicator, any
  change to fetch/retry/backoff behavior, any change to how `session` gets
  written into the cache. Those are reasonable follow-ups but out of scope here —
  this task only prevents a stale extended-session tag from being *displayed* past
  its own window.

## Acceptance criteria

- [ ] Unit test: a cached `Quote` with `session: post` renders no tag when the
      current ET clock is inside the overnight or closed window.
- [ ] Unit test: a cached `Quote` with `session: post` still renders its tag when
      the current ET clock is genuinely still inside the post window (no
      regression to the normal, connected case).
- [ ] Unit test: same for cached `pre` and `overnight` sessions against a clock
      that has moved past their windows.
- [ ] No change to behavior when the quote fetch is succeeding normally (verify
      with the existing task 24/32 refresh tests).
- [ ] `format`/`analyze`/`test` clean.
