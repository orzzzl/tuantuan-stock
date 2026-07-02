# 06 — Market data: candles, YTD, session labeling

- **Status:** BLOCKED (needs 05)
- **Owner:** —
- **Blocked by:** 05
- **Allowed new deps:** — (extends the 05 client)

## Goal
Complete `QuoteRepository` against Yahoo's v8 `chart` endpoint: historical series for
every `ChartRange`, the YTD change the race ranking needs, and the pre/regular/post
session fields — semantics per docs/provider-report.md.

## Scope
- in:
  - candles(symbol, range) via v8 `chart`: intraday (`interval=5m`,
    `includePrePost=true`) for `day`; daily bars for week/month/quarter/ytd/year.
  - Baseline: **use `chartPreviousClose` from the same response** — verified in the
    spike to be the period-start close for every range (YTD = last year's final close).
    Expose a baseline helper so the chart (10) and detail screen (13) don't re-derive it.
  - `ytdChangePct`: current price vs the ytd range's `chartPreviousClose`.
  - Session: map v7 `marketState` (PRE/REGULAR/POST/PREPRE/POSTPOST/CLOSED) to the
    domain enum; `extChangePct` from the **state-matched** field (PRE → pre field;
    POST/POSTPOST/PREPRE → post field), `null` = no extended data. Capture real
    PRE/POST/CLOSED fixtures while implementing (the spike only observed PREPRE live).
- out:
  - No UI. No disk caching.

## Acceptance criteria
- [ ] Unit tests with mocked HTTP: candles per range, baseline == chartPreviousClose
      per range, ytdChangePct math, session mapping incl. null ext fields for every
      marketState fixture.
- [ ] `format`/`analyze`/`test` clean.
