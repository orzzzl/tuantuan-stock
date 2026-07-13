# 28 — ETF short display names (task 25 follow-up)

- **Status:** IN PROGRESS
- **Owner:** Claude
- **Blocked by:** —
- **Allowed new deps:** none

## Why

Owner report with screenshot (2026-07-12 evening, fix approved): ETF rows in the
watchlist show truncated issuer-first legal names. Task 25's curated map +
legal-suffix stripping works for companies, but ETFs fall through to raw
provider names, and ETF legal names put the issuer/trust boilerplate *first*
(ProShares Trust, Direxion Daily, VanEck ETF Tr, State Street SPDR) — so
one-line truncation keeps the boilerplate and drops the distinguishing part:

- TQQQ: "Proshares Trust …" / "纳斯达克100三倍做…"
- SSO:  "Proshares Trust …" / "标普500指数两倍做…" (en title identical to TQQQ after truncation)
- YINN: "Direxion Daily F…" / "富时中国三倍做多ET…"
- MOAT: "Vaneck Etf Tr Va…" / "VanEck Vectors晨星…"
- SPY:  "State Street Spd…" / "标普500指数ETF-SP…"
- VTI:  "Total Market ETF" / "美国全股市ETF-Vang…" (en OK — curated since task 25)

The zh names are product-first (better) but carry `-发行商` tails ("ETF-SPDR",
"ETF-Vang…") that waste the end of the line, and some lead with a latin issuer
("VanEck Vectors晨星…").

## Goal

ETF rows read at a glance in both locales, same bar as task 25 set for
companies: the name people actually call the fund ("纳指三倍做多" /
"UltraPro QQQ"), nothing truncates at normal row width.

## Design (extends task 25's three-tier resolution; no new tier)

1. **Curated map**: add popular ETFs to `companyShortNames` — at least the six
   observed rows, plus a sweep of the top-ETF universe (broad index, sector,
   bonds, commodities, crypto, China/international, leveraged/inverse retail
   favorites, income) in the same spirit as the 102-symbol logo pack. Punchy
   colloquial pairs, e.g. TQQQ (纳指三倍做多 / UltraPro QQQ), SPY
   (标普500 ETF / SPDR S&P 500). Where several funds track the same index, the
   flagship gets the plain name and the others carry the issuer (SPY 标普500
   ETF; VOO 先锋标普500 / Vanguard S&P 500; IVV 安硕标普500 / iShares S&P 500)
   — this re-titles VOO from task 25, intentionally.
2. **Generic fund cleanup** in `shortenCompanyName` for uncurated ETFs, gated
   on the name identifying itself as a fund (en: ETF/Fund/Trust/Shares/Tr
   token; zh: contains ETF/基金) so plain company names are untouched:
   - en: repeatedly strip leading issuer/trust boilerplate (ProShares Trust,
     Direxion (Shares ETF Trust) Daily, VanEck ETF Tr(ust)/Vectors,
     (State Street) SPDR, iShares Trust/Inc, Vanguard, Invesco, Schwab,
     Fidelity, WisdomTree, First Trust, Global X, GraniteShares); strip the
     "Select Sector SPDR (Fund)" tail; collapse trailing "ETF Trust" → "ETF"
     and "3X Shares" → "3X". Conservative: never strip to empty.
   - zh: strip the trailing `-发行商` latin tail ("…ETF-SPDR" → "…ETF") and a
     leading latin issuer ("VanEck Vectors晨星…" → "晨星…").
3. **Ticker** fallback unchanged.

The en-locale row *subtitle* (the zh line) was part of the owner report too
("VanEck Vectors晨星…", "标普500指数ETF-SP…") — `stockSubtitle` now resolves
the zh line the same way `stockTitle` does (curated zh → shortened zh →
ticker). Search keeps full names in both lines (task 25 rule) via a new
`stockFullSubtitle`, parallel to `stockFullTitle`.

## Scope

- in: curated ETF entries + fund-aware stripping in
  `lib/data/market/company_short_names.dart`; short zh subtitle resolution in
  `localized_sets.dart` (+ `stockFullSubtitle` for search); unit tests.
- out: logo pack, search ranking, provider/network changes, layout changes.

## Acceptance criteria

- [ ] Unit tests: curated ETF symbols → short pairs; uncurated en fund names
      (ProShares/Direxion/VanEck/State Street SPDR/Select Sector) → issuer
      boilerplate stripped; uncurated zh fund names → `-发行商` tail and
      leading latin issuer stripped; company names (incl. ones containing
      "Trust") unaffected; never strips to empty.
- [ ] Map guard tests still pass (non-empty, unique per language).
- [ ] Manual (AVD, zh + en): TQQQ, SSO, YINN, MOAT, SPY rows show the curated
      short names untruncated.
- [ ] `format`/`analyze`/`test` clean.
