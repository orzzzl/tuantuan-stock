/// One OHLC bar of a price chart.
class Candle {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  /// Start of the bar's interval.
  final DateTime time;

  final double open;
  final double high;
  final double low;
  final double close;

  @override
  bool operator ==(Object other) =>
      other is Candle &&
      other.time == time &&
      other.open == open &&
      other.high == high &&
      other.low == low &&
      other.close == close;

  @override
  int get hashCode => Object.hash(time, open, high, low, close);
}
