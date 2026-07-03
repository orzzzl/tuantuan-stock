import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/app/app_theme.dart';
import 'package:tuantuan_stock/app/candy_card.dart';
import 'package:tuantuan_stock/app/cute_background.dart';
import 'package:tuantuan_stock/app/cute_palette.dart';
import 'package:tuantuan_stock/app/tuantuan_stock_app.dart';
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
import 'package:tuantuan_stock/features/detail/stock_detail_screen.dart';
import 'package:tuantuan_stock/features/search/search_screen.dart';
import 'package:tuantuan_stock/features/watchlist/watchlist_screen.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_en.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_zh.dart';
import 'package:tuantuan_stock/l10n/localized_sets.dart';

const _symbol = 'AAPL';

void main() {
  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quoteRepositoryProvider.overrideWithValue(_FakeQuoteRepository()),
          stockRepositoryProvider.overrideWithValue(_FakeStockRepository()),
          watchlistRepositoryProvider.overrideWithValue(
            _SingleStockWatchlistRepository(),
          ),
        ],
        child: TuanTuanStockApp(locale: locale),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('root pushes and pops detail and search routes', (tester) async {
    final localizations = AppLocalizationsEn();

    await pumpApp(tester);

    final theme = Theme.of(tester.element(find.byType(WatchlistScreen)));
    expect(find.byType(CuteBackground), findsOneWidget);
    expect(find.byType(CandyCard), findsWidgets);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(theme.colorScheme.primary, CuteColors.matcha);
    expect(theme.colorScheme.surfaceContainerHighest, CuteColors.borderWarm);
    expect(theme.textTheme.titleLarge?.fontFamily, contains('Baloo'));
    expect(
      theme.textTheme.titleLarge?.fontFamilyFallback?.join(','),
      contains('ZCOOL'),
    );
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w900);
    expect(theme.textTheme.bodySmall?.fontWeight, FontWeight.w600);

    expect(find.byType(WatchlistScreen), findsOneWidget);
    expect(find.text(localizations.brandTitle), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(find.byKey(WatchlistScreen.rowKey(_symbol)));
    await tester.pumpAndSettle();

    expect(find.byType(StockDetailScreen), findsOneWidget);
    expect(find.text(localizations.detailPlaceholder(_symbol)), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(find.byKey(StockDetailScreen.backButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(WatchlistScreen), findsOneWidget);

    await tester.tap(find.byKey(WatchlistScreen.searchButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byKey(SearchScreen.searchFieldKey), findsOneWidget);
    expect(find.text(localizations.searchTrendingTitle), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(find.byKey(SearchScreen.backButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(WatchlistScreen), findsOneWidget);
  });

  testWidgets('device locale swaps all scaffold copy and label sets', (
    tester,
  ) async {
    final en = AppLocalizationsEn();
    final zh = AppLocalizationsZh();

    await pumpApp(tester, locale: const Locale('zh'));

    expect(find.text(zh.brandTitle), findsOneWidget);
    expect(find.text(zh.raceHeaderTitle), findsOneWidget);
    expect(find.text(en.raceHeaderTitle), findsNothing);

    final zhContext = tester.element(find.byType(WatchlistScreen));
    final zhLocalizations = AppLocalizations.of(zhContext);
    expect(zhLocalizations.chartRangeLabels, zh.chartRangeLabels);
    expect(zhLocalizations.extendedSessionLabels, zh.extendedSessionLabels);

    await pumpApp(tester, locale: const Locale('en'));

    expect(find.text(en.brandTitle), findsOneWidget);
    expect(find.text(en.raceHeaderTitle), findsOneWidget);
    expect(find.text(zh.raceHeaderTitle), findsNothing);

    final enContext = tester.element(find.byType(WatchlistScreen));
    final enLocalizations = AppLocalizations.of(enContext);
    expect(enLocalizations.chartRangeLabels, en.chartRangeLabels);
    expect(enLocalizations.extendedSessionLabels, en.extendedSessionLabels);
    expect(enLocalizations.formatCompactNumber(1200000), isNotEmpty);
    expect(zhLocalizations.formatCompactNumber(1200000), isNotEmpty);
    expect(
      enLocalizations.formatCompactNumber(1200000),
      isNot(zhLocalizations.formatCompactNumber(1200000)),
    );
    expect(enLocalizations.formatPercent(0.123), isNotEmpty);
    expect(zhLocalizations.formatPercent(0.123), isNotEmpty);
  });

  test('widgets do not introduce direct text literals', () {
    const checkedPaths = [
      'lib/app/tuantuan_stock_app.dart',
      'lib/features/chart/plane_rider.dart',
      'lib/features/chart/sky_chart.dart',
      'lib/features/watchlist/watchlist_screen.dart',
      'lib/features/detail/stock_detail_screen.dart',
      'lib/features/search/search_screen.dart',
    ];

    for (final path in checkedPaths) {
      final source = File(path).readAsStringSync();

      expect(
        RegExp(r'''Text\s*\(\s*['"]''').hasMatch(source),
        isFalse,
        reason: '$path should use ARB-backed localization getters.',
      );
    }
  });

  testWidgets('CandyCard uses the cute border and hard offset shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Center(child: CandyCard(child: Text('Candy'))),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(CandyCard),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    final borderRadius = decoration.borderRadius! as BorderRadius;
    final shadow = decoration.boxShadow!.single;

    expect(decoration.color, CuteColors.card);
    expect(border.top.color, CuteColors.borderWarm);
    expect(border.top.width, 2);
    expect(borderRadius.topLeft.x, 20);
    expect(shadow.color, CuteColors.shadowWarm);
    expect(shadow.offset, const Offset(0, 4));
    expect(shadow.blurRadius, 0);
  });

  test('cute palette is the only source of hard-coded code colors', () {
    final offenders = <String>[];
    final colorLiteral = RegExp(r'(Color\s*\(\s*0x|#[0-9a-fA-F]{3,8})');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('lib/app/cute_palette.dart') ||
          entity.path.contains('/generated/')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (final MapEntry(:key, :value) in lines.asMap().entries) {
        if (colorLiteral.hasMatch(value)) {
          offenders.add('${entity.path}:${key + 1}: $value');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}

class _FakeQuoteRepository implements QuoteRepository {
  static final _aapl = Quote(
    price: 213.4,
    dayChange: 2.1,
    dayChangePct: 1.0,
    open: 211,
    high: 215,
    low: 210,
    prevClose: 211.3,
    volume: 1000,
    marketCap: 3.2e12,
    ytdChangePct: 4.2,
    asOf: DateTime.utc(2026, 7, 2, 18),
    session: MarketSession.regular,
  );

  @override
  Future<Quote> quote(String symbol) async => _aapl;

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) async => {
    for (final symbol in symbols)
      if (symbol == _symbol) symbol: _aapl,
  };

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) async {
    return ChartSeries(
      baseline: 211.3,
      candles: [
        for (final (i, close) in const [212.0, 214.0, 213.4].indexed)
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

class _SingleStockWatchlistRepository implements WatchlistRepository {
  final _symbols = [_symbol];
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
