# 22 — Bundle fonts: no runtime font fetching

- **Status:** READY
- **Owner:** —
- **Blocked by:** —
- **Allowed new deps:** none (google_fonts stays; fonts move into assets)

## Why

google_fonts fetches font files from `fonts.gstatic.com` at runtime — GFW-blocked, so
in China text rendering stalls and falls back mid-session. Also a startup cost and a
flash-of-wrong-font everywhere else. Was already on the v0.2 candidate list.

## Goal

All fonts ship in the binary; zero font network I/O.

## Scope

- in: download the exact font files/weights the theme uses into `assets/fonts/` (mind
  the licenses — include the OFL files), register in `pubspec.yaml`, set
  `GoogleFonts.config.allowRuntimeFetching = false` at startup.
- out: any font/typography change — pixel-identical rendering is the point.

## Acceptance criteria

- [ ] `GoogleFonts.config.allowRuntimeFetching = false` set before first frame; app
      renders correctly with network fully disabled (airplane-mode smoke check noted
      in the PR).
- [ ] License files for the bundled fonts included in the repo/assets.
- [ ] `format`/`analyze`/`test` clean.
