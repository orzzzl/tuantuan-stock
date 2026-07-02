# 12 — App icon

- **Status:** BLOCKED (needs 01)
- **Owner:** —
- **Blocked by:** 01
- **Allowed new deps:** dev: flutter_launcher_icons

## Goal
Launcher icon for iOS + Android: 团团 in the app's stock-watching identity, matching the
nudge icon family (cream background, candy shading).

## Scope
- in:
  - Icon art: 团团 flying its little orange plane, on the cream `#FFF7EF` background —
    reuse the mockup's plane-rider drawing as the base. Keep it readable at 48px.
  - Generate all densities via flutter_launcher_icons (adaptive icon on Android:
    cream bg layer + mascot foreground layer).
- out:
  - No splash screen work.

## Acceptance criteria
- [ ] Icon shows correctly on an iOS simulator home screen and an Android emulator
      (adaptive masks look right).
- [ ] Source art (SVG or layered PNG) committed under `assets/icon/`.
- [ ] `format`/`analyze`/`test` clean.
