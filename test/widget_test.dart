import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/app/app_router.dart';
import 'package:tuantuan_stock/app/tuantuan_stock_app.dart';
import 'package:tuantuan_stock/features/detail/stock_detail_screen.dart';
import 'package:tuantuan_stock/features/search/search_screen.dart';
import 'package:tuantuan_stock/features/watchlist/watchlist_screen.dart';

void main() {
  testWidgets('root pushes and pops detail and search routes', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TuanTuanStockApp()));
    await tester.pumpAndSettle();

    expect(find.byType(WatchlistScreen), findsOneWidget);
    expect(find.text('Watchlist placeholder'), findsOneWidget);

    await tester.tap(find.byKey(WatchlistScreen.detailButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(StockDetailScreen), findsOneWidget);
    expect(
      find.text('Stock detail placeholder for $sampleStockSymbol'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(StockDetailScreen.backButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(WatchlistScreen), findsOneWidget);

    await tester.tap(find.byKey(WatchlistScreen.searchButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Search placeholder'), findsOneWidget);

    await tester.tap(find.byKey(SearchScreen.backButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(WatchlistScreen), findsOneWidget);
  });
}
