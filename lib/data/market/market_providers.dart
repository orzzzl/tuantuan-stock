import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuantuan_stock/data/market/cached_stock_repository.dart';
import 'package:tuantuan_stock/data/market/cn_market_client.dart';
import 'package:tuantuan_stock/data/market/cn_quote_repository.dart';
import 'package:tuantuan_stock/data/market/cn_search_repository.dart';
import 'package:tuantuan_stock/data/market/cn_stock_repository.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
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

final marketCacheStoreProvider = Provider<MarketCacheStore>(
  (ref) => MarketCacheStore(SharedPreferencesAsync()),
);

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => CnQuoteRepository(
    ref.watch(_cnMarketClientProvider),
    cache: ref.watch(marketCacheStoreProvider),
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
