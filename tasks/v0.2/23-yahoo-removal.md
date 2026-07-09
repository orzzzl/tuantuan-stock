# 23 — Remove the Yahoo layer + real-world verification

- **Status:** CODE MERGED (PR #26) — awaiting owner device verification (US + China)
- **Owner:** Claude
- **Blocked by:** 17, 18, 20, 21
- **Allowed new deps:** none

## Goal

Once the CN source has feature parity, delete the Yahoo client/repositories (owner
decision: Tencent/Sina is THE source, not a fallback — no dead code kept "just in
case"), and verify the two original field reports are actually fixed on devices.

## Scope

- in:
  - Delete `yahoo_client.dart`, `yahoo_quote_repository.dart`,
    `yahoo_search_repository.dart`, `yahoo_stock_repository.dart`,
    `yahoo_company_profiles.dart`, their tests/fixtures, and any provider wiring or
    TODO(18) delegation remnants. `grep -ri yahoo lib/ test/` ends empty (docs may
    keep historical mentions).
  - Confirm the release AndroidManifest still carries INTERNET permission (the 07-02
    release-build gotcha) — the manifest isn't touched here, just re-checked.
  - Fresh release APK built from main and handed to the owner.
- out: new features.

## Acceptance criteria

- [x] No Yahoo/Google-favicon/gstatic references in `lib/` or `test/` (PR #26;
      re-checked on `main` at e497d88).
- [x] `format`/`analyze`/`test` clean (CI green on PR #26; reviewer re-ran locally).
- [ ] **US verification (owner):** cold start on device paints the cached board
      instantly and a fresh board within a few seconds — not a minute.
- [ ] **China verification (owner's wife, release APK):** app loads quotes, charts,
      search; fonts render; logos either load or fall back cleanly — no hangs. This
      criterion is checked by the owner relaying the result; note it in the PR and
      wait for it before closing the v0.2 goal.

Handoff note (2026-07-09): release APK for the verification gates built from `main`
at e497d88 — `build/app/outputs/flutter-apk/app-release.apk`.
