import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';

/// Snapshot behind the price hero and stats grid.
final detailQuoteProvider = FutureProvider.family<Quote, String>(
  (ref, symbol) => ref.watch(quoteRepositoryProvider).quote(symbol),
);

/// Header identity (name/logo). Decoration only — a failed lookup renders
/// ticker fallbacks rather than erroring the screen.
final detailStockProvider = FutureProvider.family<Stock?, String>((
  ref,
  symbol,
) async {
  try {
    final bySymbol = await ref.watch(stockRepositoryProvider).stocks([symbol]);
    return bySymbol[symbol];
  } on DataFailure {
    return null;
  }
});

/// Candles + baseline for the selected range chip.
final detailChartProvider =
    FutureProvider.family<ChartSeries, ({String symbol, ChartRange range})>(
      (ref, args) =>
          ref.watch(quoteRepositoryProvider).chart(args.symbol, args.range),
    );
