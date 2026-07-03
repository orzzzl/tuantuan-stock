import 'package:tuantuan_stock/data/market/yahoo_client.dart';
import 'package:tuantuan_stock/data/market/yahoo_company_profiles.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/domain/repositories/stock_repository.dart';

/// [StockRepository] backed by Yahoo's batched v7 `quote` endpoint (names and
/// exchange come with the quote payload), with logos resolved through
/// [YahooCompanyProfiles].
class YahooStockRepository implements StockRepository {
  YahooStockRepository(this._client, this._profiles);

  final YahooClient _client;
  final YahooCompanyProfiles _profiles;

  @override
  Future<Map<String, Stock>> stocks(List<String> symbols) async {
    if (symbols.isEmpty) return const {};
    final json = await _client.getJson(
      Uri.https('query1.finance.yahoo.com', '/v7/finance/quote', {
        'symbols': symbols.join(','),
      }),
      authenticated: true,
    );
    final results =
        ((json['quoteResponse'] as Map<String, Object?>?)?['result']
            as List<Object?>?) ??
        const [];
    final items = results.cast<Map<String, Object?>>();
    final logos = await Future.wait(
      items.map((item) => _profiles.logoUrl(item['symbol'] as String)),
    );
    return {
      for (final (i, item) in items.indexed)
        item['symbol'] as String: _mapStock(item, logoUrl: logos[i]),
    };
  }

  Stock _mapStock(Map<String, Object?> json, {String? logoUrl}) {
    try {
      final symbol = json['symbol'] as String;
      return Stock(
        symbol: symbol,
        name: (json['shortName'] ?? json['longName'] ?? symbol) as String,
        exchange: (json['exchange'] ?? '') as String,
        logoUrl: logoUrl,
      );
    } on TypeError catch (e) {
      throw NetworkFailure('unexpected v7 quote shape: $e');
    }
  }
}
