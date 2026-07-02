import 'package:tuantuan_stock/data/market/yahoo_client.dart';

/// Company profile lookups via Yahoo v10 `quoteSummary` — currently just the
/// website-derived logo URL. Successful lookups are cached for the process
/// lifetime; failures resolve to null (ticker-ring fallback) and may retry.
class YahooCompanyProfiles {
  YahooCompanyProfiles(this._client);

  final YahooClient _client;
  final _logoUrlBySymbol = <String, String?>{};

  /// Favicon-service logo URL for [symbol], or null when the profile has no
  /// usable website. Never throws: search results must not fail on logos.
  Future<String?> logoUrl(String symbol) async {
    if (_logoUrlBySymbol.containsKey(symbol)) {
      return _logoUrlBySymbol[symbol];
    }
    final String? url;
    try {
      url = _faviconUrl(await _website(symbol));
    } on Exception {
      return null; // Uncached so a later search can retry.
    }
    _logoUrlBySymbol[symbol] = url;
    return url;
  }

  Future<String?> _website(String symbol) async {
    final json = await _client.getJson(
      Uri.https(
        'query1.finance.yahoo.com',
        '/v10/finance/quoteSummary/$symbol',
        {'modules': 'assetProfile'},
      ),
      authenticated: true,
    );
    final results =
        ((json['quoteSummary'] as Map<String, Object?>?)?['result']
            as List<Object?>?) ??
        const [];
    if (results.isEmpty) return null;
    final profile =
        (results.first as Map<String, Object?>)['assetProfile']
            as Map<String, Object?>?;
    return profile?['website'] as String?;
  }

  String? _faviconUrl(String? website) {
    if (website == null) return null;
    final host = Uri.tryParse(website)?.host;
    if (host == null || host.isEmpty) return null;
    // The favicon pattern proven in mockups/ (04 report, "Logos").
    return 'https://www.google.com/s2/favicons?domain=$host&sz=128';
  }
}
