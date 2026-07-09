/// Symbol mapping between the app's canonical tickers and the Tencent/Sina
/// query forms (provider-report-v2 §5), kept in one place so every CN
/// endpoint spells symbols the same way. The Tencent kline symbol
/// (`usAAPL.OQ`) is intentionally absent: it is never derived — always read
/// from Tencent quote field 2.
library;

/// Tencent quote symbols for the app's `^`-prefixed indices. Sina's `int_*`
/// index feed is months-stale and never queried (report §2.1).
const _tencentIndexByApp = {
  '^GSPC': 'usINX',
  '^IXIC': 'usIXIC',
  '^DJI': 'usDJI',
};

/// `qt.gtimg.cn` query symbol: `us` + the app ticker as-is (dots kept —
/// `usBRK.B`; `usBRK.B.N` would miss).
String tencentQuoteSymbol(String appSymbol) =>
    _tencentIndexByApp[appSymbol] ?? 'us$appSymbol';

/// `hq.sinajs.cn` query symbol: `gb_` + lowercase (dots kept), or null for
/// indices, which Sina has no live feed for.
String? sinaQuoteSymbol(String appSymbol) =>
    appSymbol.startsWith('^') ? null : 'gb_${appSymbol.toLowerCase()}';

/// App ticker for a Sina suggest symbol field: uppercase, with `$` — Sina's
/// spelling of the class-share dot (`brk$b`, report §5) — restored to `.`.
String appSymbolFromSuggest(String suggestSymbol) =>
    suggestSymbol.replaceAll(r'$', '.').toUpperCase();

/// The app's canonical exchange code (Yahoo-era spelling, see
/// `Stock.exchange`) for a Tencent full-code suffix: `.OQ` NASDAQ, `.N`
/// NYSE, `.AM` NYSE American/Arca. Indices (`.DJI`) have no exchange.
String exchangeFromTencentFullCode(String fullCode) {
  final dot = fullCode.lastIndexOf('.');
  if (dot <= 0) return '';
  return switch (fullCode.substring(dot + 1)) {
    'OQ' => 'NMS',
    'N' => 'NYQ',
    'AM' => 'PCX',
    _ => '',
  };
}
