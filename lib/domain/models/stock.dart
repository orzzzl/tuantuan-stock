/// A listed security's identity: who it is, not what it trades at.
class Stock {
  const Stock({
    required this.symbol,
    required this.name,
    this.zhName,
    required this.exchange,
    this.logoAsset,
  });

  /// Ticker symbol, e.g. `AAPL` or `^GSPC` for an index.
  final String symbol;

  /// English company name.
  final String name;

  /// Chinese company name, when the provider knows one.
  final String? zhName;

  /// Exchange code, e.g. `NMS`.
  final String exchange;

  /// Bundled logo image asset path; null means render the ticker-ring
  /// fallback. Never a network URL: no logo host is reliably reachable from
  /// both mainland China and the US.
  final String? logoAsset;

  @override
  bool operator ==(Object other) =>
      other is Stock &&
      other.symbol == symbol &&
      other.name == name &&
      other.zhName == zhName &&
      other.exchange == exchange &&
      other.logoAsset == logoAsset;

  @override
  int get hashCode => Object.hash(symbol, name, zhName, exchange, logoAsset);
}
