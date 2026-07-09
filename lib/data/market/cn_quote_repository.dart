import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/data/market/cn_market_client.dart';
import 'package:tuantuan_stock/data/market/cn_symbols.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
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
/// the v0.1 Yahoo fields and as [Quote.dayChangePct]/[Quote.extChangePct],
/// whose consumers divide by 100 before `formatPercent`. Do not rescale.
class CnQuoteRepository implements QuoteSnapshotRepository {
  CnQuoteRepository(
    this._client, {
    required this._chartDelegate,
    this._cache,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final CnMarketClient _client;
  final QuoteRepository _chartDelegate;
  final MarketCacheStore? _cache;
  final DateTime Function() _now;

  /// YTD baselines (last year's final close) are constant for a calendar
  /// year, so one fetch per symbol serves the whole process lifetime.
  final _ytdBaselineByKey = <String, double>{};

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
    final snapshots = (await quoteSnapshots(symbols)).entries.toList();
    final baselines = await Future.wait(
      snapshots.map((entry) => _ytdBaseline(entry.key)),
    );
    return {
      for (final (i, MapEntry(:key, :value)) in snapshots.indexed)
        key: _withYtd(value, baselines[i]),
    };
  }

  // TODO(18): serve charts from the pinned Tencent kline / Sina minK
  // endpoints; until then the Yahoo implementation keeps this seam alive.
  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) =>
      _chartDelegate.chart(symbol, range);

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

  /// Baseline for the YTD percent, cached per symbol; null when the chart
  /// fetch fails — a quote must not fail because its YTD rank couldn't load.
  Future<double?> _ytdBaseline(String symbol) async {
    final year = _now().toUtc().year;
    final key = '$symbol|$year';
    final cached = _ytdBaselineByKey[key];
    if (cached != null) return cached;

    final diskCached = await _cache?.readYtdBaseline(symbol, year);
    if (diskCached != null) {
      _ytdBaselineByKey[key] = diskCached;
      return diskCached;
    }

    try {
      final baseline = (await chart(symbol, ChartRange.ytd)).baseline;
      _ytdBaselineByKey[key] = baseline;
      await _cache?.writeYtdBaseline(
        symbol: symbol,
        year: year,
        baseline: baseline,
      );
      return baseline;
    } on DataFailure {
      return null;
    }
  }
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
