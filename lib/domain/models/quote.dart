/// Which trading session a quote was taken in.
enum MarketSession {
  /// Pre-market.
  pre,

  /// Regular trading hours.
  regular,

  /// After-hours.
  post,

  /// Market closed, no extended-hours trading in progress.
  closed,
}

/// A point-in-time price snapshot for one symbol.
class Quote {
  const Quote({
    required this.price,
    required this.dayChange,
    required this.dayChangePct,
    required this.open,
    required this.high,
    required this.low,
    required this.prevClose,
    required this.volume,
    this.marketCap,
    this.trailingPe,
    this.forwardPe,
    this.ytdChangePct,
    required this.asOf,
    required this.session,
    this.extChangePct,
  });

  /// Last traded price in the regular session.
  final double price;

  /// Absolute change vs [prevClose].
  final double dayChange;

  /// Percent change vs [prevClose]; drives the daily-race sort and medals.
  final double dayChangePct;

  final double open;
  final double high;
  final double low;

  /// Previous regular-session close — the 0% waterline for the day chart.
  final double prevClose;

  final int volume;

  /// Market capitalization in USD; null for indices, which have none.
  final double? marketCap;

  /// Trailing twelve-month P/E; null for indices, ETFs, and loss-making
  /// companies (no meaningful earnings multiple).
  final double? trailingPe;

  /// Forward P/E from consensus estimates; null when there is none.
  final double? forwardPe;

  /// Percent change since the first trading day of the year; drives the
  /// YTD `#N` rank. Null when the YTD fetch has not resolved (it comes from
  /// the chart endpoint, not the quote endpoint).
  final double? ytdChangePct;

  /// Provider timestamp of this snapshot.
  final DateTime asOf;

  /// Session the market is in as of [asOf].
  final MarketSession session;

  /// Extended-hours percent move; non-null only when [session] is
  /// [MarketSession.pre] or [MarketSession.post] and drives the pre/post chip.
  final double? extChangePct;

  @override
  bool operator ==(Object other) =>
      other is Quote &&
      other.price == price &&
      other.dayChange == dayChange &&
      other.dayChangePct == dayChangePct &&
      other.open == open &&
      other.high == high &&
      other.low == low &&
      other.prevClose == prevClose &&
      other.volume == volume &&
      other.marketCap == marketCap &&
      other.trailingPe == trailingPe &&
      other.forwardPe == forwardPe &&
      other.ytdChangePct == ytdChangePct &&
      other.asOf == asOf &&
      other.session == session &&
      other.extChangePct == extChangePct;

  @override
  int get hashCode => Object.hash(
    price,
    dayChange,
    dayChangePct,
    open,
    high,
    low,
    prevClose,
    volume,
    marketCap,
    trailingPe,
    forwardPe,
    ytdChangePct,
    asOf,
    session,
    extChangePct,
  );
}
