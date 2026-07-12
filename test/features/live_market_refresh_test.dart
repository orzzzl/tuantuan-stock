import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tuantuan_stock/core/app_lifecycle.dart';
import 'package:tuantuan_stock/core/live_polling.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/data/market/live_market_refresh.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/data/watchlist/watchlist_providers.dart';
import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';
import 'package:tuantuan_stock/domain/repositories/watchlist_repository.dart';
import 'package:tuantuan_stock/features/detail/stock_detail_providers.dart';
import 'package:tuantuan_stock/features/watchlist/watchlist_race_providers.dart';

const _symbol = 'AAPL';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('detail quote polls every 5s in regular session', (tester) async {
    final repository = _PollingQuoteRepository(
      quoteSession: MarketSession.regular,
    );

    await _pumpDetailQuoteProbe(tester, repository);

    expect(repository.quoteCalls, 1);

    await tester.pump(
      detailQuoteRegularRefreshInterval - const Duration(milliseconds: 2),
    );
    expect(repository.quoteCalls, 1);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repository.quoteCalls, 2);
  });

  testWidgets('detail quote polls every 30s in extended sessions', (
    tester,
  ) async {
    final repository = _PollingQuoteRepository(
      quoteSession: MarketSession.post,
    );

    await _pumpDetailQuoteProbe(tester, repository);

    expect(repository.quoteCalls, 1);

    await tester.pump(
      extendedSessionRefreshInterval - const Duration(milliseconds: 2),
    );
    expect(repository.quoteCalls, 1);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repository.quoteCalls, 2);
  });

  testWidgets('closed detail quote does not schedule background requests', (
    tester,
  ) async {
    final repository = _PollingQuoteRepository(
      quoteSession: MarketSession.closed,
    );
    final sundayNoon = easternToUtc(DateTime.utc(2026, 7, 12, 12));

    await _pumpDetailQuoteProbe(tester, repository, clock: () => sundayNoon);

    expect(repository.quoteCalls, 1);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(repository.quoteCalls, 1);
  });

  testWidgets('closed detail quote wakes at the next live session boundary', (
    tester,
  ) async {
    final repository = _SequencedQuoteRepository([
      _quote(price: 100, session: MarketSession.closed),
      _quote(price: 101, session: MarketSession.pre),
    ]);
    final preMarketMinusOneMinute = easternToUtc(
      DateTime.utc(2026, 7, 13, 3, 59),
    );

    await _pumpDetailQuoteProbe(
      tester,
      repository,
      clock: () => preMarketMinusOneMinute,
    );

    expect(repository.quoteCalls, 1);

    await tester.pump(const Duration(seconds: 59));
    await tester.pump();
    expect(repository.quoteCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(repository.quoteCalls, 2);
  });

  testWidgets('polling pauses while backgrounded and resumes on foreground', (
    tester,
  ) async {
    final repository = _PollingQuoteRepository(
      quoteSession: MarketSession.regular,
    );
    final setLifecycle = await _pumpDetailQuoteProbe(tester, repository);

    expect(repository.quoteCalls, 1);

    setLifecycle(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(detailQuoteRegularRefreshInterval);
    await tester.pump();
    expect(repository.quoteCalls, 1);

    setLifecycle(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repository.quoteCalls, 2);
  });

  testWidgets('detail quote provider stops polling after it is unmounted', (
    tester,
  ) async {
    final repository = _PollingQuoteRepository(
      quoteSession: MarketSession.regular,
    );

    await _pumpDetailQuoteProbe(tester, repository);

    expect(repository.quoteCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(detailQuoteRegularRefreshInterval);
    await tester.pump();
    expect(repository.quoteCalls, 1);
  });

  testWidgets('watchlist batch uses 10s regular and 30s extended cadence', (
    tester,
  ) async {
    final regularRepository = _PollingQuoteRepository(
      snapshotSession: MarketSession.regular,
    );
    await _pumpWatchlistQuoteProbe(tester, regularRepository);

    expect(regularRepository.snapshotCalls, 1);

    await tester.pump(watchlistQuotesRegularRefreshInterval);
    await tester.pump();
    expect(regularRepository.snapshotCalls, 2);

    final extendedRepository = _PollingQuoteRepository(
      snapshotSession: MarketSession.pre,
    );
    await _pumpWatchlistQuoteProbe(tester, extendedRepository);

    expect(extendedRepository.snapshotCalls, 1);

    await tester.pump(watchlistQuotesRegularRefreshInterval);
    await tester.pump();
    expect(extendedRepository.snapshotCalls, 1);

    await tester.pump(
      extendedSessionRefreshInterval - watchlistQuotesRegularRefreshInterval,
    );
    await tester.pump();
    expect(extendedRepository.snapshotCalls, 2);
  });

  testWidgets('day chart polls at 60s and does not inherit quote cadence', (
    tester,
  ) async {
    final repository = _PollingQuoteRepository(
      quoteSession: MarketSession.regular,
    );

    await _pumpDetailChartProbe(tester, repository);

    expect(repository.quoteCalls, 1);
    expect(repository.chartCalls, 1);

    await tester.pump(detailQuoteRegularRefreshInterval);
    await tester.pump();
    expect(repository.quoteCalls, 2);
    expect(repository.chartCalls, 1);

    await tester.pump(
      detailDayChartRegularRefreshInterval - detailQuoteRegularRefreshInterval,
    );
    await tester.pump();
    expect(repository.chartCalls, 2);
  });

  testWidgets(
    'refresh failure keeps last quote, avoids loading, and backs off',
    (tester) async {
      final failedRefresh = Completer<Quote>();
      final repository = _SequencedQuoteRepository([
        _quote(price: 100, session: MarketSession.regular),
        failedRefresh.future,
        _quote(price: 101, session: MarketSession.regular),
      ]);
      final states = <AsyncValue<Quote>>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [quoteRepositoryProvider.overrideWithValue(repository)],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Consumer(
              builder: (context, ref, child) {
                final quote = ref.watch(detailQuoteProvider(_symbol));
                states.add(quote);
                return Text('${quote.valueOrNull?.price ?? 'none'}');
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(repository.quoteCalls, 1);
      expect(find.text('100.0'), findsOneWidget);

      await tester.pump(detailQuoteRegularRefreshInterval);
      await tester.pump();

      expect(repository.quoteCalls, 2);
      expect(find.text('100.0'), findsOneWidget);
      expect(states.last.hasValue, isTrue);
      expect(states.last.isLoading, isFalse);

      failedRefresh.completeError(StateError('temporary refresh failure'));
      await tester.pump();
      expect(find.text('100.0'), findsOneWidget);
      expect(states.last.hasValue, isTrue);
      expect(states.last.hasError, isFalse);

      await tester.pump(detailQuoteRegularRefreshInterval);
      await tester.pump();
      expect(repository.quoteCalls, 2);

      await tester.pump(detailQuoteRegularRefreshInterval);
      await tester.pump();
      expect(repository.quoteCalls, 3);
      expect(find.text('101.0'), findsOneWidget);
    },
  );
}

Future<void Function(AppLifecycleState)> _pumpDetailQuoteProbe(
  WidgetTester tester,
  QuoteRepository repository, {
  DateTime Function()? clock,
}) async {
  late void Function(AppLifecycleState) setLifecycle;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quoteRepositoryProvider.overrideWithValue(repository),
        if (clock != null) liveRefreshClockProvider.overrideWithValue(clock),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          setLifecycle = (state) =>
              ref.read(appLifecycleStateProvider.notifier).state = state;
          ref.watch(detailQuoteProvider(_symbol));
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
  return setLifecycle;
}

Future<void> _pumpDetailChartProbe(
  WidgetTester tester,
  QuoteRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [quoteRepositoryProvider.overrideWithValue(repository)],
      child: Consumer(
        builder: (context, ref, child) {
          ref.watch(detailQuoteProvider(_symbol));
          ref.watch(
            detailChartProvider((symbol: _symbol, range: ChartRange.day)),
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

Future<void> _pumpWatchlistQuoteProbe(
  WidgetTester tester,
  QuoteRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quoteRepositoryProvider.overrideWithValue(repository),
        watchlistRepositoryProvider.overrideWithValue(
          _StaticWatchlistRepository(const ['AAA', 'BBB']),
        ),
        marketCacheStoreProvider.overrideWithValue(
          MarketCacheStore(SharedPreferencesAsync()),
        ),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          ref.watch(watchlistQuotesProvider);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

ChartSeries _series() {
  return ChartSeries(
    baseline: 100,
    candles: [
      for (final (i, close) in const [100.0, 101.0, 102.0].indexed)
        Candle(
          time: DateTime.utc(2026, 7, 2, 14, i * 5),
          open: close - 0.5,
          high: close + 1,
          low: close - 1,
          close: close,
        ),
    ],
  );
}

Quote _quote({
  double price = 100,
  MarketSession session = MarketSession.regular,
}) {
  return Quote(
    price: price,
    dayChange: price - 100,
    dayChangePct: price - 100,
    open: 100,
    high: 104,
    low: 96,
    prevClose: 100,
    volume: 1000,
    asOf: DateTime.utc(2026, 7, 2, 20),
    session: session,
  );
}

class _PollingQuoteRepository implements QuoteSnapshotRepository {
  _PollingQuoteRepository({
    this.quoteSession = MarketSession.regular,
    MarketSession? snapshotSession,
  }) : snapshotSession = snapshotSession ?? quoteSession;

  final MarketSession quoteSession;
  final MarketSession snapshotSession;
  var quoteCalls = 0;
  var snapshotCalls = 0;
  var chartCalls = 0;

  @override
  Future<Quote> quote(String symbol) async {
    quoteCalls += 1;
    return _quote(price: 100 + quoteCalls.toDouble(), session: quoteSession);
  }

  @override
  Future<Map<String, Quote>> quoteSnapshots(List<String> symbols) async {
    snapshotCalls += 1;
    return {
      for (final (i, symbol) in symbols.indexed)
        symbol: _quote(
          price: 100 + snapshotCalls + i.toDouble(),
          session: snapshotSession,
        ),
    };
  }

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) =>
      quoteSnapshots(symbols);

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) async {
    chartCalls += 1;
    return _series();
  }
}

class _SequencedQuoteRepository implements QuoteRepository {
  _SequencedQuoteRepository(this._results);

  final List<Object> _results;
  var _index = 0;
  var quoteCalls = 0;

  @override
  Future<Quote> quote(String symbol) {
    quoteCalls += 1;
    final result = _results[_index++];
    return switch (result) {
      final Quote quote => Future.value(quote),
      final Future<Quote> future => future,
      final Object error => Future.error(error),
    };
  }

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) async {
    final quote = await this.quote(symbols.first);
    return {for (final symbol in symbols) symbol: quote};
  }

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) async => _series();
}

class _StaticWatchlistRepository implements WatchlistRepository {
  const _StaticWatchlistRepository(this._symbols);

  final List<String> _symbols;

  @override
  Stream<List<String>> watch() async* {
    yield _symbols;
  }

  @override
  Future<List<String>> symbols() async => _symbols;

  @override
  Future<void> add(String symbol) async {}

  @override
  Future<void> remove(String symbol) async {}
}
