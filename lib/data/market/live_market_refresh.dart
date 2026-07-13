import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';

const detailQuoteRegularRefreshInterval = Duration(seconds: 5);
const watchlistQuotesRegularRefreshInterval = Duration(seconds: 10);
const extendedSessionRefreshInterval = Duration(seconds: 30);
const detailDayChartRegularRefreshInterval = Duration(seconds: 60);
const _liveSessionStartMinute = 4 * 60;
const _liveSessionEndMinute = 20 * 60;

Duration? detailQuoteRefreshInterval(Quote? latest) {
  return switch (latest?.session) {
    MarketSession.regular => detailQuoteRegularRefreshInterval,
    MarketSession.pre || MarketSession.post => extendedSessionRefreshInterval,
    MarketSession.overnight || MarketSession.closed => null,
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
    // A live extended session repolls at the locked ext cadence so the
    // chart's pre/post zones gain the points the quote poll accumulates
    // (task 27).
    MarketSession.pre || MarketSession.post => extendedSessionRefreshInterval,
    MarketSession.overnight || MarketSession.closed => null,
    null => null,
  };
}

Duration closedSessionRefreshDelay(DateTime now) {
  final utc = now.toUtc();
  final eastern = utcToEastern(utc);
  final minutes = eastern.hour * 60 + eastern.minute;
  if (_isWeekday(eastern) &&
      minutes >= _liveSessionStartMinute &&
      minutes < _liveSessionEndMinute) {
    return extendedSessionRefreshInterval;
  }

  final nextStart = _nextLiveSessionStart(eastern);
  final delay = easternToUtc(nextStart).difference(utc);
  return delay.isNegative ? Duration.zero : delay;
}

DateTime _nextLiveSessionStart(DateTime eastern) {
  var target = DateTime.utc(
    eastern.year,
    eastern.month,
    eastern.day,
    _liveSessionStartMinute ~/ 60,
  );
  final minutes = eastern.hour * 60 + eastern.minute;
  if (!_isWeekday(eastern) || minutes >= _liveSessionEndMinute) {
    target = target.add(const Duration(days: 1));
  }
  while (!_isWeekday(target)) {
    target = target.add(const Duration(days: 1));
  }
  return target;
}

bool _isWeekday(DateTime eastern) =>
    eastern.weekday >= DateTime.monday && eastern.weekday <= DateTime.friday;
