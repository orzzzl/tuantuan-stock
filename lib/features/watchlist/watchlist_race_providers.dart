import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/data/market/yahoo_quote_repository.dart';
import 'package:tuantuan_stock/data/watchlist/watchlist_providers.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';

/// Which column orders the race list. Medals always follow the day-change
/// race regardless of the active sort.
enum WatchlistSort { dayChange, marketCap }

final watchlistSortProvider = StateProvider<WatchlistSort>(
  (ref) => WatchlistSort.dayChange,
);

/// Index-strip quotes (^GSPC / ^IXIC / ^DJI), independent of the watchlist.
final indexStripQuotesProvider = FutureProvider<Map<String, Quote>>(
  (ref) => ref.watch(quoteRepositoryProvider).quotes(indexStripSymbols),
);

/// One batched quote refresh for the whole watchlist.
final watchlistQuotesProvider = FutureProvider<Map<String, Quote>>((ref) async {
  final symbols = await ref.watch(watchlistProvider.future);
  if (symbols.isEmpty) return const {};
  return ref.watch(quoteRepositoryProvider).quotes(symbols);
});

/// Identities (names + logos) for the watchlist. Identity is row decoration,
/// so a failed lookup degrades to ticker fallbacks instead of erroring the
/// whole list.
final watchlistStocksProvider = FutureProvider<Map<String, Stock>>((ref) async {
  final symbols = await ref.watch(watchlistProvider.future);
  if (symbols.isEmpty) return const {};
  try {
    return await ref.watch(stockRepositoryProvider).stocks(symbols);
  } on DataFailure {
    return const {};
  }
});

/// Intraday candles behind each row's mini sparkline.
final daySparkProvider = FutureProvider.family<ChartSeries, String>(
  (ref, symbol) =>
      ref.watch(quoteRepositoryProvider).chart(symbol, ChartRange.day),
);

/// The assembled daily race, in display order with ranks resolved.
final raceBoardProvider = FutureProvider<RaceBoard>((ref) async {
  final sort = ref.watch(watchlistSortProvider);
  final symbols = await ref.watch(watchlistProvider.future);
  if (symbols.isEmpty) return RaceBoard.empty;
  final quotes = await ref.watch(watchlistQuotesProvider.future);
  final stocks = await ref.watch(watchlistStocksProvider.future);
  return RaceBoard.build(
    symbols: symbols,
    quotes: quotes,
    stocks: stocks,
    sort: sort,
  );
});

/// One watchlist row with its race positions resolved.
class RaceEntry {
  const RaceEntry({
    required this.symbol,
    required this.quote,
    required this.dayRank,
    this.stock,
    this.ytdRank,
  });

  final String symbol;
  final Quote quote;

  /// Identity (name/logo); null falls back to ticker-only rendering.
  final Stock? stock;

  /// 1-based position in today's day-change race — medals for 1–3.
  final int dayRank;

  /// 1-based rank by [Quote.ytdChangePct] within the watchlist; null while
  /// the YTD baseline hasn't resolved for this symbol.
  final int? ytdRank;
}

/// The watchlist resolved into display order plus per-row ranks.
class RaceBoard {
  const RaceBoard(this.entries);

  static const empty = RaceBoard([]);

  /// Rows in display order per [sort]. Symbols the quote batch didn't return
  /// are omitted.
  final List<RaceEntry> entries;

  /// Ranks by day change and YTD change (ties keep watchlist order), then
  /// orders rows by [sort].
  factory RaceBoard.build({
    required List<String> symbols,
    required Map<String, Quote> quotes,
    required Map<String, Stock> stocks,
    required WatchlistSort sort,
  }) {
    final quoted = symbols.where(quotes.containsKey).toList();

    final dayOrder = _stableSortedBy(
      quoted,
      (a, b) => quotes[b]!.dayChangePct.compareTo(quotes[a]!.dayChangePct),
    );
    final dayRanks = {
      for (final (i, symbol) in dayOrder.indexed) symbol: i + 1,
    };

    final ytdOrder = _stableSortedBy(
      quoted.where((symbol) => quotes[symbol]!.ytdChangePct != null).toList(),
      (a, b) => quotes[b]!.ytdChangePct!.compareTo(quotes[a]!.ytdChangePct!),
    );
    final ytdRanks = {
      for (final (i, symbol) in ytdOrder.indexed) symbol: i + 1,
    };

    final displayOrder = switch (sort) {
      WatchlistSort.dayChange => dayOrder,
      WatchlistSort.marketCap => _stableSortedBy(quoted, (a, b) {
        final capA = quotes[a]!.marketCap;
        final capB = quotes[b]!.marketCap;
        if (capA == null && capB == null) return 0;
        if (capA == null) return 1; // Unknown caps sink to the bottom.
        if (capB == null) return -1;
        return capB.compareTo(capA);
      }),
    };

    return RaceBoard([
      for (final symbol in displayOrder)
        RaceEntry(
          symbol: symbol,
          quote: quotes[symbol]!,
          stock: stocks[symbol],
          dayRank: dayRanks[symbol]!,
          ytdRank: ytdRanks[symbol],
        ),
    ]);
  }
}

/// `List.sort` is unstable; sorting (value, index) pairs keeps tied symbols
/// in their incoming order, which the YTD-rank acceptance rule requires.
List<String> _stableSortedBy(
  List<String> symbols,
  int Function(String a, String b) compare,
) {
  final indexed = symbols.indexed.toList()
    ..sort((a, b) {
      final byValue = compare(a.$2, b.$2);
      return byValue != 0 ? byValue : a.$1.compareTo(b.$1);
    });
  return [for (final (_, symbol) in indexed) symbol];
}
