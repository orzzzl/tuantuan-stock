import 'package:tuantuan_stock/data/market/yahoo_client.dart';
import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';

/// The index-strip symbols — real indices, no ETF proxies (04 report).
const indexStripSymbols = ['^GSPC', '^IXIC', '^DJI'];

/// [QuoteRepository] backed by Yahoo's batched v7 `quote` endpoint.
class YahooQuoteRepository implements QuoteRepository {
  YahooQuoteRepository(this._client);

  final YahooClient _client;

  @override
  Future<Quote> quote(String symbol) async {
    final bySymbol = await quotes([symbol]);
    final quote = bySymbol[symbol];
    if (quote == null) {
      throw NotFoundFailure('no quote for $symbol');
    }
    return quote;
  }

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) async {
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
    return {
      for (final item in results.cast<Map<String, Object?>>())
        item['symbol'] as String: _mapQuote(item),
    };
  }

  @override
  Future<List<Candle>> candles(String symbol, ChartRange range) {
    throw UnsupportedError('candles land with task 06 (v8 chart endpoint)');
  }

  Quote _mapQuote(Map<String, Object?> json) {
    try {
      final prevClose = _double(json, 'regularMarketPreviousClose');
      return Quote(
        price: _double(json, 'regularMarketPrice'),
        dayChange: _double(json, 'regularMarketChange'),
        dayChangePct: _double(json, 'regularMarketChangePercent'),
        open: _double(json, 'regularMarketOpen'),
        high: _double(json, 'regularMarketDayHigh'),
        low: _double(json, 'regularMarketDayLow'),
        prevClose: prevClose,
        volume: (json['regularMarketVolume'] as num?)?.toInt() ?? 0,
        marketCap: (json['marketCap'] as num?)?.toDouble(),
        // TODO(06): ytdChangePct from the v8 chart ytd baseline.
        ytdChangePct: null,
        asOf: _epochSeconds(json['regularMarketTime']),
        // TODO(06): session + extChangePct from marketState and the
        // state-matched pre/post change field (04 report null rules).
        session: MarketSession.closed,
        extChangePct: null,
      );
    } on TypeError catch (e) {
      throw NetworkFailure('unexpected v7 quote shape: $e');
    } on StateError catch (e) {
      throw NetworkFailure('unexpected v7 quote shape: $e');
    }
  }

  double _double(Map<String, Object?> json, String key) {
    final value = json[key] as num?;
    if (value == null) {
      throw StateError('missing $key');
    }
    return value.toDouble();
  }

  DateTime _epochSeconds(Object? value) {
    if (value is! num) return DateTime.now().toUtc();
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() * 1000,
      isUtc: true,
    );
  }
}
