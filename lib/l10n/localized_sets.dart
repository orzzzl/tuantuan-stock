import 'package:intl/intl.dart';
import 'package:tuantuan_stock/data/market/company_short_names.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';

extension AppLocalizationSets on AppLocalizations {
  /// Row/header title for a stock identity (task 25): the curated colloquial
  /// short name when the symbol is mapped, else the provider name with legal
  /// boilerplate conservatively stripped, so titles read at a glance instead
  /// of truncating. [fallback] (the ticker) covers a missing identity.
  String stockTitle(Stock? stock, String fallback) {
    if (stock == null) return fallback;
    final curated = companyShortName(stock.symbol);
    if (curated != null) return _isChinese ? curated.zh : curated.en;
    final zhName = stock.zhName;
    return _isChinese && zhName != null
        ? shortenCompanyName(zhName, chinese: true)
        : shortenCompanyName(stock.name, chinese: false);
  }

  /// Full provider name (the pre-task-25 [stockTitle]): search results keep
  /// the legal name — it helps disambiguation there.
  String stockFullTitle(Stock? stock, String fallback) {
    if (stock == null) return fallback;
    return _isChinese ? (stock.zhName ?? stock.name) : stock.name;
  }

  /// Row subtitle under [stockTitle]: the ticker in a Chinese locale (the
  /// Chinese name is the title there), otherwise the zh name resolved like
  /// [stockTitle] (task 28 — provider zh names carry issuer boilerplate that
  /// truncates the line).
  String stockSubtitle(Stock? stock, String fallback) {
    if (stock == null || _isChinese) return fallback;
    final curated = companyShortName(stock.symbol);
    if (curated != null) return curated.zh;
    final zhName = stock.zhName;
    return zhName == null
        ? fallback
        : shortenCompanyName(zhName, chinese: true);
  }

  /// Full-name variant of [stockSubtitle] for search results (task 25 rule:
  /// search keeps full names — they help disambiguation there).
  String stockFullSubtitle(Stock? stock, String fallback) {
    if (stock == null) return fallback;
    return _isChinese ? fallback : (stock.zhName ?? fallback);
  }

  bool get _isChinese => localeName.startsWith('zh');

  List<String> get chartRangeLabels => [
    rangeDay,
    rangeWeek,
    rangeMonth,
    rangeQuarter,
    rangeYtd,
    rangeYear,
    rangeYear5,
    rangeAll,
  ];

  List<String> get extendedSessionLabels => [
    preMarketSessionLabel,
    postMarketSessionLabel,
  ];

  String formatCompactNumber(num value) {
    return NumberFormat.compact(locale: localeName).format(value);
  }

  /// Formats a fractional value, so `0.0173` renders as `1.73%` (two
  /// decimals everywhere, like every brokerage app — owner call 2026-07-02).
  String formatPercent(num value, {int decimalDigits = 2}) {
    return NumberFormat.decimalPercentPattern(
      locale: localeName,
      decimalDigits: decimalDigits,
    ).format(value);
  }

  /// [formatPercent] with an explicit sign, so `0.0173` renders as `+1.73%`.
  String formatSignedPercent(num value, {int decimalDigits = 2}) {
    final formatted = formatPercent(value, decimalDigits: decimalDigits);
    return value >= 0 ? '+$formatted' : formatted;
  }

  /// Grouped two-decimal price/index formatting, so `5432.1` renders as
  /// `5,432.10`.
  String formatPrice(num value) {
    return NumberFormat.decimalPatternDigits(
      locale: localeName,
      decimalDigits: 2,
    ).format(value);
  }

  String formatShortDateTime(DateTime value) {
    return DateFormat.yMd(localeName).add_Hm().format(value.toLocal());
  }
}
