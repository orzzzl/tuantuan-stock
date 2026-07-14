# 33 — Alpaca overnight quote source

- **Status:** DONE (Codex, PR #43, merged 2026-07-13)
- **Owner:** Codex
- **Blocked by:** 32
- **Allowed new deps:** none (plain `http` + `dart:convert`, same as the CN client)

## Why

The owner-approved overnight source (provider-report-v3c, signed off 2026-07-13)
is Alpaca Basic's derived `overnight` feed: one REST latest-quotes batch returns
real-time indicative quotes for the whole watchlist. This task builds that data
path — and nothing visible — behind the existing `QuoteRepository` seam.

The watchlist and detail screens poll the repository through independent
streams, so the union-batch guarantee cannot live on the quote path: this task
builds the shared `OvernightQuoteCoordinator` (design §5.2) that owns every
Alpaca request, and a request-free merge on the quote path.

## Scope

- in:
  - `AlpacaOvernightClient` in `lib/data/market/`: one
    `GET /v2/stocks/quotes/latest?symbols=...&feed=overnight` per call, batch of
    symbols in, per-symbol quote midpoints out. Auth headers from
    `ALPACA_KEY_ID` / `ALPACA_SECRET_KEY` `--dart-define`s; when either is empty
    the client reports itself disabled and the whole overnight path is a
    pass-through (design §3, §5.2). Secrets never appear in logs or errors.
  - `OvernightQuoteCoordinator` in `lib/data/market/` (design §5.2): the only
    caller of `AlpacaOvernightClient`. Owns the consumer symbol registry
    (register/unregister; polls the **union**), the **single-flight
    invariant** (at most one Alpaca request in flight; registry changes never
    fire a parallel request — at most they pull the next batched tick
    forward), and publishes an immutable `OvernightSnapshot` (per-symbol
    midpoint + quote timestamp + fetch time). This task builds the
    coordinator's fetch/registry/snapshot core; putting it on a clock is
    task 34.
  - A request-free merge on the repository path (design §5.2): a snapshot hit
    sets `session = overnight` and `extChangePct` = midpoint vs the latest
    regular close already carried by the Tencent/Sina quote; a miss (absent,
    stale, failed, outside window) returns the underlying quote untouched
    (`session` stays `closed`). The merge itself performs no I/O.
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

- [ ] Parser + merge unit tests over fixtures: happy batch, missing symbol,
      stale timestamp, malformed JSON, 429, timeout — each degrades to "no
      overnight value" with the underlying quote intact.
- [ ] Coordinator union test: watchlist set + a registered non-watchlist
      detail symbol ⇒ the next batch contains exactly their union; unregister
      drops the symbol from the following batch.
- [ ] Single-flight test (counting fake client): concurrent consumer activity
      — detail registration mid-fetch, overlapping tick triggers — never
      produces a second in-flight Alpaca request; total requests per tick is
      exactly one.
- [ ] No-key build test: with empty dart-defines the coordinator is provably
      inert (zero Alpaca requests attempted) and the merge is a pass-through.
- [ ] Outside-window test: zero Alpaca requests attempted.
- [ ] No credential value can reach logs, exceptions, or test output; nothing
      secret in the fixtures.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard
      tests).
- [ ] `format`/`analyze`/`test` clean.
