import 'package:tuantuan_stock/data/market/overnight_quote_coordinator.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';

/// Request-free decorator over the primary provider. Alpaca is contacted only
/// by [OvernightQuoteCoordinator], never from a quote repository call.
class OvernightQuoteRepository
    implements QuoteSnapshotRepository, QuoteYtdRepository {
  OvernightQuoteRepository(
    this._delegate,
    this._coordinator, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final QuoteRepository _delegate;
  final OvernightQuoteCoordinator _coordinator;
  final DateTime Function() _now;

  @override
  Future<Quote> quote(String symbol) async => mergeOvernightQuote(
    await _delegate.quote(symbol),
    symbol,
    _coordinator.snapshot,
    now: _now(),
  );

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) async =>
      _mergeAll(await _delegate.quotes(symbols));

  @override
  Future<Map<String, Quote>> quoteSnapshots(List<String> symbols) async {
    final quotes = switch (_delegate) {
      final QuoteSnapshotRepository snapshots => await snapshots.quoteSnapshots(
        symbols,
      ),
      _ => await _delegate.quotes(symbols),
    };
    return _mergeAll(quotes);
  }

  @override
  Future<Map<String, Quote>> ytdQuotes(List<String> symbols) async {
    final quotes = switch (_delegate) {
      final QuoteYtdRepository ytd => await ytd.ytdQuotes(symbols),
      _ => await _delegate.quotes(symbols),
    };
    return _mergeAll(quotes);
  }

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) =>
      _delegate.chart(symbol, range);

  Map<String, Quote> _mergeAll(Map<String, Quote> quotes) => Map.unmodifiable({
    for (final MapEntry(:key, :value) in quotes.entries)
      key: mergeOvernightQuote(value, key, _coordinator.snapshot, now: _now()),
  });
}

/// Turns a usable quote midpoint into the existing extended-session seam.
/// The regular quote's price remains authoritative; the UI shows the move in
/// its session chip, just like pre/post-market data.
Quote mergeOvernightQuote(
  Quote quote,
  String symbol,
  OvernightSnapshot snapshot, {
  required DateTime now,
}) {
  final overnight = snapshot.quotes[symbol];
  if (overnight == null ||
      overnight.timestamp.toUtc().isBefore(
        now.toUtc().subtract(overnightQuoteMaxAge),
      ) ||
      quote.price == 0) {
    return quote;
  }
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
    ytdChangePct: quote.ytdChangePct,
    asOf: quote.asOf,
    session: MarketSession.overnight,
    extChangePct: (overnight.midpoint - quote.price) / quote.price * 100,
  );
}
