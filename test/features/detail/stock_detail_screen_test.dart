import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/app/cute_palette.dart';
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
import 'package:tuantuan_stock/features/chart/plane_rider.dart';
import 'package:tuantuan_stock/features/chart/sky_chart.dart';
import 'package:tuantuan_stock/features/detail/stock_detail_screen.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_en.dart';

const _symbol = 'AAPL';

void main() {
  final localizations = AppLocalizationsEn();

  Future<(_FakeQuoteRepository, _InMemoryWatchlistRepository)> pumpDetail(
    WidgetTester tester, {
    Quote? quote,
    Map<ChartRange, ChartSeries>? seriesByRange,
    List<String> watched = const [],
  }) async {
    final quotes = _FakeQuoteRepository(
      quoteValue: quote ?? _quote(),
      seriesByRange:
          seriesByRange ??
          {
            ChartRange.day: _series(baseline: 100, closes: [101, 102, 103]),
          },
    );
    final watchlist = _InMemoryWatchlistRepository(watched);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quoteRepositoryProvider.overrideWithValue(quotes),
          stockRepositoryProvider.overrideWithValue(_FakeStockRepository()),
          watchlistRepositoryProvider.overrideWithValue(watchlist),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StockDetailScreen(symbol: _symbol),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (quotes, watchlist);
  }

  Gradient heroGradient(WidgetTester tester) {
    final hero = tester.widget<Container>(
      find.byKey(StockDetailScreen.heroKey),
    );
    return (hero.decoration! as BoxDecoration).gradient!;
  }

  PlaneRiderState riderState(WidgetTester tester) =>
      tester.widget<PlaneRider>(find.byType(PlaneRider)).state;

  SkyChart skyChart(WidgetTester tester) =>
      tester.widget<SkyChart>(find.byType(SkyChart));

  testWidgets('up day: matcha hero, up chart, climbing rider', (tester) async {
    await pumpDetail(
      tester,
      quote: _quote(dayChange: 2.1, dayChangePct: 1.0),
      seriesByRange: {
        ChartRange.day: _series(baseline: 100, closes: [101, 102, 103]),
      },
    );

    expect(heroGradient(tester), CuteColors.upGradient);
    expect(skyChart(tester).direction, ChartDirection.up);
    expect(riderState(tester), PlaneRiderState.climbing);
    expect(find.textContaining(localizations.todayLabel), findsOneWidget);
  });

  testWidgets('down day above water: coral hero, diving rider, session chip', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      quote: _quote(
        dayChange: -2.1,
        dayChangePct: -1.0,
        session: MarketSession.post,
        extChangePct: -1.5,
      ),
      seriesByRange: {
        ChartRange.day: _series(baseline: 100, closes: [105, 104, 102]),
      },
    );

    expect(heroGradient(tester), CuteColors.downGradient);
    expect(skyChart(tester).direction, ChartDirection.up);
    expect(riderState(tester), PlaneRiderState.diving);
    expect(
      find.textContaining(localizations.postMarketSessionLabel),
      findsOneWidget,
    );
    expect(find.textContaining('-1.5%'), findsOneWidget);
  });

  testWidgets('underwater: rider drowns below the baseline', (tester) async {
    await pumpDetail(
      tester,
      quote: _quote(dayChange: -4, dayChangePct: -3.8),
      seriesByRange: {
        ChartRange.day: _series(baseline: 100, closes: [99, 97, 95]),
      },
    );

    expect(skyChart(tester).direction, ChartDirection.down);
    expect(riderState(tester), PlaneRiderState.underwater);
  });

  testWidgets('gap open: the line starts away from the waterline', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      seriesByRange: {
        ChartRange.day: _series(baseline: 100, closes: [103, 104]),
      },
    );

    final chart = skyChart(tester);
    expect(chart.baseline, 100);
    expect(chart.candles.first.close, isNot(chart.baseline));
    expect(riderState(tester), PlaneRiderState.climbing);
  });

  testWidgets('range switch reloads, re-baselines, and re-labels everything', (
    tester,
  ) async {
    final (quotes, _) = await pumpDetail(
      tester,
      seriesByRange: {
        ChartRange.day: _series(baseline: 100, closes: [101, 102]),
        ChartRange.ytd: _series(baseline: 80, closes: [70, 95]),
      },
    );

    expect(skyChart(tester).baseline, 100);
    expect(skyChart(tester).baselineLabel, isNull);
    // 1D hero: the official day change (quote fixture: +2.00 / +2.0%).
    expect(
      find.text('▲ +2.00 +2.0% ${localizations.todayLabel}'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(StockDetailScreen.rangeChipKey(ChartRange.ytd)),
    );
    await tester.pumpAndSettle();

    expect(quotes.chartCalls, contains((_symbol, ChartRange.ytd)));
    expect(skyChart(tester).baseline, 80);
    expect(
      skyChart(tester).baselineLabel,
      localizations.skyChartBaselinePeriodStartLabel,
    );
    // Robinhood mode: hero now shows price (102) vs the YTD baseline (80).
    expect(
      find.text('▲ +22.00 +27.5% ${localizations.rangeYtd}'),
      findsOneWidget,
    );
  });

  testWidgets('star toggles watchlist membership', (tester) async {
    final (_, watchlist) = await pumpDetail(tester);

    expect(await watchlist.symbols(), isEmpty);

    await tester.tap(find.byKey(StockDetailScreen.watchToggleKey));
    await tester.pumpAndSettle();
    expect(await watchlist.symbols(), contains(_symbol));

    await tester.tap(find.byKey(StockDetailScreen.watchToggleKey));
    await tester.pumpAndSettle();
    expect(await watchlist.symbols(), isEmpty);
  });

  testWidgets('stats grid formats volume and market cap compactly', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      quote: _quote(volume: 48200000, marketCap: 3.46e12),
    );

    // The two-row chip strip pushes the grid below the test viewport.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();

    expect(find.text(localizations.statVolumeLabel), findsOneWidget);
    expect(find.text('48.2M'), findsOneWidget);
    expect(find.text('3.46T'), findsOneWidget);
  });
}

ChartSeries _series({required double baseline, required List<double> closes}) {
  return ChartSeries(
    baseline: baseline,
    candles: [
      for (final (i, close) in closes.indexed)
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
  double price = 102,
  double dayChange = 2,
  double dayChangePct = 2,
  int volume = 1000,
  double? marketCap = 1e12,
  MarketSession session = MarketSession.regular,
  double? extChangePct,
}) {
  return Quote(
    price: price,
    dayChange: dayChange,
    dayChangePct: dayChangePct,
    open: 100,
    high: 104,
    low: 96,
    prevClose: 100,
    volume: volume,
    marketCap: marketCap,
    ytdChangePct: 5,
    asOf: DateTime.utc(2026, 7, 2, 20),
    session: session,
    extChangePct: extChangePct,
  );
}

class _FakeQuoteRepository implements QuoteRepository {
  _FakeQuoteRepository({required this.quoteValue, required this.seriesByRange});

  final Quote quoteValue;
  final Map<ChartRange, ChartSeries> seriesByRange;
  final chartCalls = <(String, ChartRange)>[];

  @override
  Future<Quote> quote(String symbol) async => quoteValue;

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) async => {
    for (final symbol in symbols) symbol: quoteValue,
  };

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) async {
    chartCalls.add((symbol, range));
    return seriesByRange[range]!;
  }
}

class _FakeStockRepository implements StockRepository {
  @override
  Future<Map<String, Stock>> stocks(List<String> symbols) async => {
    for (final symbol in symbols)
      if (symbol == _symbol)
        symbol: const Stock(
          symbol: _symbol,
          name: 'Apple Inc.',
          zhName: '苹果',
          exchange: 'NMS',
        ),
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
