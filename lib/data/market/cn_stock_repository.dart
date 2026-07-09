import 'package:tuantuan_stock/data/market/cn_market_client.dart';
import 'package:tuantuan_stock/data/market/cn_symbols.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/domain/repositories/stock_repository.dart';

/// [StockRepository] backed by the same batched Tencent quote payload the
/// prices come from: field 46 is the English name, 1 the Chinese name, 2 the
/// full code whose suffix is the exchange (report §4.1).
class CnStockRepository implements StockRepository {
  CnStockRepository(this._client);

  final CnMarketClient _client;

  @override
  Future<Map<String, Stock>> stocks(List<String> symbols) async {
    if (symbols.isEmpty) return const {};
    final batch = await _client.tencentQuotes(symbols);
    return {
      for (final MapEntry(:key, :value) in batch.entries)
        key: stockFromTencentFields(key, value),
    };
  }
}

/// Identity from one Tencent quote row; shared by the stock and search
/// repositories. `logoUrl` stays null — logos become bundled assets in task
/// 21, and the ticker-ring fallback already ships.
Stock stockFromTencentFields(String symbol, List<String> fields) {
  try {
    final zhName = fields[1];
    final name = fields[46];
    return Stock(
      symbol: symbol,
      name: name.isEmpty ? symbol : name,
      zhName: zhName.isEmpty ? null : zhName,
      exchange: exchangeFromTencentFullCode(fields[2]),
    );
  } on RangeError catch (e) {
    throw NetworkFailure('unexpected Tencent quote shape for $symbol: $e');
  }
}
