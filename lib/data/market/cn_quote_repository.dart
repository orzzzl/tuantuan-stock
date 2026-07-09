import 'dart:async';
import 'dart:math' as math;

import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/data/market/cn_market_client.dart';
import 'package:tuantuan_stock/data/market/cn_symbols.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';

/// [QuoteRepository] backed by the per-feature pinning of report v2 §1:
/// batched prices from Tencent `qt.gtimg.cn`, extended-hours figures from
/// Sina `hq.sinajs.cn`, the session from Tencent's market-state tokens. One
/// refresh = one request per source, whatever the batch size (§7).
///
/// Percent-convention audit (task 17): Tencent field 32 and Sina field 22
/// deliver PERCENT POINTS (`-0.64` means −0.64%) — the same convention as
/// the v0.1 provider fields and as [Quote.dayChangePct]/[Quote.extChangePct],
/// whose consumers divide by 100 before `formatPercent`. Do not rescale.
class CnQuoteRepository implements QuoteSnapshotRepository, QuoteYtdRepository {
  CnQuoteRepository(this._client, {this._cache, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final CnMarketClient _client;
  final MarketCacheStore? _cache;
  final DateTime Function() _now;

  /// YTD baselines (last year's final close) are constant for a calendar
  /// year, so one fetch per symbol serves the whole process lifetime.
  final _ytdBaselineByKey = <String, double>{};
  final _ytdBaselineFutureByKey = <String, Future<double?>>{};

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
  Future<Map<String, Quote>> quoteSnapshots(List<String> symbols) async {
    if (symbols.isEmpty) return const {};
    // One round-trip per source, fired together; only the Tencent batch is
    // load-bearing — the other two feed decorations and degrade instead.
    final tencentFuture = _client.tencentQuotes(symbols);
    final sinaFuture = _sinaQuotes(symbols);
    final sessionFuture = _session();
    final tencent = await tencentFuture;
    final sina = await sinaFuture;
    final session = await sessionFuture;
    return {
      for (final MapEntry(:key, :value) in tencent.entries)
        key: _mapQuote(key, value, session: session, sina: sina[key]),
    };
  }

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) async {
    if (symbols.isEmpty) return const {};
    final snapshots = await quoteSnapshots(symbols);
    final year = _now().toUtc().year;
    for (final symbol in snapshots.keys) {
      _primeYtdBaseline(symbol, year);
    }
    return {
      for (final MapEntry(:key, :value) in snapshots.entries)
        key: _withYtd(value, _ytdBaselineByKey[_ytdKey(key, year)]),
    };
  }

  @override
  Future<Map<String, Quote>> ytdQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return const {};
    final snapshots = (await quoteSnapshots(symbols)).entries.toList();
    final year = _now().toUtc().year;
    final baselines = await Future.wait(
      snapshots.map((entry) => _ytdBaseline(entry.key, year)),
    );
    return {
      for (final (i, MapEntry(:key, :value)) in snapshots.indexed)
        key: _withYtd(value, baselines[i]),
    };
  }

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) async {
    final fields = await _tencentFields(symbol);
    return switch (range) {
      ChartRange.day => _dayChart(symbol, fields),
      ChartRange.week => _klineChart(
        symbol,
        fields,
        range: range,
        granularity: CnKlineGranularity.day,
      ),
      ChartRange.month => _klineChart(
        symbol,
        fields,
        range: range,
        granularity: CnKlineGranularity.day,
      ),
      ChartRange.quarter => _klineChart(
        symbol,
        fields,
        range: range,
        granularity: CnKlineGranularity.day,
      ),
      ChartRange.ytd => _klineChart(
        symbol,
        fields,
        range: range,
        granularity: CnKlineGranularity.day,
      ),
      ChartRange.year => _klineChart(
        symbol,
        fields,
        range: range,
        granularity: CnKlineGranularity.day,
      ),
      ChartRange.year5 => _klineChart(
        symbol,
        fields,
        range: range,
        granularity: CnKlineGranularity.week,
      ),
      ChartRange.all => _klineChart(
        symbol,
        fields,
        range: range,
        granularity: CnKlineGranularity.month,
      ),
    };
  }

  /// Extended-hours rows are chip decoration: a Sina failure degrades to no
  /// chips rather than failing the refresh. Indices have no Sina feed and
  /// are filtered out; an all-index batch skips the request entirely.
  Future<Map<String, List<String>>> _sinaQuotes(List<String> symbols) async {
    final quotable = symbols
        .where((symbol) => sinaQuoteSymbol(symbol) != null)
        .toList();
    if (quotable.isEmpty) return const {};
    try {
      return await _client.sinaQuotes(quotable);
    } on DataFailure {
      return const {};
    }
  }

  /// The session drives chips only, so an unreadable state feed degrades to
  /// closed (no extended chips) rather than failing the refresh.
  Future<MarketSession> _session() async {
    try {
      return sessionFromMarketTokens(await _client.usMarketState());
    } on DataFailure {
      return MarketSession.closed;
    }
  }

  Future<List<String>> _tencentFields(String symbol) async {
    final fields = (await _client.tencentQuotes([symbol]))[symbol];
    if (fields == null) {
      throw NotFoundFailure('no quote for $symbol');
    }
    return fields;
  }

  Future<ChartSeries> _dayChart(String symbol, List<String> fields) async {
    if (symbol.startsWith('^')) {
      throw NetworkFailure('Sina minK unsupported for $symbol');
    }
    try {
      final tradingDate = _tradingDate(fields);
      final baseline = double.parse(fields[4]);
      final rows = await _client.sinaMin5(symbol);
      final candles = [
        for (final row in rows)
          if (row['d'] case final String dateTime
              when dateTime.startsWith('$tradingDate '))
            _sinaMin5Bar(row).toCandle(),
      ];
      return ChartSeries(
        baseline: baseline,
        candles: List.unmodifiable(candles),
      );
    } on FormatException catch (e) {
      throw NetworkFailure('unexpected day chart shape for $symbol: $e');
    } on RangeError catch (e) {
      throw NetworkFailure('unexpected day chart shape for $symbol: $e');
    } on StateError catch (e) {
      throw NetworkFailure('unexpected day chart shape for $symbol: $e');
    }
  }

  Future<ChartSeries> _klineChart(
    String symbol,
    List<String> fields, {
    required ChartRange range,
    required CnKlineGranularity granularity,
  }) async {
    final rows = await _tencentKlineBars(symbol, fields, granularity);
    if (rows.isEmpty) {
      throw NetworkFailure('empty Tencent kline for $symbol');
    }
    return switch (range) {
      ChartRange.week => _lastBarsSeries(rows, 5),
      ChartRange.month => _dateWindowSeries(
        rows,
        _subtractMonths(rows.last.time, 1),
      ),
      ChartRange.quarter => _dateWindowSeries(
        rows,
        _subtractMonths(rows.last.time, 3),
      ),
      ChartRange.ytd => _ytdSeries(rows),
      ChartRange.year => _dateWindowSeries(
        rows,
        _subtractMonths(rows.last.time, 12),
      ),
      ChartRange.year5 => _dateWindowSeries(
        rows,
        _subtractMonths(rows.last.time, 60),
      ),
      ChartRange.all => ChartSeries(
        baseline: rows.first.close,
        candles: List.unmodifiable(rows.map((row) => row.toCandle())),
      ),
      ChartRange.day => throw StateError('day chart is not Tencent kline'),
    };
  }

  Future<List<_PriceBar>> _tencentKlineBars(
    String symbol,
    List<String> fields,
    CnKlineGranularity granularity,
  ) async {
    final rawRows = await _client.tencentKline(
      klineSymbol: _tencentKlineSymbol(symbol, fields),
      granularity: granularity,
    );
    try {
      return [for (final row in rawRows) _tencentKlineBar(row)];
    } on FormatException catch (e) {
      throw NetworkFailure('unexpected Tencent kline shape for $symbol: $e');
    } on RangeError catch (e) {
      throw NetworkFailure('unexpected Tencent kline shape for $symbol: $e');
    }
  }

  ChartSeries _lastBarsSeries(List<_PriceBar> rows, int count) {
    final first = math.max(0, rows.length - count);
    final baseline = rows[math.max(0, first - 1)].close;
    return ChartSeries(
      baseline: baseline,
      candles: List.unmodifiable(rows.skip(first).map((row) => row.toCandle())),
    );
  }

  ChartSeries _dateWindowSeries(List<_PriceBar> rows, DateTime start) {
    final first = rows.indexWhere((row) => !row.time.isBefore(start));
    if (first < 0) {
      throw NetworkFailure('Tencent kline has no rows in requested window');
    }
    final baseline = rows[math.max(0, first - 1)].close;
    return ChartSeries(
      baseline: baseline,
      candles: List.unmodifiable(rows.skip(first).map((row) => row.toCandle())),
    );
  }

  ChartSeries _ytdSeries(List<_PriceBar> rows) {
    final year = rows.last.time.year;
    final first = rows.indexWhere((row) => row.time.year == year);
    if (first < 0) {
      throw NetworkFailure('Tencent kline has no current-year rows');
    }
    final baseline = _lastCloseBeforeYear(rows, year) ?? rows[first].close;
    return ChartSeries(
      baseline: baseline,
      candles: List.unmodifiable(rows.skip(first).map((row) => row.toCandle())),
    );
  }

  Quote _mapQuote(
    String symbol,
    List<String> fields, {
    required MarketSession session,
    List<String>? sina,
  }) {
    try {
      final marketCap = double.tryParse(fields[45]);
      final trailingPe = double.tryParse(fields[39]);
      return Quote(
        price: double.parse(fields[3]),
        dayChange: double.parse(fields[31]),
        dayChangePct: double.parse(fields[32]),
        open: double.parse(fields[5]),
        high: double.parse(fields[33]),
        low: double.parse(fields[34]),
        prevClose: double.parse(fields[4]),
        volume: int.parse(fields[6]),
        // Total market cap arrives in hundred-million (1e8) USD; empty for
        // indices.
        marketCap: marketCap == null || marketCap == 0 ? null : marketCap * 1e8,
        trailingPe: trailingPe == null || trailingPe <= 0 ? null : trailingPe,
        // Not in the Tencent payload (report §4.1).
        forwardPe: null,
        ytdChangePct: null,
        asOf: easternToUtc(DateTime.parse(fields[30])),
        session: session,
        extChangePct: _extChangePct(session, sina),
      );
    } on FormatException catch (e) {
      throw NetworkFailure('unexpected Tencent quote shape for $symbol: $e');
    } on RangeError catch (e) {
      throw NetworkFailure('unexpected Tencent quote shape for $symbol: $e');
    }
  }

  /// The chip only shows a move from the session it claims (the v0.1 PREPRE
  /// rule, report §6): a pre chip needs a pre-stamped Sina figure, a post
  /// chip a post-stamped one. Anything else — stale figure from the previous
  /// session, missing row (dotted tickers, §5) — renders no chip.
  double? _extChangePct(MarketSession session, List<String>? sina) {
    if (sina == null || sina.length <= 24) return null;
    final pct = double.tryParse(sina[22]);
    final minutes = easternMinutesOfDay(sina[24]);
    if (pct == null || minutes == null) return null;
    return switch (session) {
      MarketSession.pre when minutes < 9 * 60 + 30 => pct,
      MarketSession.post when minutes >= 16 * 60 => pct,
      _ => null,
    };
  }

  Quote _withYtd(Quote quote, double? baseline) {
    if (baseline == null || baseline == 0) return quote;
    return Quote(
      price: quote.price,
      dayChange: quote.dayChange,
      dayChangePct: quote.dayChangePct,
      open: quote.open,
      high: quote.high,
      low: quote.low,
      prevClose: quote.prevClose,
      volume: quote.volume,
      marketCap: quote.marketCap,
      trailingPe: quote.trailingPe,
      forwardPe: quote.forwardPe,
      ytdChangePct: (quote.price - baseline) / baseline * 100,
      asOf: quote.asOf,
      session: quote.session,
      extChangePct: quote.extChangePct,
    );
  }

  /// Starts the slow YTD baseline read/fetch, but never waits for it on the
  /// quote path. A later call can decorate quotes from memory/disk once ready.
  void _primeYtdBaseline(String symbol, int year) {
    unawaited(_ytdBaseline(symbol, year));
  }

  Future<double?> _ytdBaseline(String symbol, int year) {
    final key = _ytdKey(symbol, year);
    final cached = _ytdBaselineByKey[key];
    if (cached != null) return Future.value(cached);
    return _ytdBaselineFutureByKey[key] ??= _resolveYtdBaseline(
      symbol,
      year,
      key,
    );
  }

  Future<double?> _resolveYtdBaseline(
    String symbol,
    int year,
    String key,
  ) async {
    try {
      final diskCached = await _cache?.readYtdBaseline(symbol, year);
      if (diskCached != null) {
        _ytdBaselineByKey[key] = diskCached;
        return diskCached;
      }

      final baseline = await _ytdBaselineFromDailyKline(symbol, year);
      _ytdBaselineByKey[key] = baseline;
      await _cache?.writeYtdBaseline(
        symbol: symbol,
        year: year,
        baseline: baseline,
      );
      return baseline;
    } on Object {
      // YTD is a decoration; quote refreshes must not fail or hang on it.
      return null;
    }
  }

  Future<double> _ytdBaselineFromDailyKline(String symbol, int year) async {
    final fields = await _tencentFields(symbol);
    final rows = await _tencentKlineBars(
      symbol,
      fields,
      CnKlineGranularity.day,
    );
    final baseline = _lastCloseBeforeYear(rows, year);
    if (baseline == null) {
      throw NetworkFailure('Tencent kline has no prior-year close for $symbol');
    }
    return baseline;
  }

  static String _ytdKey(String symbol, int year) => '$symbol|$year';
}

/// Session from the Tencent market-state tokens (report §6): `USB_open` =
/// pre, `US_open` = regular, `USA_open` = post, all-close = closed.
MarketSession sessionFromMarketTokens(String market) {
  String? state(String prefix) {
    for (final token in market.split('|')) {
      if (token.startsWith(prefix)) {
        return token.substring(prefix.length).split('_').first;
      }
    }
    return null;
  }

  if (state('USB_') == 'open') return MarketSession.pre;
  if (state('USA_') == 'open') return MarketSession.post;
  if (state('US_') == 'open') return MarketSession.regular;
  return MarketSession.closed;
}

String _tencentKlineSymbol(String symbol, List<String> fields) {
  try {
    final fullCode = fields[2];
    if (fullCode.isEmpty || fullCode.startsWith('.')) {
      throw StateError('unsupported kline code $fullCode for $symbol');
    }
    return 'us$fullCode';
  } on RangeError catch (e) {
    throw NetworkFailure('unexpected Tencent quote shape for $symbol: $e');
  } on StateError catch (e) {
    throw NetworkFailure('unexpected Tencent quote shape for $symbol: $e');
  }
}

String _tradingDate(List<String> fields) {
  final timestamp = fields[30];
  if (timestamp.length < 10) {
    throw StateError('missing trade date');
  }
  return timestamp.substring(0, 10);
}

_PriceBar _tencentKlineBar(List<String> row) => _PriceBar(
  time: _dateOnly(row[0]),
  open: double.parse(row[1]),
  high: double.parse(row[3]),
  low: double.parse(row[4]),
  close: double.parse(row[2]),
);

_PriceBar _sinaMin5Bar(Map<String, String> row) => _PriceBar(
  time: easternToUtc(DateTime.parse(row['d']!)),
  open: double.parse(row['o']!),
  high: double.parse(row['h']!),
  low: double.parse(row['l']!),
  close: double.parse(row['c']!),
);

DateTime _dateOnly(String raw) => DateTime.utc(
  int.parse(raw.substring(0, 4)),
  int.parse(raw.substring(5, 7)),
  int.parse(raw.substring(8, 10)),
);

DateTime _subtractMonths(DateTime date, int months) {
  var year = date.year;
  var month = date.month - months;
  while (month <= 0) {
    year -= 1;
    month += 12;
  }
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, math.min(date.day, lastDay));
}

double? _lastCloseBeforeYear(List<_PriceBar> rows, int year) {
  for (var i = rows.length - 1; i >= 0; i -= 1) {
    if (rows[i].time.year < year) {
      return rows[i].close;
    }
  }
  return null;
}

class _PriceBar {
  const _PriceBar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;

  Candle toCandle() =>
      Candle(time: time, open: open, high: high, low: low, close: close);
}
