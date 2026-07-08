import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/data/watchlist/watchlist_providers.dart';
import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';
import 'package:tuantuan_stock/domain/repositories/stock_repository.dart';
import 'package:tuantuan_stock/domain/repositories/watchlist_repository.dart';
import 'package:tuantuan_stock/features/watchlist/watchlist_screen.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_en.dart';

/// Day race: AAA 🥇 > BBB 🥈 > CCC 🥉 > DDDD (4). YTD race: BBB #1 > AAA #2 >
/// CCC #3, DDDD unresolved. Market caps: DDDD > BBB > CCC > AAA.
final _quotes = {
  'AAA': _quote(dayChangePct: 3, marketCap: 1e11, ytdChangePct: 10),
  'BBB': _quote(
    dayChangePct: 2,
    marketCap: 3e11,
    ytdChangePct: 30,
    session: MarketSession.post,
    extChangePct: -1.2,
  ),
  'CCC': _quote(dayChangePct: -1, marketCap: 2e11, ytdChangePct: -5),
  'DDDD': _quote(dayChangePct: -2, marketCap: 4e11),
};
const _watched = ['AAA', 'BBB', 'CCC', 'DDDD'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final localizations = AppLocalizationsEn();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<_InMemoryWatchlistRepository> pumpWatchlist(
    WidgetTester tester, {
    List<String> watched = _watched,
    Map<String, Quote>? quotes,
    Map<String, Stock> stocks = const {},
    QuoteRepository? quoteRepository,
    StockRepository? stockRepository,
    MarketCacheStore? marketCache,
    bool settle = true,
  }) async {
    final watchlist = _InMemoryWatchlistRepository(watched);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quoteRepositoryProvider.overrideWithValue(
            quoteRepository ?? _FakeQuoteRepository(quotes ?? _quotes),
          ),
          stockRepositoryProvider.overrideWithValue(
            stockRepository ?? _FakeStockRepository(stocks),
          ),
          if (marketCache != null)
            marketCacheStoreProvider.overrideWithValue(marketCache),
          watchlistRepositoryProvider.overrideWithValue(watchlist),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WatchlistScreen(),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return watchlist;
  }

  double rowY(WidgetTester tester, String symbol) =>
      tester.getTopLeft(find.byKey(WatchlistScreen.rowKey(symbol))).dy;

  Finder inRow(String symbol, String text) => find.descendant(
    of: find.byKey(WatchlistScreen.rowKey(symbol)),
    matching: find.text(text),
  );

  testWidgets('rows sort by day change with medals on the top-3 gainers', (
    tester,
  ) async {
    await pumpWatchlist(tester);

    expect(rowY(tester, 'AAA'), lessThan(rowY(tester, 'BBB')));
    expect(rowY(tester, 'BBB'), lessThan(rowY(tester, 'CCC')));
    expect(rowY(tester, 'CCC'), lessThan(rowY(tester, 'DDDD')));

    expect(inRow('AAA', '🥇'), findsOneWidget);
    expect(inRow('BBB', '🥈'), findsOneWidget);
    expect(inRow('CCC', '🥉'), findsOneWidget);
    expect(inRow('DDDD', '4'), findsOneWidget);
    expect(find.text(localizations.watchlistFooterHint), findsOneWidget);
  });

  testWidgets('YTD ranks follow ytdChangePct and skip unresolved symbols', (
    tester,
  ) async {
    await pumpWatchlist(
      tester,
      stocks: {
        'AAA': const Stock(
          symbol: 'AAA',
          name: 'Alpha Inc',
          zhName: '阿尔法',
          exchange: 'NMS',
        ),
      },
    );

    expect(find.text('Alpha Inc'), findsOneWidget);
    expect(
      inRow('AAA', '阿尔法 · ${localizations.ytdRankLabel(2)}'),
      findsOneWidget,
    );
    expect(
      inRow('BBB', 'BBB · ${localizations.ytdRankLabel(1)}'),
      findsOneWidget,
    );
    expect(
      inRow('CCC', 'CCC · ${localizations.ytdRankLabel(3)}'),
      findsOneWidget,
    );
    // No YTD baseline yet — the subtitle stays a plain identity line.
    final unrankedTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(WatchlistScreen.rowKey('DDDD')),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .whereType<String>();
    expect(unrankedTexts.any((text) => text.contains('#')), isFalse);
  });

  testWidgets(
    'rows paint from quote snapshots while identity and YTD resolve later',
    (tester) async {
      final stocks = Completer<Map<String, Stock>>();
      final ytdQuotes = Completer<Map<String, Quote>>();
      final snapshots = {
        'AAA': _quote(dayChangePct: 3, marketCap: 1e11),
        'BBB': _quote(
          dayChangePct: 2,
          marketCap: 3e11,
          session: MarketSession.post,
          extChangePct: -1.2,
        ),
        'CCC': _quote(dayChangePct: -1, marketCap: 2e11),
        'DDDD': _quote(dayChangePct: -2, marketCap: 4e11),
      };

      await pumpWatchlist(
        tester,
        quoteRepository: _ProgressiveQuoteRepository(
          snapshots: snapshots,
          ytdQuotes: ytdQuotes.future,
        ),
        stockRepository: _DeferredStockRepository(stocks.future),
      );

      expect(find.byKey(WatchlistScreen.rowKey('AAA')), findsOneWidget);
      expect(find.byKey(WatchlistScreen.rowKey('DDDD')), findsOneWidget);
      expect(inRow('AAA', 'AAA'), findsWidgets);
      expect(inRow('AAA', localizations.ytdRankLabel(1)), findsNothing);
      expect(rowY(tester, 'AAA'), lessThan(rowY(tester, 'BBB')));
      expect(rowY(tester, 'BBB'), lessThan(rowY(tester, 'CCC')));

      stocks.complete({
        'AAA': const Stock(
          symbol: 'AAA',
          name: 'Alpha Inc',
          zhName: '阿尔法',
          exchange: 'NMS',
        ),
      });
      await tester.pumpAndSettle();

      expect(find.text('Alpha Inc'), findsOneWidget);
      expect(inRow('AAA', '阿尔法'), findsOneWidget);
      expect(rowY(tester, 'AAA'), lessThan(rowY(tester, 'BBB')));

      ytdQuotes.complete(_quotes);
      await tester.pumpAndSettle();

      expect(
        inRow('AAA', '阿尔法 · ${localizations.ytdRankLabel(2)}'),
        findsOneWidget,
      );
      expect(
        inRow('BBB', 'BBB · ${localizations.ytdRankLabel(1)}'),
        findsOneWidget,
      );
      expect(rowY(tester, 'AAA'), lessThan(rowY(tester, 'BBB')));

      await tester.tap(find.byKey(WatchlistScreen.sortByYtdKey));
      await tester.pumpAndSettle();

      expect(rowY(tester, 'BBB'), lessThan(rowY(tester, 'AAA')));
      expect(inRow('BBB', '▲ +30.00%'), findsOneWidget);
    },
  );

  testWidgets('warm quote cache paints stale rows before fresh data lands', (
    tester,
  ) async {
    final cache = MarketCacheStore(SharedPreferencesAsync());
    final staleAt = DateTime.utc(2026, 7, 8, 4, 15);
    final freshQuotes = Completer<Map<String, Quote>>();
    final repository = _DeferredSnapshotQuoteRepository(freshQuotes.future);
    await cache.writeQuoteSnapshots({
      'AAA': _quote(dayChangePct: 3, marketCap: 1e11),
      'BBB': _quote(dayChangePct: 2, marketCap: 3e11),
    }, staleAt);

    await pumpWatchlist(
      tester,
      watched: const ['AAA', 'BBB'],
      quoteRepository: repository,
      stockRepository: _FakeStockRepository(const {}),
      marketCache: cache,
      settle: false,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(WatchlistScreen.rowKey('AAA')), findsOneWidget);
    expect(find.textContaining('As of'), findsOneWidget);

    freshQuotes.complete({
      'AAA': _quote(dayChangePct: 1, marketCap: 1e11),
      'BBB': _quote(dayChangePct: 4, marketCap: 3e11),
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('As of'), findsNothing);
    expect(rowY(tester, 'BBB'), lessThan(rowY(tester, 'AAA')));
  });

  testWidgets('pull-to-refresh does not flash the stale cue over fresh rows', (
    tester,
  ) async {
    final cache = MarketCacheStore(SharedPreferencesAsync());
    final repository = _SequencedSnapshotQuoteRepository();
    await cache.writeQuoteSnapshots({
      'AAA': _quote(dayChangePct: 3, marketCap: 1e11),
      'BBB': _quote(dayChangePct: 2, marketCap: 3e11),
    }, DateTime.utc(2026, 7, 8, 4, 15));

    await pumpWatchlist(
      tester,
      watched: const ['AAA', 'BBB'],
      quoteRepository: repository,
      stockRepository: _FakeStockRepository(const {}),
      marketCache: cache,
      settle: false,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('As of'), findsOneWidget);

    repository.completePending(_quotes);
    await tester.pumpAndSettle();
    expect(find.textContaining('As of'), findsNothing);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The refresh fetch is still in flight; the stale cue must not pop back
    // over the already-fresh rows.
    expect(find.textContaining('As of'), findsNothing);

    repository.completePending(_quotes);
    await tester.pumpAndSettle();
    expect(find.textContaining('As of'), findsNothing);
    expect(find.byKey(WatchlistScreen.rowKey('AAA')), findsOneWidget);
  });

  testWidgets(
    'market-cap sort reorders rows, headlines market caps, medals stay put',
    (tester) async {
      await pumpWatchlist(tester);

      await tester.tap(find.byKey(WatchlistScreen.sortByMarketCapKey));
      await tester.pumpAndSettle();

      expect(rowY(tester, 'DDDD'), lessThan(rowY(tester, 'BBB')));
      expect(rowY(tester, 'BBB'), lessThan(rowY(tester, 'CCC')));
      expect(rowY(tester, 'CCC'), lessThan(rowY(tester, 'AAA')));

      expect(inRow('AAA', '🥇'), findsOneWidget);
      expect(inRow('DDDD', '4'), findsOneWidget);

      // The headline figure is now the compact market cap, not the price.
      expect(inRow('DDDD', '400B'), findsOneWidget);
      expect(inRow('AAA', '100B'), findsOneWidget);

      await tester.tap(find.byKey(WatchlistScreen.sortByChangeKey));
      await tester.pumpAndSettle();

      expect(rowY(tester, 'AAA'), lessThan(rowY(tester, 'BBB')));
      expect(inRow('AAA', '🥇'), findsOneWidget);
      expect(inRow('AAA', '100B'), findsNothing);
    },
  );

  testWidgets('YTD sort reorders rows and pills show the YTD move', (
    tester,
  ) async {
    await pumpWatchlist(tester);

    await tester.tap(find.byKey(WatchlistScreen.sortByYtdKey));
    await tester.pumpAndSettle();

    // BBB (+30) > AAA (+10) > CCC (-5); DDDD's YTD is unresolved → last.
    expect(rowY(tester, 'BBB'), lessThan(rowY(tester, 'AAA')));
    expect(rowY(tester, 'AAA'), lessThan(rowY(tester, 'CCC')));
    expect(rowY(tester, 'CCC'), lessThan(rowY(tester, 'DDDD')));

    expect(inRow('BBB', '▲ +30.00%'), findsOneWidget);
    expect(inRow('CCC', '▼ -5.00%'), findsOneWidget);
    expect(inRow('DDDD', '—'), findsOneWidget);
    // Medals still belong to the day race.
    expect(inRow('AAA', '🥇'), findsOneWidget);
  });

  testWidgets('extended-session tag renders only outside regular hours', (
    tester,
  ) async {
    await pumpWatchlist(tester);

    final tag = tester.widget<Text>(
      find.byKey(WatchlistScreen.sessionTagKey('BBB')),
    );
    expect(tag.data, contains(localizations.postMarketSessionLabel));
    expect(tag.data, contains('-1.20%'));
    expect(find.byKey(WatchlistScreen.sessionTagKey('AAA')), findsNothing);
    expect(find.byKey(WatchlistScreen.sessionTagKey('CCC')), findsNothing);
  });

  testWidgets('empty watchlist shows the search nudge', (tester) async {
    await pumpWatchlist(tester, watched: const []);

    expect(find.text(localizations.emptyWatchlistTitle), findsOneWidget);
    expect(find.text(localizations.emptyWatchlistHint), findsOneWidget);
    expect(find.byKey(WatchlistScreen.emptySearchButtonKey), findsOneWidget);
    expect(find.byKey(WatchlistScreen.sortByChangeKey), findsNothing);
  });

  testWidgets('swipe-left removes a stock and undo restores it', (
    tester,
  ) async {
    final watchlist = await pumpWatchlist(tester);

    await tester.drag(
      find.byKey(WatchlistScreen.rowKey('CCC')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(WatchlistScreen.rowKey('CCC')), findsNothing);
    expect(await watchlist.symbols(), isNot(contains('CCC')));
    expect(find.text(localizations.removedSnackLabel('CCC')), findsOneWidget);

    await tester.tap(find.text(localizations.undoRemoveButtonLabel));
    await tester.pumpAndSettle();

    expect(await watchlist.symbols(), contains('CCC'));
    expect(find.byKey(WatchlistScreen.rowKey('CCC')), findsOneWidget);
  });
}

Quote _quote({
  required double dayChangePct,
  double? marketCap,
  double? ytdChangePct,
  MarketSession session = MarketSession.regular,
  double? extChangePct,
}) {
  return Quote(
    price: 100,
    dayChange: dayChangePct,
    dayChangePct: dayChangePct,
    open: 99,
    high: 104,
    low: 96,
    prevClose: 100,
    volume: 1000,
    marketCap: marketCap,
    ytdChangePct: ytdChangePct,
    asOf: DateTime.utc(2026, 7, 2, 20),
    session: session,
    extChangePct: extChangePct,
  );
}

class _FakeQuoteRepository implements QuoteRepository {
  _FakeQuoteRepository(this.bySymbol);

  final Map<String, Quote> bySymbol;

  @override
  Future<Quote> quote(String symbol) async => bySymbol[symbol]!;

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) async => {
    for (final symbol in symbols) symbol: ?bySymbol[symbol],
  };

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) async {
    return ChartSeries(
      baseline: 100,
      candles: [
        for (final (i, close) in const [99.0, 101.0, 103.0].indexed)
          Candle(
            time: DateTime.utc(2026, 7, 2, 14 + i),
            open: close - 1,
            high: close + 1,
            low: close - 2,
            close: close,
          ),
      ],
    );
  }
}

class _ProgressiveQuoteRepository implements QuoteSnapshotRepository {
  _ProgressiveQuoteRepository({
    required this.snapshots,
    required this.ytdQuotes,
  });

  final Map<String, Quote> snapshots;
  final Future<Map<String, Quote>> ytdQuotes;

  @override
  Future<Quote> quote(String symbol) async => snapshots[symbol]!;

  @override
  Future<Map<String, Quote>> quoteSnapshots(List<String> symbols) async => {
    for (final symbol in symbols) symbol: ?snapshots[symbol],
  };

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) async {
    final bySymbol = await ytdQuotes;
    return {for (final symbol in symbols) symbol: ?bySymbol[symbol]};
  }

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) {
    return Completer<ChartSeries>().future;
  }
}

class _DeferredSnapshotQuoteRepository implements QuoteSnapshotRepository {
  _DeferredSnapshotQuoteRepository(this.snapshots);

  final Future<Map<String, Quote>> snapshots;

  @override
  Future<Quote> quote(String symbol) async => (await snapshots)[symbol]!;

  @override
  Future<Map<String, Quote>> quoteSnapshots(List<String> symbols) async {
    final bySymbol = await snapshots;
    return {for (final symbol in symbols) symbol: ?bySymbol[symbol]};
  }

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) =>
      quoteSnapshots(symbols);

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) {
    return Completer<ChartSeries>().future;
  }
}

/// Hands out one pending future per snapshot fetch so a test can hold a
/// refresh in flight; [completePending] resolves every outstanding call.
class _SequencedSnapshotQuoteRepository implements QuoteSnapshotRepository {
  final _calls = <Completer<Map<String, Quote>>>[];

  void completePending(Map<String, Quote> quotes) {
    for (final call in _calls) {
      if (!call.isCompleted) call.complete(quotes);
    }
  }

  @override
  Future<Quote> quote(String symbol) async =>
      (await quoteSnapshots([symbol]))[symbol]!;

  @override
  Future<Map<String, Quote>> quoteSnapshots(List<String> symbols) {
    final call = Completer<Map<String, Quote>>();
    _calls.add(call);
    return call.future.then(
      (bySymbol) => {for (final symbol in symbols) symbol: ?bySymbol[symbol]},
    );
  }

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) =>
      quoteSnapshots(symbols);

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) {
    return Completer<ChartSeries>().future;
  }
}

class _FakeStockRepository implements StockRepository {
  _FakeStockRepository(this.bySymbol);

  final Map<String, Stock> bySymbol;

  @override
  Future<Map<String, Stock>> stocks(List<String> symbols) async => {
    for (final symbol in symbols) symbol: ?bySymbol[symbol],
  };
}

class _DeferredStockRepository implements StockRepository {
  _DeferredStockRepository(this.stocksBySymbol);

  final Future<Map<String, Stock>> stocksBySymbol;

  @override
  Future<Map<String, Stock>> stocks(List<String> symbols) async {
    final bySymbol = await stocksBySymbol;
    return {for (final symbol in symbols) symbol: ?bySymbol[symbol]};
  }
}

class _InMemoryWatchlistRepository implements WatchlistRepository {
  _InMemoryWatchlistRepository(List<String> initial) : _symbols = [...initial];

  final List<String> _symbols;
  final _changes = StreamController<List<String>>.broadcast();

  @override
  Stream<List<String>> watch() async* {
    yield List.unmodifiable(_symbols);
    yield* _changes.stream;
  }

  @override
  Future<List<String>> symbols() async => List.unmodifiable(_symbols);

  @override
  Future<void> add(String symbol) async {
    if (_symbols.contains(symbol)) return;
    _symbols.add(symbol);
    _changes.add(List.unmodifiable(_symbols));
  }

  @override
  Future<void> remove(String symbol) async {
    if (!_symbols.remove(symbol)) return;
    _changes.add(List.unmodifiable(_symbols));
  }
}
