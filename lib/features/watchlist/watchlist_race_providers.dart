import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/data/watchlist/watchlist_providers.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';

/// Which column orders the race list. Medals always follow the day-change
/// race regardless of the active sort.
enum WatchlistSort { dayChange, marketCap, ytd }

final watchlistSortProvider = StateProvider<WatchlistSort>(
  (ref) => WatchlistSort.dayChange,
);

/// The index-strip symbols — real indices, no ETF proxies (04 report).
const indexStripSymbols = ['^GSPC', '^IXIC', '^DJI'];

/// Index-strip quotes (^GSPC / ^IXIC / ^DJI), independent of the watchlist.
final indexStripQuotesProvider = StreamProvider<CachedQuoteBatch>(
  (ref) => _quoteSnapshotBatches(ref, indexStripSymbols),
);

/// One batched quote snapshot refresh for the whole watchlist. This is the
/// first-paint path: slow chart-derived decorations are filled by separate
/// providers.
final watchlistQuotesProvider = StreamProvider<CachedQuoteBatch>((ref) async* {
  final symbols = await ref.watch(watchlistProvider.future);
  yield* _quoteSnapshotBatches(ref, symbols);
});

/// Slow YTD decoration for repositories whose quote snapshots intentionally
/// omit chart-derived fields. Non-snapshot repositories already include their
/// YTD state in [watchlistQuotesProvider].
final watchlistYtdQuotesProvider = FutureProvider<Map<String, Quote>>((
  ref,
) async {
  final repository = ref.watch(quoteRepositoryProvider);
  final symbols = await ref.watch(watchlistProvider.future);
  if (symbols.isEmpty) return const {};
  return switch (repository) {
    final QuoteYtdRepository ytdRepository => ytdRepository.ytdQuotes(symbols),
    final QuoteSnapshotRepository snapshotRepository =>
      snapshotRepository.quotes(symbols),
    _ => const {},
  };
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
final raceBoardProvider = Provider<AsyncValue<RaceBoard>>((ref) {
  final sort = ref.watch(watchlistSortProvider);
  final symbols = ref.watch(watchlistProvider);
  final quoteBatch = ref.watch(watchlistQuotesProvider);

  if (symbols case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (quoteBatch case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }

  final symbolList = symbols.valueOrNull;
  if (symbolList == null) return const AsyncLoading();
  if (symbolList.isEmpty) return const AsyncData(RaceBoard.empty);

  final quotes = quoteBatch.valueOrNull?.quotes;
  if (quotes == null) return const AsyncLoading();

  final stocks = ref.watch(watchlistStocksProvider).valueOrNull ?? const {};
  final ytdQuotes =
      ref.watch(watchlistYtdQuotesProvider).valueOrNull ?? const {};

  return AsyncData(
    RaceBoard.build(
      symbols: symbolList,
      quotes: quotes,
      stocks: stocks,
      ytdChangePctBySymbol: {
        for (final MapEntry(:key, :value) in ytdQuotes.entries)
          if (value.ytdChangePct != null) key: value.ytdChangePct!,
      },
      sort: sort,
    ),
  );
});

Stream<CachedQuoteBatch> _quoteSnapshotBatches(
  Ref ref,
  List<String> symbols,
) async* {
  final cache = ref.watch(marketCacheStoreProvider);
  if (symbols.isEmpty) {
    yield CachedQuoteBatch(
      quotes: const {},
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isStale: false,
    );
    return;
  }

  final cached = cache.hasServedFreshQuotes
      ? null
      : await cache.readQuoteSnapshots(symbols);
  if (cached != null) {
    yield cached;
    await Future<void>.delayed(Duration.zero);
  }

  try {
    final fresh = await _quoteSnapshots(ref, symbols);
    final fetchedAt = DateTime.now().toUtc();
    await cache.writeQuoteSnapshots(fresh, fetchedAt);
    cache.hasServedFreshQuotes = true;
    yield CachedQuoteBatch(quotes: fresh, fetchedAt: fetchedAt, isStale: false);
  } on Object {
    if (cached == null) rethrow;
  }
}

Future<Map<String, Quote>> _quoteSnapshots(Ref ref, List<String> symbols) {
  final repository = ref.watch(quoteRepositoryProvider);
  return switch (repository) {
    final QuoteSnapshotRepository snapshots => snapshots.quoteSnapshots(
      symbols,
    ),
    _ => repository.quotes(symbols),
  };
}

/// One watchlist row with its race positions resolved.
class RaceEntry {
  const RaceEntry({
    required this.symbol,
    required this.quote,
    required this.dayRank,
    this.stock,
    this.ytdChangePct,
    this.ytdRank,
  });

  final String symbol;
  final Quote quote;

  /// Identity (name/logo); null falls back to ticker-only rendering.
  final Stock? stock;

  /// Percent change since the first trading day of the year; null while the
  /// YTD decoration has not resolved for this symbol.
  final double? ytdChangePct;

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
    required Map<String, double> ytdChangePctBySymbol,
    required WatchlistSort sort,
  }) {
    final quoted = symbols.where(quotes.containsKey).toList();
    double? ytdChangePct(String symbol) =>
        ytdChangePctBySymbol[symbol] ?? quotes[symbol]!.ytdChangePct;

    final dayOrder = _stableSortedBy(
      quoted,
      (a, b) => quotes[b]!.dayChangePct.compareTo(quotes[a]!.dayChangePct),
    );
    final dayRanks = {
      for (final (i, symbol) in dayOrder.indexed) symbol: i + 1,
    };

    final ytdOrder = _stableSortedBy(
      quoted.where((symbol) => ytdChangePct(symbol) != null).toList(),
      (a, b) => ytdChangePct(b)!.compareTo(ytdChangePct(a)!),
    );
    final ytdRanks = {
      for (final (i, symbol) in ytdOrder.indexed) symbol: i + 1,
    };

    final displayOrder = switch (sort) {
      WatchlistSort.dayChange => dayOrder,
      WatchlistSort.marketCap => _stableSortedBy(
        quoted,
        (a, b) => _descNullsLast(quotes[a]!.marketCap, quotes[b]!.marketCap),
      ),
      WatchlistSort.ytd => _stableSortedBy(
        quoted,
        (a, b) => _descNullsLast(ytdChangePct(a), ytdChangePct(b)),
      ),
    };

    return RaceBoard([
      for (final symbol in displayOrder)
        RaceEntry(
          symbol: symbol,
          quote: quotes[symbol]!,
          stock: stocks[symbol],
          ytdChangePct: ytdChangePct(symbol),
          dayRank: dayRanks[symbol]!,
          ytdRank: ytdRanks[symbol],
        ),
    ]);
  }
}

/// Descending compare where unknown values sink to the bottom.
int _descNullsLast(double? a, double? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
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
