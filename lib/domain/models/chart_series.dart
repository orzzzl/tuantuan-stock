import 'package:tuantuan_stock/domain/models/candle.dart';

/// A chart's bars plus its 0% waterline, fetched together so consumers never
/// re-derive the baseline.
class ChartSeries {
  const ChartSeries({required this.baseline, required this.candles});

  /// The 0% reference close for the range: previous regular-session close for
  /// a day chart, period-start close otherwise (YTD = last year's final
  /// close). Provider-verified per range in docs/provider-report.md.
  final double baseline;

  /// Bars oldest-first. May be empty outside trading windows.
  final List<Candle> candles;
}
