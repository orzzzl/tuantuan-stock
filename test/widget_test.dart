import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/app/app_router.dart';
import 'package:tuantuan_stock/app/tuantuan_stock_app.dart';
import 'package:tuantuan_stock/features/detail/stock_detail_screen.dart';
import 'package:tuantuan_stock/features/search/search_screen.dart';
import 'package:tuantuan_stock/features/watchlist/watchlist_screen.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_en.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations_zh.dart';
import 'package:tuantuan_stock/l10n/localized_sets.dart';

void main() {
  testWidgets('root pushes and pops detail and search routes', (tester) async {
    final localizations = AppLocalizationsEn();

    await tester.pumpWidget(const ProviderScope(child: TuanTuanStockApp()));
    await tester.pumpAndSettle();

    expect(find.byType(WatchlistScreen), findsOneWidget);
    expect(find.text(localizations.watchlistPlaceholder), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(find.byKey(WatchlistScreen.detailButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(StockDetailScreen), findsOneWidget);
    expect(
      find.text(localizations.detailPlaceholder(sampleStockSymbol)),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(find.byKey(StockDetailScreen.backButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(WatchlistScreen), findsOneWidget);

    await tester.tap(find.byKey(WatchlistScreen.searchButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text(localizations.searchPlaceholder), findsOneWidget);
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

    await tester.pumpWidget(
      const ProviderScope(child: TuanTuanStockApp(locale: Locale('zh'))),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.watchlistTitle), findsOneWidget);
    expect(find.text(zh.watchlistPlaceholder), findsOneWidget);
    expect(find.text(en.watchlistPlaceholder), findsNothing);

    final zhContext = tester.element(find.byType(WatchlistScreen));
    final zhLocalizations = AppLocalizations.of(zhContext);
    expect(zhLocalizations.chartRangeLabels, zh.chartRangeLabels);
    expect(zhLocalizations.extendedSessionLabels, zh.extendedSessionLabels);

    await tester.pumpWidget(
      const ProviderScope(child: TuanTuanStockApp(locale: Locale('en'))),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.watchlistTitle), findsOneWidget);
    expect(find.text(en.watchlistPlaceholder), findsOneWidget);
    expect(find.text(zh.watchlistPlaceholder), findsNothing);

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
}
