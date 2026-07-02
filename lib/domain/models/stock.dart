/// A listed security's identity: who it is, not what it trades at.
class Stock {
  const Stock({
    required this.symbol,
    required this.name,
    this.zhName,
    required this.exchange,
    this.logoUrl,
  });

  /// Ticker symbol, e.g. `AAPL` or `^GSPC` for an index.
  final String symbol;

  /// English company name.
  final String name;

  /// Chinese company name, when the provider knows one.
  final String? zhName;

  /// Exchange code, e.g. `NMS`.
  final String exchange;

  /// Company logo image URL; null means render the ticker-ring fallback.
  final String? logoUrl;

  @override
  bool operator ==(Object other) =>
      other is Stock &&
      other.symbol == symbol &&
      other.name == name &&
      other.zhName == zhName &&
      other.exchange == exchange &&
      other.logoUrl == logoUrl;

  @override
  int get hashCode => Object.hash(symbol, name, zhName, exchange, logoUrl);
}
