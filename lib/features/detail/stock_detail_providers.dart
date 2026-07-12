import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuantuan_stock/core/live_polling.dart';
import 'package:tuantuan_stock/data/market/live_market_refresh.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';

/// Snapshot behind the price hero and stats grid.
final detailQuoteProvider = StreamProvider.autoDispose.family<Quote, String>((
  ref,
  symbol,
) {
  return livePollingStream(
    ref: ref,
    fetch: () => ref.read(quoteRepositoryProvider).quote(symbol),
    interval: detailQuoteRefreshInterval,
    nullIntervalDelay: (_) =>
        closedSessionRefreshDelay(ref.read(liveRefreshClockProvider)()),
  );
});

final _detailQuoteSessionProvider = Provider.autoDispose
    .family<MarketSession?, String>(
      (ref, symbol) =>
          ref.watch(detailQuoteProvider(symbol)).valueOrNull?.session,
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
final detailChartProvider = StreamProvider.autoDispose
    .family<ChartSeries, ({String symbol, ChartRange range})>((ref, args) {
      return livePollingStream(
        ref: ref,
        fetch: () =>
            ref.read(quoteRepositoryProvider).chart(args.symbol, args.range),
        interval: (_) => args.range == ChartRange.day
            ? detailDayChartRefreshInterval(
                ref.read(_detailQuoteSessionProvider(args.symbol)),
              )
            : null,
        rescheduleWhen: [_detailQuoteSessionProvider(args.symbol)],
      );
    });
