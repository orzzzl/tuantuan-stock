import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One real-time indicative quote from Alpaca's derived `overnight` feed.
class OvernightQuote {
  const OvernightQuote({required this.midpoint, required this.timestamp});

  final double midpoint;
  final DateTime timestamp;
}

/// A failed overnight fetch (timeout, transport error, non-200 including 429,
/// or a malformed payload). Deliberately payload-free: no message, no status,
/// no credentials — the coordinator turns it into an empty snapshot and the
/// polling loop only counts consecutive occurrences for its backoff.
class OvernightFeedFailure implements Exception {
  const OvernightFeedFailure();
}

/// Minimal client seam so the coordinator can be tested without HTTP.
abstract interface class OvernightQuoteClient {
  bool get isEnabled;

  Future<Map<String, OvernightQuote>> latestQuotes(List<String> symbols);
}

/// Alpaca Basic's batched latest-quotes endpoint. Every failure surfaces as
/// one payload-free [OvernightFeedFailure] so the polling loop can back off;
/// the coordinator still degrades it to absence before any consumer sees it.
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

    final http.Response response;
    try {
      response = await _http
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
    } on Object {
      throw const OvernightFeedFailure();
    }
    lastRateLimitRemaining = int.tryParse(
      response.headers['x-ratelimit-remaining'] ?? '',
    );
    if (response.statusCode != 200) throw const OvernightFeedFailure();
    return _parseLatestQuotes(response.body);
  }

  static Map<String, OvernightQuote> _parseLatestQuotes(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on Object {
      throw const OvernightFeedFailure();
    }
    if (decoded is! Map<String, Object?>) throw const OvernightFeedFailure();
    final rawQuotes = decoded['quotes'];
    if (rawQuotes is! Map<String, Object?>) throw const OvernightFeedFailure();
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in rawQuotes.entries)
        if (_parseQuote(value) case final OvernightQuote quote) key: quote,
    });
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
