import 'package:tuantuan_stock/data/market/yahoo_client.dart';
import 'package:tuantuan_stock/data/market/yahoo_company_profiles.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/domain/repositories/search_repository.dart';

/// US exchange codes accepted in search results (DESIGN.md: US equities/ETFs
/// only): Nasdaq tiers, NYSE, NYSE American, NYSE Arca, Cboe BZX.
const _usExchanges = {'NMS', 'NGM', 'NCM', 'NYQ', 'ASE', 'PCX', 'BTS'};

const _usQuoteTypes = {'EQUITY', 'ETF'};

/// [SearchRepository] backed by Yahoo's keyless v1 `search` endpoint, with
/// logos resolved through [YahooCompanyProfiles].
class YahooSearchRepository implements SearchRepository {
  YahooSearchRepository(this._client, this._profiles);

  final YahooClient _client;
  final YahooCompanyProfiles _profiles;

  @override
  Future<List<Stock>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final json = await _client.getJson(
      Uri.https('query1.finance.yahoo.com', '/v1/finance/search', {
        'q': trimmed,
        'quotesCount': '10',
      }),
    );
    final matches = ((json['quotes'] as List<Object?>?) ?? const [])
        .cast<Map<String, Object?>>()
        .where(_isUsListing)
        .toList();
    return Future.wait(matches.map(_mapStock));
  }

  bool _isUsListing(Map<String, Object?> json) =>
      _usQuoteTypes.contains(json['quoteType']) &&
      _usExchanges.contains(json['exchange']) &&
      json['symbol'] is String;

  Future<Stock> _mapStock(Map<String, Object?> json) async {
    final symbol = json['symbol'] as String;
    return Stock(
      symbol: symbol,
      name: (json['shortname'] ?? json['longname'] ?? symbol) as String,
      exchange: json['exchange'] as String,
      logoUrl: await _profiles.logoUrl(symbol),
    );
  }
}
