import 'package:tuantuan_stock/domain/models/quote.dart';

const detailQuoteRegularRefreshInterval = Duration(seconds: 5);
const watchlistQuotesRegularRefreshInterval = Duration(seconds: 10);
const extendedSessionRefreshInterval = Duration(seconds: 30);
const detailDayChartRegularRefreshInterval = Duration(seconds: 60);

Duration? detailQuoteRefreshInterval(Quote? latest) {
  return switch (latest?.session) {
    MarketSession.regular => detailQuoteRegularRefreshInterval,
    MarketSession.pre || MarketSession.post => extendedSessionRefreshInterval,
    MarketSession.closed => null,
    null => detailQuoteRegularRefreshInterval,
  };
}

Duration? watchlistQuotesRefreshInterval(Iterable<Quote> quotes) {
  final sessions = {for (final quote in quotes) quote.session};
  if (sessions.contains(MarketSession.regular)) {
    return watchlistQuotesRegularRefreshInterval;
  }
  if (sessions.contains(MarketSession.pre) ||
      sessions.contains(MarketSession.post)) {
    return extendedSessionRefreshInterval;
  }
  return null;
}

Duration? detailDayChartRefreshInterval(MarketSession? session) {
  return switch (session) {
    MarketSession.regular => detailDayChartRegularRefreshInterval,
    MarketSession.pre || MarketSession.post || MarketSession.closed => null,
    null => null,
  };
}
