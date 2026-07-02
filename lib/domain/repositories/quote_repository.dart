import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';

/// Read-only price data. Implementations throw [DataFailure] subtypes on
/// error.
abstract interface class QuoteRepository {
  /// Current snapshot for [symbol], including session and YTD fields.
  Future<Quote> quote(String symbol);

  /// Snapshots for [symbols] in one provider round-trip, keyed by symbol —
  /// the watchlist-refresh path. Unknown symbols are absent from the map.
  Future<Map<String, Quote>> quotes(List<String> symbols);

  /// Chart bars for [symbol] over [range], oldest first.
  Future<List<Candle>> candles(String symbol, ChartRange range);
}
