# 19 — Progressive first paint: list renders on the quote batch alone

- **Status:** READY
- **Owner:** —
- **Blocked by:** — (provider-agnostic; works against the current Yahoo layer and the
  future CN layer identically)
- **Allowed new deps:** none

## Why

Owner report (2026-07-07, from the US): ~1 minute to the first list. One structural
cause is ours regardless of provider: `raceBoardProvider` awaits quotes AND identities,
and `quotes()` internally awaits a YTD baseline chart per symbol — so the first paint
waits for nearly the whole request storm (~`8 + 3N` serialized requests for N symbols).

## Goal

The watchlist paints as soon as **one batched quote response** arrives. Everything
else — YTD ranks, logos/names, sparklines — streams in without blocking or reordering
jank.

## Scope

- in:
  - `lib/features/watchlist/watchlist_race_providers.dart` (+ screen): `raceBoardProvider`
    builds from quotes only; identity (`watchlistStocksProvider`) becomes a decoration
    layer that fills in as it resolves (ticker-ring + plain ticker until then — the
    designed fallback, so no new visual language).
  - `ytdChangePct`/`ytdRank` (`今年 #N` subtitle) tolerate late resolution: render the
    row without them, fill when ready (the `RaceEntry.ytdRank == null` path already
    exists — make it the normal transient state, not an error state).
  - Sparklines stay per-row async (they already are) — verify a pending spark never
    blocks row layout.
  - Sane loading states: skeleton/shimmer or cub placeholder consistent with the cute
    theme for the sub-second pre-quote window; no layout shift when decorations land.
  - `docs/DESIGN.md`: add a short "Loading" subsection describing this progressive
    order (quotes → decorations → sparklines) so the behavior spec stays the truth.
- out: data-layer changes (17/18), disk caches (20). Do not touch `quotes()` internals —
  if YTD still blocks inside the data layer when this task starts, treat it as slow
  decoration and don't wait for it (18 removes the blocking).

## Acceptance criteria

- [ ] Widget/provider tests: race board resolves with quotes only (identity + YTD
      futures never completing); rows show ticker fallback then update when identity
      lands; sort stays stable while decorations stream in.
- [ ] No `Text('literal')` (ARB only), no colors outside CuteColors (repo guard tests).
- [ ] `format`/`analyze`/`test` clean.
