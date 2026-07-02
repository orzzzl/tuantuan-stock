import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';

Quote _quote({
  double price = 101.5,
  MarketSession session = MarketSession.regular,
  double? extChangePct,
}) {
  return Quote(
    price: price,
    dayChange: 1.5,
    dayChangePct: 1.5,
    open: 100.2,
    high: 102.0,
    low: 99.8,
    prevClose: 100.0,
    volume: 1234567,
    marketCap: 3.1e12,
    ytdChangePct: 12.3,
    asOf: DateTime.utc(2026, 7, 1, 20),
    session: session,
    extChangePct: extChangePct,
  );
}

void main() {
  group('Stock', () {
    test('equal field-by-field', () {
      const a = Stock(symbol: 'AAPL', name: 'Apple Inc.', exchange: 'NMS');
      const b = Stock(symbol: 'AAPL', name: 'Apple Inc.', exchange: 'NMS');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('optional zhName and logoUrl participate in equality', () {
      const bare = Stock(symbol: 'AAPL', name: 'Apple Inc.', exchange: 'NMS');
      const branded = Stock(
        symbol: 'AAPL',
        name: 'Apple Inc.',
        zhName: 'apple-zh',
        exchange: 'NMS',
        logoUrl: 'https://example.com/aapl.png',
      );
      expect(bare, isNot(branded));
    });
  });

  group('Quote', () {
    test('equal field-by-field', () {
      expect(_quote(), _quote());
      expect(_quote().hashCode, _quote().hashCode);
    });

    test('differs by price and by session', () {
      expect(_quote(), isNot(_quote(price: 99.0)));
      expect(_quote(), isNot(_quote(session: MarketSession.post)));
    });

    test('carries the extended-hours move when outside regular hours', () {
      final afterHours = _quote(
        session: MarketSession.post,
        extChangePct: -0.4,
      );
      expect(afterHours.extChangePct, -0.4);
      expect(_quote().extChangePct, isNull);
    });
  });

  group('Candle', () {
    test('equal field-by-field', () {
      final a = Candle(
        time: DateTime.utc(2026, 7, 1),
        open: 1,
        high: 2,
        low: 0.5,
        close: 1.5,
      );
      final b = Candle(
        time: DateTime.utc(2026, 7, 1),
        open: 1,
        high: 2,
        low: 0.5,
        close: 1.5,
      );
      expect(a, b);
      expect(
        a,
        isNot(Candle(time: a.time, open: 1, high: 2, low: 0.5, close: 2)),
      );
    });
  });

  group('ChartRange', () {
    test('covers day through year including ytd', () {
      expect(ChartRange.values, [
        ChartRange.day,
        ChartRange.week,
        ChartRange.month,
        ChartRange.quarter,
        ChartRange.ytd,
        ChartRange.year,
      ]);
    });
  });

  group('DataFailure', () {
    test('subtypes are distinguishable by type and keep their message', () {
      const DataFailure failure = RateLimitFailure('429 from provider');
      expect(failure, isA<RateLimitFailure>());
      expect(failure, isNot(isA<NetworkFailure>()));
      expect(failure.toString(), 'RateLimitFailure: 429 from provider');
    });

    test('exhaustive switch over the sealed hierarchy compiles', () {
      String describe(DataFailure f) => switch (f) {
        NetworkFailure() => 'network',
        RateLimitFailure() => 'rate-limit',
        AuthFailure() => 'auth',
        NotFoundFailure() => 'not-found',
      };
      expect(describe(const NotFoundFailure('no such symbol')), 'not-found');
    });
  });
}
