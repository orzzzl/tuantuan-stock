import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:http/http.dart' as http;
import 'package:tuantuan_stock/data/market/cn_symbols.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';

/// Desktop-browser user agent, matching the curl probes in the 16 report.
const _userAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/// Sina hosts answer 403/garbage without this Referer (report §3).
const _sinaReferer = 'https://finance.sina.com.cn';

/// Any liquid symbol serves the ~1 KB market-state probe (report §6); AAPL's
/// full code is pinned from the 16 fixtures.
const _marketStateParam = 'usAAPL.OQ,day,,,1,qfq';

final _tencentQuoteLine = RegExp(r'^v_(.+?)="(.*)";?$');
final _sinaQuoteLine = RegExp(r'^var hq_str_(.+?)="(.*)";$');
final _sinaSuggestBody = RegExp(r'^var suggestvalue="(.*)";$');

enum CnKlineGranularity {
  day('day'),
  week('week'),
  month('month');

  const CnKlineGranularity(this.queryValue);

  final String queryValue;
}

/// Low-level Tencent/Sina HTTP client (report §3/§10): browser UA, the Sina
/// Referer, GBK decoding, envelope stripping, and a hard per-request timeout.
/// No auth state, no retries, and — deliberately — no request queue: neither
/// host throttles (§7), and the v0.1 serialized queue was one cause of the
/// 60s first paint. Errors map to [DataFailure] subtypes.
class CnMarketClient {
  CnMarketClient({
    required http.Client httpClient,
    this.timeout = const Duration(seconds: 8),
  }) : _http = httpClient;

  final http.Client _http;

  /// Fail-fast deadline for every request.
  final Duration timeout;

  /// Quote fields (report §4.1) per app symbol from ONE batched Tencent
  /// request. Unknown symbols (`pv_none_match` rows) are absent.
  Future<Map<String, List<String>>> tencentQuotes(List<String> symbols) async {
    final appByQuery = {
      for (final symbol in symbols) tencentQuoteSymbol(symbol): symbol,
    };
    final uri = Uri.parse('https://qt.gtimg.cn/q=${appByQuery.keys.join(',')}');
    return _parseQuoteLines(
      await _getGbk(uri),
      pattern: _tencentQuoteLine,
      separator: '~',
      appByQuery: appByQuery,
      uri: uri,
    );
  }

  /// Quote fields (report §4.2) per app symbol from ONE batched Sina request.
  /// Unknown symbols come back as empty bodies and are absent. Callers must
  /// pre-filter indices ([sinaQuoteSymbol] returns null for them).
  Future<Map<String, List<String>>> sinaQuotes(List<String> symbols) async {
    final appByQuery = {
      for (final symbol in symbols) sinaQuoteSymbol(symbol)!: symbol,
    };
    final uri = Uri.parse(
      'https://hq.sinajs.cn/list=${appByQuery.keys.join(',')}',
    );
    return _parseQuoteLines(
      await _getGbk(uri, referer: _sinaReferer),
      pattern: _sinaQuoteLine,
      separator: ',',
      appByQuery: appByQuery,
      uri: uri,
    );
  }

  /// Comma-split suggest entries for [query] (report §4.5). The `type=41`
  /// (US listing) filter happens at the caller, which owns field meanings.
  Future<List<List<String>>> sinaSuggest(String query) async {
    final uri = Uri.parse(
      'https://suggest3.sinajs.cn/suggest/'
      'type=41&key=${Uri.encodeComponent(query)}',
    );
    final body = (await _getGbk(uri, referer: _sinaReferer)).trim();
    final match = _sinaSuggestBody.firstMatch(body);
    if (match == null) {
      throw NetworkFailure('unexpected suggest body from ${uri.host}');
    }
    final entries = match.group(1)!;
    if (entries.isEmpty) return const [];
    return [for (final entry in entries.split(';')) entry.split(',')];
  }

  /// The pipe-separated market-state feed (report §6) from a minimal kline
  /// call — the session-token source for `MarketSession`.
  Future<String> usMarketState() async {
    final uri = Uri.https('web.ifzq.gtimg.cn', '/appstock/app/usfqkline/get', {
      'param': _marketStateParam,
    });
    final json = await _getJson(uri);
    if (json['code'] != 0) {
      throw NetworkFailure('kline error ${json['code']} from ${uri.host}');
    }
    if (json['data'] case final Map<String, Object?> data) {
      for (final entry in data.values) {
        if (entry case {'qt': {'market': [final String market, ...]}}) {
          return market;
        }
      }
    }
    throw NetworkFailure('unexpected kline market shape from ${uri.host}');
  }

  /// Tencent adjusted kline rows for one full-code symbol (report §4.3).
  /// Rows are `[date, open, close, high, low, volume]` strings; some weekly
  /// rows carry extra corporate-action metadata, which callers do not need.
  Future<List<List<String>>> tencentKline({
    required String klineSymbol,
    required CnKlineGranularity granularity,
  }) async {
    final uri = Uri.https('web.ifzq.gtimg.cn', '/appstock/app/usfqkline/get', {
      'param': '$klineSymbol,${granularity.queryValue},,,320,qfq',
    });
    final json = await _getJson(uri);
    if (json['code'] != 0) {
      throw NetworkFailure('kline error ${json['code']} from ${uri.host}');
    }
    try {
      final data = json['data'] as Map<String, Object?>;
      final payload = data[klineSymbol] as Map<String, Object?>;
      final rows =
          payload['qfq${granularity.queryValue}'] as List<Object?>? ?? const [];
      return [
        for (final row in rows) _firstStringFields(row as List<Object?>, 6),
      ];
    } on RangeError catch (e) {
      throw NetworkFailure('unexpected kline shape from ${uri.host}: $e');
    } on StateError catch (e) {
      throw NetworkFailure('unexpected kline shape from ${uri.host}: $e');
    } on TypeError catch (e) {
      throw NetworkFailure('unexpected kline shape from ${uri.host}: $e');
    }
  }

  /// Sina 5-minute bars for the regular session (report §4.4/§8), after
  /// stripping the anti-hotlink comment and JSONP callback.
  Future<List<Map<String, String>>> sinaMin5(String symbol) async {
    final uri = Uri.https(
      'stock.finance.sina.com.cn',
      '/usstock/api/jsonp.php/cb/US_MinKService.getMinK',
      {'symbol': symbol.toLowerCase(), 'type': '5'},
    );
    final body = await _getGbk(uri, referer: _sinaReferer);
    final jsonText = _stripSinaJsonp(body, uri);
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! List<Object?>) {
        throw const FormatException('root is not a list');
      }
      return [for (final item in decoded) _stringMap(item)];
    } on FormatException catch (e) {
      throw NetworkFailure('unexpected Sina minK shape from ${uri.host}: $e');
    } on StateError catch (e) {
      throw NetworkFailure('unexpected Sina minK shape from ${uri.host}: $e');
    } on TypeError catch (e) {
      throw NetworkFailure('unexpected Sina minK shape from ${uri.host}: $e');
    }
  }

  Map<String, List<String>> _parseQuoteLines(
    String text, {
    required RegExp pattern,
    required String separator,
    required Map<String, String> appByQuery,
    required Uri uri,
  }) {
    final fieldsBySymbol = <String, List<String>>{};
    var envelopeLines = 0;
    for (final line in LineSplitter.split(text)) {
      final match = pattern.firstMatch(line.trim());
      if (match == null) continue;
      envelopeLines++;
      final appSymbol = appByQuery[match.group(1)];
      final body = match.group(2)!;
      // No app symbol = a row we didn't ask for (e.g. Tencent's
      // `pv_none_match`); an empty body is Sina's unknown-symbol marker.
      if (appSymbol == null || body.isEmpty) continue;
      fieldsBySymbol[appSymbol] = body.split(separator);
    }
    if (envelopeLines == 0) {
      throw NetworkFailure('unexpected quote body from ${uri.host}');
    }
    return fieldsBySymbol;
  }

  List<String> _firstStringFields(List<Object?> row, int count) {
    if (row.length < count) {
      throw StateError('row has ${row.length} fields');
    }
    final fields = <String>[];
    for (var i = 0; i < count; i += 1) {
      final value = row[i];
      if (value is! String) {
        throw StateError('field $i is ${value.runtimeType}');
      }
      fields.add(value);
    }
    return fields;
  }

  Map<String, String> _stringMap(Object? item) {
    if (item is! Map<String, Object?>) {
      throw StateError('row is ${item.runtimeType}');
    }
    final result = <String, String>{};
    for (final MapEntry(:key, :value) in item.entries) {
      if (value is! String) {
        throw StateError('$key is ${value.runtimeType}');
      }
      result[key] = value;
    }
    return result;
  }

  String _stripSinaJsonp(String text, Uri uri) {
    final start = text.indexOf('cb(');
    final end = text.lastIndexOf(')');
    if (start < 0 || end <= start + 3) {
      throw NetworkFailure('unexpected JSONP body from ${uri.host}');
    }
    return text.substring(start + 3, end);
  }

  Future<String> _getGbk(Uri uri, {String? referer}) async => gbk.decode(
    (await _get(uri, referer: referer)).bodyBytes,
    allowMalformed: true,
  );

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final response = await _get(uri);
    try {
      return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true))
          as Map<String, Object?>;
    } on FormatException catch (e) {
      throw NetworkFailure('non-JSON body from ${uri.host}: $e');
    } on TypeError catch (e) {
      throw NetworkFailure('non-object body from ${uri.host}: $e');
    }
  }

  Future<http.Response> _get(Uri uri, {String? referer}) async {
    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: {'User-Agent': _userAgent, 'Referer': ?referer})
          .timeout(timeout);
    } on TimeoutException {
      throw NetworkFailure(
        'GET ${uri.host}${uri.path}: no response in ${timeout.inSeconds}s',
      );
    } on http.ClientException catch (e) {
      throw NetworkFailure('GET ${uri.host}${uri.path}: $e');
    } on IOException catch (e) {
      throw NetworkFailure('GET ${uri.host}${uri.path}: $e');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw NetworkFailure(
        'HTTP ${response.statusCode} from ${uri.host}${uri.path}',
      );
    }
    return response;
  }
}
