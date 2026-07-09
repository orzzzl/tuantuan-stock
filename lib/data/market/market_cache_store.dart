import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuantuan_stock/data/market/company_logos.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';

class CachedQuoteBatch {
  const CachedQuoteBatch({
    required this.quotes,
    required this.fetchedAt,
    required this.isStale,
  });

  final Map<String, Quote> quotes;
  final DateTime fetchedAt;
  final bool isStale;
}

class MarketCacheStore {
  MarketCacheStore(this._prefs);

  static const quoteSnapshotsKey = 'market.quoteSnapshots.v1';
  // v2: v1 held v0.1-provider identities without zh names; the identity cache
  // has no TTL, so the provider switch (task 17) must refetch once.
  static const stocksKey = 'market.stocks.v2';
  static const ytdBaselinesKey = 'market.ytdBaselines.v1';

  final SharedPreferencesAsync _prefs;

  /// True once a fresh quote batch has been served this process lifetime.
  /// The stale pre-paint exists only to cover cold start; later stream
  /// rebuilds (pull-to-refresh, watchlist edits) consult this to skip the
  /// cache read so the banner never flashes over an already-fresh board.
  bool hasServedFreshQuotes = false;

  Future<CachedQuoteBatch?> readQuoteSnapshots(List<String> symbols) async {
    if (symbols.isEmpty) {
      return CachedQuoteBatch(
        quotes: const {},
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        isStale: false,
      );
    }
    final root = await _readMap(quoteSnapshotsKey);
    if (root == null) return null;
    final entries = root['quotes'];
    if (entries is! Map<String, Object?>) return null;

    final quotes = <String, Quote>{};
    DateTime? oldestFetch;
    try {
      for (final symbol in symbols) {
        final entry = entries[symbol];
        if (entry is! Map<String, Object?>) return null;
        final fetchedAt = DateTime.parse(entry['fetchedAt'] as String).toUtc();
        oldestFetch = oldestFetch == null || fetchedAt.isBefore(oldestFetch)
            ? fetchedAt
            : oldestFetch;
        quotes[symbol] = _decodeQuote(entry['quote'] as Map<String, Object?>);
      }
    } on Object {
      await _prefs.remove(quoteSnapshotsKey);
      return null;
    }

    return CachedQuoteBatch(
      quotes: Map.unmodifiable(quotes),
      fetchedAt: oldestFetch!,
      isStale: true,
    );
  }

  Future<void> writeQuoteSnapshots(
    Map<String, Quote> quotes,
    DateTime fetchedAt,
  ) async {
    if (quotes.isEmpty) return;
    final root = await _readMap(quoteSnapshotsKey) ?? const {};
    final entries = switch (root['quotes']) {
      final Map<String, Object?> map => {...map},
      _ => <String, Object?>{},
    };
    for (final MapEntry(:key, :value) in quotes.entries) {
      entries[key] = {
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'quote': _encodeQuote(value),
      };
    }
    await _prefs.setString(
      quoteSnapshotsKey,
      jsonEncode({'version': 1, 'quotes': entries}),
    );
  }

  Future<Map<String, Stock>> readStocks(List<String> symbols) async {
    final root = await _readMap(stocksKey);
    if (root == null) return const {};
    final entries = root['stocks'];
    if (entries is! Map<String, Object?>) return const {};

    final stocks = <String, Stock>{};
    try {
      for (final symbol in symbols) {
        final entry = entries[symbol];
        if (entry is Map<String, Object?>) {
          stocks[symbol] = _decodeStock(entry);
        }
      }
    } on Object {
      await _prefs.remove(stocksKey);
      return const {};
    }
    return Map.unmodifiable(stocks);
  }

  Future<void> writeStocks(Map<String, Stock> stocks) async {
    if (stocks.isEmpty) return;
    final root = await _readMap(stocksKey) ?? const {};
    final entries = switch (root['stocks']) {
      final Map<String, Object?> map => {...map},
      _ => <String, Object?>{},
    };
    for (final MapEntry(:key, :value) in stocks.entries) {
      entries[key] = _encodeStock(value);
    }
    await _prefs.setString(
      stocksKey,
      jsonEncode({'version': 1, 'stocks': entries}),
    );
  }

  Future<double?> readYtdBaseline(String symbol, int year) async {
    final root = await _readMap(ytdBaselinesKey);
    if (root == null) return null;
    final entries = root['baselines'];
    if (entries is! Map<String, Object?>) return null;
    final value = entries[_ytdKey(symbol, year)];
    return value is num ? value.toDouble() : null;
  }

  Future<void> writeYtdBaseline({
    required String symbol,
    required int year,
    required double baseline,
  }) async {
    final root = await _readMap(ytdBaselinesKey) ?? const {};
    final entries = switch (root['baselines']) {
      final Map<String, Object?> map => {...map},
      _ => <String, Object?>{},
    };
    entries[_ytdKey(symbol, year)] = baseline;
    await _prefs.setString(
      ytdBaselinesKey,
      jsonEncode({'version': 1, 'baselines': entries}),
    );
  }

  Future<Map<String, Object?>?> _readMap(String key) async {
    final raw = await _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?> && decoded['version'] == 1) {
        return decoded;
      }
    } on Object {
      // Fall through to drop bad data.
    }
    await _prefs.remove(key);
    return null;
  }

  static String _ytdKey(String symbol, int year) => '$symbol|$year';

  static Map<String, Object?> _encodeQuote(Quote quote) => {
    'price': quote.price,
    'dayChange': quote.dayChange,
    'dayChangePct': quote.dayChangePct,
    'open': quote.open,
    'high': quote.high,
    'low': quote.low,
    'prevClose': quote.prevClose,
    'volume': quote.volume,
    'marketCap': quote.marketCap,
    'trailingPe': quote.trailingPe,
    'forwardPe': quote.forwardPe,
    'ytdChangePct': quote.ytdChangePct,
    'asOf': quote.asOf.toUtc().toIso8601String(),
    'session': quote.session.name,
    'extChangePct': quote.extChangePct,
  };

  static Quote _decodeQuote(Map<String, Object?> json) {
    return Quote(
      price: (json['price'] as num).toDouble(),
      dayChange: (json['dayChange'] as num).toDouble(),
      dayChangePct: (json['dayChangePct'] as num).toDouble(),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      prevClose: (json['prevClose'] as num).toDouble(),
      volume: (json['volume'] as num).toInt(),
      marketCap: (json['marketCap'] as num?)?.toDouble(),
      trailingPe: (json['trailingPe'] as num?)?.toDouble(),
      forwardPe: (json['forwardPe'] as num?)?.toDouble(),
      ytdChangePct: (json['ytdChangePct'] as num?)?.toDouble(),
      asOf: DateTime.parse(json['asOf'] as String).toUtc(),
      session: MarketSession.values.byName(json['session'] as String),
      extChangePct: (json['extChangePct'] as num?)?.toDouble(),
    );
  }

  // The logo is not persisted: it is derived from the bundled pack at decode
  // time, so cached identities pick up pack additions without a refetch (and
  // any v0.1-era cached network URL is dropped rather than fetched).
  static Map<String, Object?> _encodeStock(Stock stock) => {
    'symbol': stock.symbol,
    'name': stock.name,
    'zhName': stock.zhName,
    'exchange': stock.exchange,
  };

  static Stock _decodeStock(Map<String, Object?> json) {
    final symbol = json['symbol'] as String;
    return Stock(
      symbol: symbol,
      name: json['name'] as String,
      zhName: json['zhName'] as String?,
      exchange: json['exchange'] as String,
      logoAsset: companyLogoAsset(symbol),
    );
  }
}
