# 01 — Flutter scaffold (single-page shell)

- **Status:** READY
- **Owner:** —
- **Blocked by:** —
- **Allowed new deps:** flutter_riverpod, go_router; dev: custom_lint, riverpod_lint, flutter_lints

## Goal
An empty-but-runnable Flutter app for iOS + Android with the layered folder structure and
the **single-page navigation** from DESIGN.md: watchlist is the root route; detail and
search are pushed routes. No tab bar anywhere.

## Scope
- in:
  - `flutter create` at repo root (org id: `com.tuantuan.stock`, platforms: ios, android).
  - Folders under `lib/`: `app/`, `core/`, `domain/`, `data/`,
    `features/{watchlist,detail,search,chart}/`, `l10n/`.
  - `go_router`: `/` (watchlist placeholder), `/stock/:symbol` (detail placeholder),
    `/search` (search placeholder). Placeholder screens: centered label + working
    push/pop (a button on `/` opens each route).
  - `ProviderScope` at the root; thin `main.dart`.
  - Lints wired; `flutter analyze` clean.
- out:
  - No theme styling (02), no data, no real UI.

## Acceptance criteria
- [ ] `flutter run` launches on an iOS simulator and an Android emulator.
- [ ] `/` opens at launch; detail and search can be pushed and popped.
- [ ] No `NavigationBar`/`TabBar` in the tree.
- [ ] `dart format .` clean, `flutter analyze` clean, `flutter test` passes.
