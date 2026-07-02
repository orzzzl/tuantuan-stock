import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';

/// Read-only price data for a single symbol. Implementations throw
/// [DataFailure] subtypes on error.
abstract interface class QuoteRepository {
  /// Current snapshot for [symbol], including session and YTD fields.
  Future<Quote> quote(String symbol);

  /// Chart bars for [symbol] over [range], oldest first.
  Future<List<Candle>> candles(String symbol, ChartRange range);
}
