import 'package:intl/intl.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';

extension AppLocalizationSets on AppLocalizations {
  /// Row title for a stock identity (task 17): a Chinese locale leads with
  /// the provider's Chinese name when it knows one; other locales keep the
  /// English name. [fallback] (the ticker) covers a missing identity.
  String stockTitle(Stock? stock, String fallback) {
    if (stock == null) return fallback;
    return _isChinese ? (stock.zhName ?? stock.name) : stock.name;
  }

  /// Row subtitle under [stockTitle]: the ticker in a Chinese locale (the
  /// Chinese name is the title there), otherwise the zh-name-or-ticker line
  /// unchanged from v0.1.
  String stockSubtitle(Stock? stock, String fallback) {
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
