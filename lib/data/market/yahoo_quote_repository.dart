import 'package:tuantuan_stock/data/market/yahoo_client.dart';
import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';

/// The index-strip symbols — real indices, no ETF proxies (04 report).
const indexStripSymbols = ['^GSPC', '^IXIC', '^DJI'];

/// [QuoteRepository] backed by Yahoo's batched v7 `quote` and keyless v8
/// `chart` endpoints.
class YahooQuoteRepository implements QuoteRepository {
  YahooQuoteRepository(this._client);

  final YahooClient _client;

  /// YTD baselines (last year's final close) are constant for a calendar
  /// year, so one fetch per symbol serves the whole process lifetime.
  final _ytdBaselineBySymbol = <String, double>{};

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
    final items = results.cast<Map<String, Object?>>();
    final baselines = await Future.wait(
      items.map((item) => _ytdBaseline(item['symbol'] as String)),
    );
    return {
      for (final (i, item) in items.indexed)
        item['symbol'] as String: _mapQuote(item, ytdBaseline: baselines[i]),
    };
  }

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) async {
    final (yahooRange, interval) = switch (range) {
      ChartRange.day => ('1d', '5m'),
      ChartRange.week => ('5d', '1d'),
      ChartRange.month => ('1mo', '1d'),
      ChartRange.quarter => ('3mo', '1d'),
      ChartRange.ytd => ('ytd', '1d'),
      ChartRange.year => ('1y', '1d'),
      ChartRange.year5 => ('5y', '1wk'),
      ChartRange.all => ('max', '1mo'),
    };
    final json = await _client.getJson(
      Uri.https('query1.finance.yahoo.com', '/v8/finance/chart/$symbol', {
        'range': yahooRange,
        'interval': interval,
        // Extended-hours bars let the day chart show the gap open.
        if (range == ChartRange.day) 'includePrePost': 'true',
      }),
    );
    try {
      return _mapChart(json);
    } on TypeError catch (e) {
      throw NetworkFailure('unexpected v8 chart shape: $e');
    } on StateError catch (e) {
      throw NetworkFailure('unexpected v8 chart shape: $e');
    }
  }

  ChartSeries _mapChart(Map<String, Object?> json) {
    final result =
        ((json['chart'] as Map<String, Object?>?)?['result'] as List<Object?>?)
            ?.firstOrNull;
    if (result is! Map<String, Object?>) {
      throw StateError('missing chart.result');
    }
    final meta = result['meta'] as Map<String, Object?>;
    final baseline = (meta['chartPreviousClose'] as num).toDouble();

    final timestamps =
        (result['timestamp'] as List<Object?>?)?.cast<num?>() ?? const [];
    final quote =
        (((result['indicators'] as Map<String, Object?>?)?['quote']
                    as List<Object?>?)
                ?.firstOrNull
            as Map<String, Object?>?) ??
        const {};
    List<num?> series(String key) =>
        (quote[key] as List<Object?>?)?.cast<num?>() ?? const [];
    final opens = series('open');
    final highs = series('high');
    final lows = series('low');
    final closes = series('close');

    final candles = <Candle>[
      for (final (i, ts) in timestamps.indexed)
        // Yahoo pads unfinished bars with nulls; skip them.
        if (ts != null &&
            opens.elementAtOrNull(i) != null &&
            highs.elementAtOrNull(i) != null &&
            lows.elementAtOrNull(i) != null &&
            closes.elementAtOrNull(i) != null)
          Candle(
            time: DateTime.fromMillisecondsSinceEpoch(
              ts.toInt() * 1000,
              isUtc: true,
            ),
            open: opens[i]!.toDouble(),
            high: highs[i]!.toDouble(),
            low: lows[i]!.toDouble(),
            close: closes[i]!.toDouble(),
          ),
    ];
    return ChartSeries(baseline: baseline, candles: candles);
  }

  /// Baseline for the YTD percent, cached per symbol; null when the chart
  /// fetch fails — a quote must not fail because its YTD rank couldn't load.
  Future<double?> _ytdBaseline(String symbol) async {
    final cached = _ytdBaselineBySymbol[symbol];
    if (cached != null) return cached;
    try {
      final baseline = (await chart(symbol, ChartRange.ytd)).baseline;
      _ytdBaselineBySymbol[symbol] = baseline;
      return baseline;
    } on DataFailure {
      return null;
    }
  }

  Quote _mapQuote(Map<String, Object?> json, {double? ytdBaseline}) {
    try {
      final price = _double(json, 'regularMarketPrice');
      final (session, extChangePct) = _session(json);
      return Quote(
        price: price,
        dayChange: _double(json, 'regularMarketChange'),
        dayChangePct: _double(json, 'regularMarketChangePercent'),
        open: _double(json, 'regularMarketOpen'),
        high: _double(json, 'regularMarketDayHigh'),
        low: _double(json, 'regularMarketDayLow'),
        prevClose: _double(json, 'regularMarketPreviousClose'),
        volume: (json['regularMarketVolume'] as num?)?.toInt() ?? 0,
        marketCap: (json['marketCap'] as num?)?.toDouble(),
        ytdChangePct: ytdBaseline == null || ytdBaseline == 0
            ? null
            : (price - ytdBaseline) / ytdBaseline * 100,
        asOf: _epochSeconds(json['regularMarketTime']),
        session: session,
        extChangePct: extChangePct,
      );
    } on TypeError catch (e) {
      throw NetworkFailure('unexpected v7 quote shape: $e');
    } on StateError catch (e) {
      throw NetworkFailure('unexpected v7 quote shape: $e');
    }
  }

  /// Session + the state-matched extended-hours move (04 report null rules):
  /// PRE reads the pre field; POST/POSTPOST/PREPRE read the post field
  /// (during the overnight PREPRE window the previous post-session move is
  /// what the UI tags); null field = no extended data. Unknown states map to
  /// closed with no extended move.
  (MarketSession, double?) _session(Map<String, Object?> json) {
    final pre = (json['preMarketChangePercent'] as num?)?.toDouble();
    final post = (json['postMarketChangePercent'] as num?)?.toDouble();
    return switch (json['marketState']) {
      'PRE' => (MarketSession.pre, pre),
      'REGULAR' => (MarketSession.regular, null),
      'POST' || 'POSTPOST' || 'PREPRE' => (MarketSession.post, post),
      _ => (MarketSession.closed, null),
    };
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
