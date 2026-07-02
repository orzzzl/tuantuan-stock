import 'package:intl/intl.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';

extension AppLocalizationSets on AppLocalizations {
  List<String> get chartRangeLabels => [
    rangeDay,
    rangeWeek,
    rangeMonth,
    rangeQuarter,
    rangeYtd,
    rangeYear,
  ];

  List<String> get extendedSessionLabels => [
    preMarketSessionLabel,
    postMarketSessionLabel,
  ];

  String formatCompactNumber(num value) {
    return NumberFormat.compact(locale: localeName).format(value);
  }

  /// Formats a fractional value, so `0.0173` renders as `1.7%`.
  String formatPercent(num value, {int decimalDigits = 1}) {
    return NumberFormat.decimalPercentPattern(
      locale: localeName,
      decimalDigits: decimalDigits,
    ).format(value);
  }
}
