import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One real-time indicative quote from Alpaca's derived `overnight` feed.
class OvernightQuote {
  const OvernightQuote({required this.midpoint, required this.timestamp});

  final double midpoint;
  final DateTime timestamp;
}

/// Minimal client seam so the coordinator can be tested without HTTP.
abstract interface class OvernightQuoteClient {
  bool get isEnabled;

  Future<Map<String, OvernightQuote>> latestQuotes(List<String> symbols);
}

/// Alpaca Basic's batched latest-quotes endpoint. Every failure intentionally
/// maps to an empty result: the overnight path is optional decoration.
class AlpacaOvernightClient implements OvernightQuoteClient {
  AlpacaOvernightClient({
    required http.Client httpClient,
    required this.keyId,
    required this.secretKey,
    this.timeout = const Duration(seconds: 8),
  }) : _http = httpClient;

  final http.Client _http;
  final String keyId;
  final String secretKey;
  final Duration timeout;

  /// Observed for operational validation only. It is never shown or logged.
  int? lastRateLimitRemaining;

  @override
  bool get isEnabled => keyId.isNotEmpty && secretKey.isNotEmpty;

  @override
  Future<Map<String, OvernightQuote>> latestQuotes(List<String> symbols) async {
    if (!isEnabled || symbols.isEmpty) return const {};

    try {
      final response = await _http
          .get(
            Uri.https('data.alpaca.markets', '/v2/stocks/quotes/latest', {
              'symbols': symbols.join(','),
              'feed': 'overnight',
            }),
            headers: {
              'APCA-API-KEY-ID': keyId,
              'APCA-API-SECRET-KEY': secretKey,
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);
      lastRateLimitRemaining = int.tryParse(
        response.headers['x-ratelimit-remaining'] ?? '',
      );
      if (response.statusCode != 200) return const {};
      return _parseLatestQuotes(response.body);
    } on Object {
      return const {};
    }
  }

  static Map<String, OvernightQuote> _parseLatestQuotes(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) return const {};
      final rawQuotes = decoded['quotes'];
      if (rawQuotes is! Map<String, Object?>) return const {};
      return Map.unmodifiable({
        for (final MapEntry(:key, :value) in rawQuotes.entries)
          if (_parseQuote(value) case final OvernightQuote quote) key: quote,
      });
    } on Object {
      return const {};
    }
  }

  static OvernightQuote? _parseQuote(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final bid = raw['bp'];
    final ask = raw['ap'];
    final stamp = raw['t'];
    if (bid is! num || ask is! num || stamp is! String) return null;
    if (bid <= 0 || ask <= 0) return null;
    final timestamp = DateTime.tryParse(stamp)?.toUtc();
    if (timestamp == null) return null;
    return OvernightQuote(
      midpoint: (bid.toDouble() + ask.toDouble()) / 2,
      timestamp: timestamp,
    );
  }
}
