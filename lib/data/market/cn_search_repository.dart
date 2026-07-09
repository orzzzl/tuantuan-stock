import 'package:tuantuan_stock/data/market/cn_market_client.dart';
import 'package:tuantuan_stock/data/market/cn_stock_repository.dart';
import 'package:tuantuan_stock/data/market/cn_symbols.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/domain/repositories/search_repository.dart';

/// The suggest listing-type field for US equities and ETFs (report §4.5).
const _usListingType = '41';

const _maxResults = 10;

/// [SearchRepository] backed by Sina suggest (en, zh and ticker-prefix
/// queries all work) with identities resolved through one Tencent quote
/// batch — suggest names come back zh-or-en unpredictably, while the quote
/// payload always carries both (report §4.5).
class CnSearchRepository implements SearchRepository {
  CnSearchRepository(this._client);

  final CnMarketClient _client;

  @override
  Future<List<Stock>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final symbols = _matchedSymbols(await _client.sinaSuggest(trimmed));
    if (symbols.isEmpty) return const [];
    final identities = await _client.tencentQuotes(symbols);
    return [
      // Suggest order is best-match-first; symbols Tencent doesn't know are
      // dropped rather than shown without an identity.
      for (final symbol in symbols)
        if (identities[symbol] case final fields?)
          stockFromTencentFields(symbol, fields),
    ];
  }

  List<String> _matchedSymbols(List<List<String>> entries) {
    final symbols = <String>[];
    for (final entry in entries) {
      if (entry.length < 3 || entry[1] != _usListingType) continue;
      final symbol = appSymbolFromSuggest(entry[2]);
      if (symbol.isEmpty || symbols.contains(symbol)) continue;
      symbols.add(symbol);
      if (symbols.length == _maxResults) break;
    }
    return symbols;
  }
}
