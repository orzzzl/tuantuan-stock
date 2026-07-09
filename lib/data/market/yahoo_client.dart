import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tuantuan_stock/domain/models/data_failure.dart';

/// Desktop-browser user agent — Yahoo rejects default library agents.
const _userAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const _cookieUrl = 'https://fc.yahoo.com';
const _crumbUrl = 'https://query1.finance.yahoo.com/v1/test/getcrumb';

/// Low-level Yahoo Finance HTTP client: browser UA, the cookie+crumb dance
/// for authenticated endpoints (fetch once, cache, refresh on 401), a
/// minimum-interval guard between requests, and backoff on HTTP 429/999.
/// Maps transport/provider errors to [DataFailure] subtypes.
class YahooClient {
  YahooClient({
    required http.Client httpClient,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
    this.minInterval = const Duration(milliseconds: 400),
    this.maxAttempts = 3,
  }) : _http = httpClient,
       _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed;

  final http.Client _http;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;

  /// Smallest allowed gap between two outgoing requests.
  final Duration minInterval;

  /// Total tries per request when the provider throttles (429/999).
  final int maxAttempts;

  String? _cookie;
  String? _crumb;
  Future<void>? _credentialsInFlight;
  DateTime? _lastRequestAt;

  /// Tail of the request queue: all requests are serialized so the
  /// minimum-interval guard holds even for concurrent callers (e.g. YTD
  /// baseline charts fanned out over a quote batch).
  Future<void> _queueTail = Future.value();

  /// Fetches [uri] and decodes the JSON object body. [authenticated] appends
  /// the cached crumb and cookie (v7 quote); on a 401 the credentials are
  /// refreshed once and the request retried.
  Future<Map<String, Object?>> getJson(
    Uri uri, {
    bool authenticated = false,
  }) async {
    if (authenticated) {
      await _ensureCredentials();
    }
    var response = await _send(_withCrumb(uri, authenticated));
    if (authenticated && response.statusCode == HttpStatus.unauthorized) {
      await _refreshCredentials();
      response = await _send(_withCrumb(uri, authenticated));
    }
    return _decode(uri, response);
  }

  Uri _withCrumb(Uri uri, bool authenticated) {
    if (!authenticated) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'crumb': _crumb!},
    );
  }

  Future<http.Response> _send(Uri uri) {
    final response = _queueTail.then((_) => _sendNow(uri));
    _queueTail = response.then((_) {}, onError: (_) {});
    return response;
  }

  Future<http.Response> _sendNow(Uri uri) async {
    for (var attempt = 1; ; attempt++) {
      await _throttle();
      final http.Response response;
      try {
        response = await _http.get(uri, headers: _headers());
      } on http.ClientException catch (e) {
        throw NetworkFailure('GET ${uri.host}${uri.path}: $e');
      } on IOException catch (e) {
        throw NetworkFailure('GET ${uri.host}${uri.path}: $e');
      }
      final throttled =
          response.statusCode == HttpStatus.tooManyRequests ||
          response.statusCode == 999; // Yahoo's custom rate-limit status.
      if (!throttled) return response;
      if (attempt >= maxAttempts) {
        throw RateLimitFailure(
          'HTTP ${response.statusCode} from ${uri.host} '
          'after $maxAttempts attempts',
        );
      }
      await _wait(Duration(seconds: 1 << (attempt - 1)));
    }
  }

  Future<void> _throttle() async {
    final last = _lastRequestAt;
    if (last != null) {
      final elapsed = _now().difference(last);
      if (elapsed < minInterval) await _wait(minInterval - elapsed);
    }
    _lastRequestAt = _now();
  }

  Map<String, String> _headers() => {
    'User-Agent': _userAgent,
    'Cookie': ?_cookie,
  };

  /// Concurrent callers share one in-flight dance instead of racing it.
  Future<void> _ensureCredentials() {
    if (_crumb != null) return Future.value();
    return _credentialsInFlight ??= _fetchCredentials().whenComplete(
      () => _credentialsInFlight = null,
    );
  }

  Future<void> _fetchCredentials() async {
    final cookieResponse = await _send(Uri.parse(_cookieUrl));
    final setCookie = cookieResponse.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) {
      throw const AuthFailure('cookie endpoint returned no Set-Cookie');
    }
    // Keep only the `name=value` pair; attributes (Expires, Path, …) and any
    // comma-joined extra cookies are irrelevant to the crumb endpoints.
    _cookie = setCookie.split(';').first;

    final crumbResponse = await _send(Uri.parse(_crumbUrl));
    final crumb = crumbResponse.body.trim();
    if (crumbResponse.statusCode != HttpStatus.ok || crumb.isEmpty) {
      throw AuthFailure('crumb fetch failed: HTTP ${crumbResponse.statusCode}');
    }
    _crumb = crumb;
  }

  Future<void> _refreshCredentials() async {
    _cookie = null;
    _crumb = null;
    await _ensureCredentials();
  }

  Map<String, Object?> _decode(Uri uri, http.Response response) {
    switch (response.statusCode) {
      case HttpStatus.ok:
        break;
      case HttpStatus.unauthorized:
        throw const AuthFailure('still unauthorized after crumb refresh');
      case HttpStatus.notFound:
        throw NotFoundFailure('${uri.path} not found');
      default:
        throw NetworkFailure(
          'HTTP ${response.statusCode} from ${uri.host}${uri.path}',
        );
    }
    try {
      return jsonDecode(response.body) as Map<String, Object?>;
    } on FormatException catch (e) {
      throw NetworkFailure('non-JSON body from ${uri.host}${uri.path}: $e');
    }
  }
}
