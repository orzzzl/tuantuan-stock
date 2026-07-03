import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  final localizations = AppLocalizationsEn();

  Future<_InMemoryWatchlistRepository> pumpWatchlist(
    WidgetTester tester, {
    List<String> watched = _watched,
    Map<String, Quote>? quotes,
    Map<String, Stock> stocks = const {},
  }) async {
    final watchlist = _InMemoryWatchlistRepository(watched);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quoteRepositoryProvider.overrideWithValue(
            _FakeQuoteRepository(quotes ?? _quotes),
          ),
          stockRepositoryProvider.overrideWithValue(
            _FakeStockRepository(stocks),
          ),
          watchlistRepositoryProvider.overrideWithValue(watchlist),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WatchlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets('market-cap sort reorders rows but medals stay put', (
    tester,
  ) async {
    await pumpWatchlist(tester);

    await tester.tap(find.byKey(WatchlistScreen.sortByMarketCapKey));
    await tester.pumpAndSettle();

    expect(rowY(tester, 'DDDD'), lessThan(rowY(tester, 'BBB')));
    expect(rowY(tester, 'BBB'), lessThan(rowY(tester, 'CCC')));
    expect(rowY(tester, 'CCC'), lessThan(rowY(tester, 'AAA')));

    expect(inRow('AAA', '🥇'), findsOneWidget);
    expect(inRow('DDDD', '4'), findsOneWidget);

    await tester.tap(find.byKey(WatchlistScreen.sortByChangeKey));
    await tester.pumpAndSettle();

    expect(rowY(tester, 'AAA'), lessThan(rowY(tester, 'BBB')));
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
    expect(tag.data, contains('-1.2%'));
    expect(find.byKey(WatchlistScreen.sessionTagKey('AAA')), findsNothing);
    expect(find.byKey(WatchlistScreen.sessionTagKey('CCC')), findsNothing);
  });

  testWidgets('empty watchlist shows the search nudge', (tester) async {
    await pumpWatchlist(tester, watched: const []);

    expect(find.text(localizations.emptyWatchlistTitle), findsOneWidget);
    expect(find.text(localizations.emptyWatchlistHint), findsOneWidget);
    expect(find.byKey(WatchlistScreen.emptySearchButtonKey), findsOneWidget);
    expect(find.text(localizations.raceHeaderTitle), findsNothing);
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

class _FakeStockRepository implements StockRepository {
  _FakeStockRepository(this.bySymbol);

  final Map<String, Stock> bySymbol;

  @override
  Future<Map<String, Stock>> stocks(List<String> symbols) async => {
    for (final symbol in symbols) symbol: ?bySymbol[symbol],
  };
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
