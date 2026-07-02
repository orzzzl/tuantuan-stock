import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';

/// Read-only price data. Implementations throw [DataFailure] subtypes on
/// error.
abstract interface class QuoteRepository {
  /// Current snapshot for [symbol], including session and YTD fields.
  Future<Quote> quote(String symbol);

  /// Snapshots for [symbols] in one provider round-trip, keyed by symbol —
  /// the watchlist-refresh path. Unknown symbols are absent from the map.
  Future<Map<String, Quote>> quotes(List<String> symbols);

  /// Chart bars plus the range's 0% baseline for [symbol] over [range].
  Future<ChartSeries> chart(String symbol, ChartRange range);
}
