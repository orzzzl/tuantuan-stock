import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuantuan_stock/data/market/cached_stock_repository.dart';
import 'package:tuantuan_stock/data/market/alpaca_overnight_client.dart';
import 'package:tuantuan_stock/data/market/cn_market_client.dart';
import 'package:tuantuan_stock/data/market/cn_quote_repository.dart';
import 'package:tuantuan_stock/data/market/cn_search_repository.dart';
import 'package:tuantuan_stock/data/market/cn_stock_repository.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/data/market/overnight_quote_coordinator.dart';
import 'package:tuantuan_stock/data/market/overnight_quote_repository.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';
import 'package:tuantuan_stock/domain/repositories/search_repository.dart';
import 'package:tuantuan_stock/domain/repositories/stock_repository.dart';

final _httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final _cnMarketClientProvider = Provider<CnMarketClient>(
  (ref) => CnMarketClient(httpClient: ref.watch(_httpClientProvider)),
);

final _alpacaOvernightClientProvider = Provider<AlpacaOvernightClient>(
  (ref) => AlpacaOvernightClient(
    httpClient: ref.watch(_httpClientProvider),
    keyId: const String.fromEnvironment('ALPACA_KEY_ID'),
    secretKey: const String.fromEnvironment('ALPACA_SECRET_KEY'),
  ),
);

final overnightQuoteCoordinatorProvider = Provider<OvernightQuoteCoordinator>((
  ref,
) {
  final coordinator = OvernightQuoteCoordinator(
    client: ref.watch(_alpacaOvernightClientProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final overnightSnapshotProvider = StreamProvider<OvernightSnapshot>((
  ref,
) async* {
  final coordinator = ref.watch(overnightQuoteCoordinatorProvider);
  yield coordinator.snapshot;
  yield* coordinator.snapshots;
});

final marketCacheStoreProvider = Provider<MarketCacheStore>(
  (ref) => MarketCacheStore(SharedPreferencesAsync()),
);

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => OvernightQuoteRepository(
    CnQuoteRepository(
      ref.watch(_cnMarketClientProvider),
      cache: ref.watch(marketCacheStoreProvider),
    ),
    ref.watch(overnightQuoteCoordinatorProvider),
  ),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => CnSearchRepository(ref.watch(_cnMarketClientProvider)),
);

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => CachedStockRepository(
    CnStockRepository(ref.watch(_cnMarketClientProvider)),
    ref.watch(marketCacheStoreProvider),
  ),
);
