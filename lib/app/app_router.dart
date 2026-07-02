import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tuantuan_stock/features/detail/stock_detail_screen.dart';
import 'package:tuantuan_stock/features/search/search_screen.dart';
import 'package:tuantuan_stock/features/watchlist/watchlist_screen.dart';

const sampleStockSymbol = 'AAPL';

String stockPath(String symbol) => '/stock/$symbol';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const WatchlistScreen();
        },
      ),
      GoRoute(
        path: '/stock/:symbol',
        builder: (BuildContext context, GoRouterState state) {
          final symbol = state.pathParameters['symbol'] ?? '';
          return StockDetailScreen(symbol: symbol);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (BuildContext context, GoRouterState state) {
          return const SearchScreen();
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
