# 33 — Alpaca overnight quote source

- **Status:** BLOCKED (owner design sign-off on `docs/overnight-design.md`)
- **Owner:** —
- **Blocked by:** 32; owner sign-off on the v0.4 design
- **Allowed new deps:** none (plain `http` + `dart:convert`, same as the CN client)

## Why

The owner-approved overnight source (provider-report-v3c, signed off 2026-07-13)
is Alpaca Basic's derived `overnight` feed: one REST latest-quotes batch returns
real-time indicative quotes for the whole watchlist. This task builds that data
path — and nothing visible — behind the existing `QuoteRepository` seam.

## Scope

- in:
  - `AlpacaOvernightClient` in `lib/data/market/`: one
    `GET /v2/stocks/quotes/latest?symbols=...&feed=overnight` per call, batch of
    symbols in, per-symbol quote midpoints out. Auth headers from
    `ALPACA_KEY_ID` / `ALPACA_SECRET_KEY` `--dart-define`s; when either is empty
    the client reports itself disabled and the whole overnight path is a
    pass-through (design §3, §5.2). Secrets never appear in logs or errors.
  - An overnight decorator over the existing repository path: inside the
    overnight window (task 32's classifier) it enriches the Tencent/Sina quote
    with `session = overnight` and `extChangePct` = midpoint vs the latest
    regular close already carried by the quote; outside the window, or on any
    failure, it returns the underlying quote untouched.
  - **Displayed value = quote midpoint** `(bid + ask) / 2` (Basic's only
    real-time field — trades are 15-min delayed and must not be used).
  - **Staleness guard**: `latestQuote.t` older than a named constant
    (20 minutes) ⇒ no overnight value for that symbol this tick.
  - **Failure = absence** (task 30 rule, owner-locked): short timeout (~8s),
    non-200, 429, malformed/empty payload — that tick yields no overnight value,
    with no error surfaced anywhere. Read `X-RateLimit-Remaining`; a 429 is a
    normal no-value tick.
  - Response fixtures under `test/fixtures/` (real shape from the v3c probe,
    values sanitized; no credential material).
- out: polling/cadence (task 34), UI (task 35), websockets, bars/snapshot
  endpoints (unless task 35's chosen option later needs bars — separate probe),
  any change to the CN providers.

## Acceptance criteria

- [ ] Parser + decorator unit tests over fixtures: happy batch, missing symbol,
      stale timestamp, malformed JSON, 429, timeout — each degrades to "no
      overnight value" with the underlying quote intact.
- [ ] No-key build test: with empty dart-defines the decorator is a provable
      pass-through (zero Alpaca requests attempted).
- [ ] Outside-window test: zero Alpaca requests attempted.
- [ ] No credential value can reach logs, exceptions, or test output; nothing
      secret in the fixtures.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard
      tests).
- [ ] `format`/`analyze`/`test` clean.
