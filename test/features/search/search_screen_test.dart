import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/data/watchlist/watchlist_providers.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/domain/repositories/search_repository.dart';
import 'package:tuantuan_stock/domain/repositories/watchlist_repository.dart';
import 'package:tuantuan_stock/features/search/search_screen.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_en.dart';

const _amd = Stock(
  symbol: 'AMD',
  name: 'Advanced Micro Devices',
  exchange: 'NMS',
);
const _spy = Stock(symbol: 'SPY', name: 'SPDR S&P 500', exchange: 'PCX');

/// Long enough for the debounce timer to fire.
const _settle = Duration(milliseconds: 400);

void main() {
  final localizations = AppLocalizationsEn();

  Future<(_FakeSearchRepository, _InMemoryWatchlistRepository)> pumpSearch(
    WidgetTester tester, {
    Map<String, List<Stock>> results = const {},
    Object? searchError,
    List<String> watched = const [],
  }) async {
    final search = _FakeSearchRepository(results, error: searchError);
    final watchlist = _InMemoryWatchlistRepository(watched);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(search),
          watchlistRepositoryProvider.overrideWithValue(watchlist),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SearchScreen(),
        ),
      ),
    );
    await tester.pump();
    return (search, watchlist);
  }

  Future<void> enterQuery(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(SearchScreen.searchFieldKey), query);
    await tester.pump(_settle);
    await tester.pump();
  }

  testWidgets('empty query shows the curated trending list', (tester) async {
    final (search, _) = await pumpSearch(tester);

    expect(find.text(localizations.searchTrendingTitle), findsOneWidget);
    expect(find.text(localizations.trendingMetaName), findsOneWidget);
    expect(find.text(localizations.trendingSpyName), findsOneWidget);
    expect(find.byKey(SearchScreen.toggleKey('META')), findsOneWidget);
    expect(find.text(localizations.exchangeTagNasdaq), findsWidgets);
    expect(find.text(localizations.exchangeTagNyse), findsOneWidget);
    expect(search.queries, isEmpty);
  });

  testWidgets('typing debounces, then renders the matches', (tester) async {
    final (search, _) = await pumpSearch(
      tester,
      results: {
        'AMD': [_amd, _spy],
      },
    );

    await tester.enterText(find.byKey(SearchScreen.searchFieldKey), 'AM');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(SearchScreen.searchFieldKey), 'AMD');
    await tester.pump(_settle);
    await tester.pump();

    expect(search.queries, ['AMD']);
    expect(find.text(localizations.searchResultsTitle('AMD')), findsOneWidget);
    expect(find.text(_amd.name), findsOneWidget);
    expect(find.text(_spy.name), findsOneWidget);
    expect(find.text(localizations.searchTrendingTitle), findsNothing);
  });

  testWidgets('plus adds, check removes, and membership updates live', (
    tester,
  ) async {
    final (_, watchlist) = await pumpSearch(
      tester,
      results: {
        'AMD': [_amd, _spy],
      },
      watched: ['SPY'],
    );
    await enterQuery(tester, 'AMD');

    Icon toggleIcon(String symbol) => tester.widget<Icon>(
      find.descendant(
        of: find.byKey(SearchScreen.toggleKey(symbol)),
        matching: find.byType(Icon),
      ),
    );

    expect(toggleIcon('AMD').icon, Icons.add_rounded);
    expect(toggleIcon('SPY').icon, Icons.check_rounded);

    await tester.tap(find.byKey(SearchScreen.toggleKey('AMD')));
    await tester.pump();
    await tester.pump();
    expect(await watchlist.symbols(), ['SPY', 'AMD']);
    expect(toggleIcon('AMD').icon, Icons.check_rounded);

    await tester.tap(find.byKey(SearchScreen.toggleKey('AMD')));
    await tester.pump();
    await tester.pump();
    expect(await watchlist.symbols(), ['SPY']);
    expect(toggleIcon('AMD').icon, Icons.add_rounded);

    // A change made elsewhere (e.g. the watchlist screen) is reflected too.
    await watchlist.add('AMD');
    await tester.pump();
    expect(toggleIcon('AMD').icon, Icons.check_rounded);
  });

  testWidgets('a query with no matches shows the no-results state', (
    tester,
  ) async {
    await pumpSearch(tester);
    await enterQuery(tester, 'ZZZZ');

    expect(find.text(localizations.searchNoResultsLabel), findsOneWidget);
  });

  testWidgets('a failing search shows the error state', (tester) async {
    await pumpSearch(
      tester,
      searchError: const NetworkFailure('socket closed'),
    );
    await enterQuery(tester, 'AMD');

    expect(find.text(localizations.searchErrorLabel), findsOneWidget);
  });
}

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository(this.resultsByQuery, {this.error});

  final Map<String, List<Stock>> resultsByQuery;
  final Object? error;
  final queries = <String>[];

  @override
  Future<List<Stock>> search(String query) async {
    queries.add(query);
    final failure = error;
    if (failure != null) throw failure;
    return resultsByQuery[query] ?? const [];
  }
}

class _InMemoryWatchlistRepository implements WatchlistRepository {
  _InMemoryWatchlistRepository(List<String> initial)
    : _symbols = List.of(initial);

  final List<String> _symbols;
  final _changes = StreamController<List<String>>.broadcast();

  @override
  Stream<List<String>> watch() async* {
    yield List.of(_symbols);
    yield* _changes.stream;
  }

  @override
  Future<List<String>> symbols() async => List.of(_symbols);

  @override
  Future<void> add(String symbol) async {
    if (_symbols.contains(symbol)) return;
    _symbols.add(symbol);
    _changes.add(List.of(_symbols));
  }

  @override
  Future<void> remove(String symbol) async {
    if (_symbols.remove(symbol)) _changes.add(List.of(_symbols));
  }
}
