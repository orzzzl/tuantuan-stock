import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/domain/repositories/stock_repository.dart';

class CachedStockRepository implements StockRepository {
  CachedStockRepository(this._delegate, this._cache);

  final StockRepository _delegate;
  final MarketCacheStore _cache;

  @override
  Future<Map<String, Stock>> stocks(List<String> symbols) async {
    if (symbols.isEmpty) return const {};

    final cached = await _cache.readStocks(symbols);
    if (_coversAll(symbols, cached)) return cached;

    final fresh = await _delegate.stocks(symbols);
    await _cache.writeStocks(fresh);
    return fresh;
  }

  bool _coversAll(List<String> symbols, Map<String, Stock> stocks) {
    return symbols.every(stocks.containsKey);
  }
}
