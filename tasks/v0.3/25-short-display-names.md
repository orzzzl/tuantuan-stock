# 25 — Short display names: the list is recognizable at a glance

- **Status:** DONE (PR #28)
- **Owner:** Claude
- **Blocked by:** —
- **Allowed new deps:** none

## Why

Owner report (2026-07-12): watchlist row titles are the provider's full legal
names ("阿里巴巴集团控股有限公司", "Advanced Micro Devices Inc") — they truncate
and you can't tell what a row is at a glance. `stockTitle` in
`lib/l10n/localized_sets.dart` currently passes `zhName`/`name` straight through.

## Goal

Every row title is a short, instantly recognizable name — the name people
actually call the company ("苹果" / "Apple", "谷歌" / "Google", "台积电" /
"TSMC") — in both locales. Nothing truncates in a normal-width row.

## Design (three-tier resolution, first hit wins)

1. **Curated map** `companyShortNames`: symbol → (zh, en) colloquial short
   names, hand-checked, covering at least the same ~102 symbols as the bundled
   logo pack (`company_logos.dart`) plus the index-strip symbols. Colloquial
   beats legal: Alphabet → 谷歌/Google, Meta → Meta, Berkshire → 伯克希尔/
   Berkshire. Lives next to `company_logos.dart` in the data layer.
2. **Generic cleanup** of the provider name for unmapped symbols: strip legal
   suffixes and share-class tails. en: `Inc`, `Corp(oration)`, `Co`, `Ltd`,
   `Holdings`, `Group`, `PLC`, `-CL A`/`Class A` tails, trailing punctuation.
   zh: trailing `控股有限公司` / `股份有限公司` / `有限公司` / `公司` (keep
   `集团` — it's part of how people say the name, e.g. 阿里巴巴集团 → strip
   only the legal tail → 阿里巴巴集团 stays recognizable; curated map handles
   the big ones anyway). Conservative: only strip clearly-legal boilerplate,
   never the leading words.
3. **Ticker** fallback (unchanged) when there's no identity at all.

Apply in `stockTitle` (and detail-screen header, which uses the same helper or
should after this task). Subtitle (ticker line) unchanged. Search results may
keep the full name — full names help disambiguation there; in-scope only if
trivial.

## Scope

- in: short-name map + resolution helper + unit tests; wire into watchlist row
  title and detail header; guard that map entries are non-empty and unique.
- out: logo pack changes, search ranking, any provider/network change (this is
  purely presentational, offline data).

## Acceptance criteria

- [ ] Unit tests: mapped symbol → curated short name per locale; unmapped →
      suffix-stripped provider name (zh + en cases); no identity → ticker.
- [ ] Manual: default watchlist + index strip show no truncated titles on a
      normal phone width, zh and en locales.
- [ ] No `Text('literal')` (ARB only — the map is data, not UI copy, so it
      lives in the data layer like `company_logos.dart`), no colors outside
      CuteColors (repo guard tests).
- [ ] `format`/`analyze`/`test` clean.
