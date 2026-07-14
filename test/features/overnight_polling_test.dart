import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tuantuan_stock/core/app_lifecycle.dart';
import 'package:tuantuan_stock/core/live_polling.dart';
import 'package:tuantuan_stock/data/market/alpaca_overnight_client.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/data/market/live_market_refresh.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/data/market/overnight_polling.dart';
import 'package:tuantuan_stock/data/market/overnight_quote_coordinator.dart';
import 'package:tuantuan_stock/data/watchlist/watchlist_providers.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';
import 'package:tuantuan_stock/domain/repositories/watchlist_repository.dart';
import 'package:tuantuan_stock/features/detail/stock_detail_providers.dart';
import 'package:tuantuan_stock/features/watchlist/watchlist_race_providers.dart';

// 2026-07-13 is a Monday; all wall clocks below are US Eastern (EDT).
final _mondayNight = easternToUtc(DateTime.utc(2026, 7, 13, 20, 30));
final _mondayNoon = easternToUtc(DateTime.utc(2026, 7, 13, 12));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('ticks one union batch per 30s inside the window; the day '
      'chart poller stays silent', (tester) async {
    final clock = _MutableClock(_mondayNight);
    final client = _FakeOvernightClient(midpoints: {'AAA': 102}, clock: clock);
    final repository = _ClosedQuoteRepository();

    await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: repository,
      watchlist: const ['AAA', 'BBB'],
      detailSymbol: 'CCC',
      watchDayChart: true,
    );

    final settled = client.calls.length;
    expect(repository.chartCalls, 1);

    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(client.calls.length, settled + 1);
    expect(client.calls.last, ['AAA', 'BBB', 'CCC']);

    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(client.calls.length, settled + 2);
    expect(client.calls.last, ['AAA', 'BBB', 'CCC']);

    // The 1D chart poller must not wake up overnight.
    expect(repository.chartCalls, 1);
    expect(repository.snapshotCalls, 1);
  });

  testWidgets('outside the window the loop performs zero requests', (
    tester,
  ) async {
    final clock = _MutableClock(_mondayNoon);
    final client = _FakeOvernightClient(midpoints: {'AAA': 102}, clock: clock);

    await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: _ClosedQuoteRepository(),
      watchlist: const ['AAA'],
    );

    await tester.pump(const Duration(minutes: 10));
    await tester.pump();
    expect(client.calls, isEmpty);
  });

  testWidgets('crossing 20:00 ET starts polling without a restart', (
    tester,
  ) async {
    final clock = _MutableClock(
      easternToUtc(DateTime.utc(2026, 7, 13, 19, 59)),
    );
    final client = _FakeOvernightClient(midpoints: {'AAA': 102}, clock: clock);

    await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: _ClosedQuoteRepository(),
      watchlist: const ['AAA'],
    );

    expect(client.calls, isEmpty);

    clock.now = easternToUtc(DateTime.utc(2026, 7, 13, 20, 1));
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(client.calls, isNotEmpty);
    expect(client.calls.last, ['AAA']);
  });

  testWidgets('crossing 04:00 ET stops polling', (tester) async {
    final clock = _MutableClock(easternToUtc(DateTime.utc(2026, 7, 14, 3, 59)));
    final client = _FakeOvernightClient(midpoints: {'AAA': 102}, clock: clock);

    await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: _ClosedQuoteRepository(),
      watchlist: const ['AAA'],
      detailSymbol: 'AAA',
    );

    expect(client.calls, isNotEmpty);
    final inWindow = client.calls.length;

    clock.now = easternToUtc(DateTime.utc(2026, 7, 14, 4, 1));
    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    await tester.pump(const Duration(hours: 2));
    await tester.pump();
    expect(client.calls.length, inWindow);
  });

  testWidgets('Friday night never starts', (tester) async {
    final clock = _MutableClock(
      easternToUtc(DateTime.utc(2026, 7, 17, 19, 59)),
    );
    final client = _FakeOvernightClient(midpoints: {'AAA': 102}, clock: clock);

    await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: _ClosedQuoteRepository(),
      watchlist: const ['AAA'],
    );

    clock.now = easternToUtc(DateTime.utc(2026, 7, 17, 20, 1));
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    clock.now = easternToUtc(DateTime.utc(2026, 7, 18, 12));
    await tester.pump(const Duration(hours: 16));
    await tester.pump();
    expect(client.calls, isEmpty);
  });

  testWidgets('backgrounded means zero requests; resume in the window '
      'refreshes immediately', (tester) async {
    final clock = _MutableClock(_mondayNight);
    final client = _FakeOvernightClient(midpoints: {'AAA': 102}, clock: clock);

    final setLifecycle = await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: _ClosedQuoteRepository(),
      watchlist: const ['AAA'],
    );
    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    final beforePause = client.calls.length;
    expect(beforePause, greaterThan(0));

    setLifecycle(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(client.calls.length, beforePause);

    setLifecycle(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(client.calls.length, beforePause + 1);
  });

  testWidgets('no-value ticks keep the 30s cadence and a later success '
      're-lights the overnight values without a restart', (tester) async {
    final clock = _MutableClock(_mondayNight);
    final client = _FakeOvernightClient(midpoints: {}, clock: clock);
    final repository = _ClosedQuoteRepository();

    await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: repository,
      watchlist: const ['AAA'],
      detailSymbol: 'AAA',
    );

    final settled = client.calls.length;
    for (var tick = 1; tick <= 3; tick++) {
      await tester.pump(extendedSessionRefreshInterval);
      await tester.pump();
      expect(client.calls.length, settled + tick);
    }
    expect(find.text('closed:null'), findsOneWidget);

    client.midpoints = {'AAA': 102};
    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(find.text('overnight:2.00'), findsOneWidget);
    expect(repository.quoteCalls, 1);
  });

  testWidgets('failures back off to 5 min, recover on success, and never '
      'slow the CN pollers', (tester) async {
    final clock = _MutableClock(_mondayNight);
    final client = _FakeOvernightClient(midpoints: {'AAA': 102}, clock: clock)
      ..failing = true;
    final repository = _ClosedQuoteRepository();

    await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: repository,
      watchlist: const ['AAA'],
      detailSymbol: 'AAA',
    );

    // The immediate first tick failed, so the cadence doubles: 60s, 120s,
    // 240s, then the 5 min cap.
    final settled = client.calls.length;
    expect(settled, 1);

    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(client.calls.length, settled);
    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(client.calls.length, settled + 1);

    await tester.pump(const Duration(seconds: 120));
    await tester.pump();
    expect(client.calls.length, settled + 2);

    client.failing = false;
    await tester.pump(const Duration(seconds: 240));
    await tester.pump();
    expect(client.calls.length, settled + 3);

    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(client.calls.length, settled + 4);

    // The CN quote path slept through the whole outage untouched.
    expect(repository.quoteCalls, 1);
    expect(repository.snapshotCalls, 1);
  });

  testWidgets('a new snapshot re-merges the detail quote with no CN refetch, '
      'and a failed tick falls back to closed', (tester) async {
    final clock = _MutableClock(_mondayNight);
    final client = _FakeOvernightClient(midpoints: {'AAA': 102}, clock: clock);
    final repository = _ClosedQuoteRepository();

    await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: repository,
      watchlist: const ['AAA'],
      detailSymbol: 'AAA',
    );

    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(find.text('overnight:2.00'), findsOneWidget);

    client.midpoints = {'AAA': 103};
    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(find.text('overnight:3.00'), findsOneWidget);

    client.failing = true;
    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(find.text('closed:null'), findsOneWidget);

    expect(repository.quoteCalls, 1);
  });

  testWidgets('a new snapshot re-merges the watchlist batch with no CN '
      'refetch', (tester) async {
    final clock = _MutableClock(_mondayNight);
    final client = _FakeOvernightClient(midpoints: {'AAA': 102}, clock: clock);
    final repository = _ClosedQuoteRepository();

    await _pumpOvernightProbe(
      tester,
      clock: clock,
      client: client,
      repository: repository,
      watchlist: const ['AAA', 'BBB'],
      showWatchlistSessions: true,
    );

    await tester.pump(extendedSessionRefreshInterval);
    await tester.pump();
    expect(find.text('AAA:overnight BBB:closed'), findsOneWidget);
    expect(repository.snapshotCalls, 1);
  });
}

Future<void Function(AppLifecycleState)> _pumpOvernightProbe(
  WidgetTester tester, {
  required _MutableClock clock,
  required _FakeOvernightClient client,
  required QuoteRepository repository,
  required List<String> watchlist,
  String? detailSymbol,
  bool watchDayChart = false,
  bool showWatchlistSessions = false,
}) async {
  late void Function(AppLifecycleState) setLifecycle;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quoteRepositoryProvider.overrideWithValue(repository),
        watchlistRepositoryProvider.overrideWithValue(
          _StaticWatchlistRepository(watchlist),
        ),
        marketCacheStoreProvider.overrideWithValue(
          MarketCacheStore(SharedPreferencesAsync()),
        ),
        liveRefreshClockProvider.overrideWithValue(clock.call),
        overnightQuoteCoordinatorProvider.overrideWith((ref) {
          final coordinator = OvernightQuoteCoordinator(
            client: client,
            now: clock.call,
          );
          ref.onDispose(coordinator.dispose);
          return coordinator;
        }),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Consumer(
          builder: (context, ref, child) {
            setLifecycle = (state) =>
                ref.read(appLifecycleStateProvider.notifier).state = state;
            final batch = ref.watch(watchlistQuotesProvider);
            final detail = detailSymbol == null
                ? null
                : ref.watch(detailQuoteProvider(detailSymbol)).valueOrNull;
            if (watchDayChart && detailSymbol != null) {
              ref.watch(
                detailChartProvider((
                  symbol: detailSymbol,
                  range: ChartRange.day,
                )),
              );
            }
            ref.watch(overnightPollingProvider);
            final label = showWatchlistSessions
                ? (batch.valueOrNull?.quotes.entries
                          .map(
                            (entry) =>
                                '${entry.key}:${entry.value.session.name}',
                          )
                          .join(' ') ??
                      'none')
                : '${detail?.session.name}:'
                      '${detail?.extChangePct?.toStringAsFixed(2)}';
            return Text(label);
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
  return setLifecycle;
}

class _MutableClock {
  _MutableClock(this.now);

  DateTime now;

  DateTime call() => now;
}

class _FakeOvernightClient implements OvernightQuoteClient {
  _FakeOvernightClient({required this.midpoints, required this.clock});

  Map<String, double> midpoints;
  final _MutableClock clock;
  bool failing = false;
  final calls = <List<String>>[];

  @override
  bool get isEnabled => true;

  @override
  Future<Map<String, OvernightQuote>> latestQuotes(List<String> symbols) {
    calls.add(List.of(symbols));
    if (failing) return Future.error(const OvernightFeedFailure());
    return Future.value({
      for (final symbol in symbols)
        if (midpoints[symbol] case final double midpoint)
          symbol: OvernightQuote(midpoint: midpoint, timestamp: clock.now),
    });
  }
}

class _ClosedQuoteRepository implements QuoteSnapshotRepository {
  var quoteCalls = 0;
  var snapshotCalls = 0;
  var chartCalls = 0;

  Quote get _closedQuote => Quote(
    price: 100,
    dayChange: 0,
    dayChangePct: 0,
    open: 100,
    high: 101,
    low: 99,
    prevClose: 100,
    volume: 1000,
    asOf: DateTime.utc(2026, 7, 13, 20),
    session: MarketSession.closed,
  );

  @override
  Future<Quote> quote(String symbol) async {
    quoteCalls += 1;
    return _closedQuote;
  }

  @override
  Future<Map<String, Quote>> quoteSnapshots(List<String> symbols) async {
    snapshotCalls += 1;
    return {for (final symbol in symbols) symbol: _closedQuote};
  }

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) =>
      quoteSnapshots(symbols);

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) async {
    chartCalls += 1;
    return ChartSeries(baseline: 100, candles: const []);
  }
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
