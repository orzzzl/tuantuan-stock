import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';

void main() {
  DateTime eastern(int year, int month, int day, int hour, [int minute = 0]) =>
      easternToUtc(DateTime.utc(year, month, day, hour, minute));

  group('isOvernightSession', () {
    test('uses inclusive 20:00 and exclusive 04:00 ET bounds', () {
      expect(isOvernightSession(eastern(2026, 7, 13, 19, 59)), isFalse);
      expect(isOvernightSession(eastern(2026, 7, 13, 20)), isTrue);
      expect(isOvernightSession(eastern(2026, 7, 14, 3, 59)), isTrue);
      expect(isOvernightSession(eastern(2026, 7, 14, 4)), isFalse);
    });

    test('starts on Sunday and runs across midnight', () {
      expect(isOvernightSession(eastern(2026, 7, 12, 19, 59)), isFalse);
      expect(isOvernightSession(eastern(2026, 7, 12, 20)), isTrue);
      expect(isOvernightSession(eastern(2026, 7, 13, 3, 59)), isTrue);
    });

    test('includes the Thursday start and Friday 04:00 end', () {
      expect(isOvernightSession(eastern(2026, 7, 16, 19, 59)), isFalse);
      expect(isOvernightSession(eastern(2026, 7, 16, 20)), isTrue);
      expect(isOvernightSession(eastern(2026, 7, 17, 3, 59)), isTrue);
      expect(isOvernightSession(eastern(2026, 7, 17, 4)), isFalse);
    });

    test('excludes Friday and Saturday nights', () {
      expect(isOvernightSession(eastern(2026, 7, 17, 20)), isFalse);
      expect(isOvernightSession(eastern(2026, 7, 18, 3, 59)), isFalse);
      expect(isOvernightSession(eastern(2026, 7, 18, 20)), isFalse);
      expect(isOvernightSession(eastern(2026, 7, 19, 3, 59)), isFalse);
    });

    test('follows the Eastern clock after the spring DST transition', () {
      expect(isOvernightSession(eastern(2026, 3, 8, 20)), isTrue);
      expect(isOvernightSession(eastern(2026, 3, 9, 3, 59)), isTrue);
      expect(isOvernightSession(eastern(2026, 3, 9, 4)), isFalse);
    });
  });

  group('isExtendedSessionWindowNow', () {
    bool now(MarketSession session, DateTime instant) =>
        isExtendedSessionWindowNow(session, instant);

    test('pre holds 04:00-09:30 ET on weekdays only', () {
      expect(now(MarketSession.pre, eastern(2026, 7, 13, 4)), isTrue);
      expect(now(MarketSession.pre, eastern(2026, 7, 13, 9, 29)), isTrue);
      expect(now(MarketSession.pre, eastern(2026, 7, 13, 3, 59)), isFalse);
      expect(now(MarketSession.pre, eastern(2026, 7, 13, 9, 30)), isFalse);
      expect(now(MarketSession.pre, eastern(2026, 7, 18, 5)), isFalse);
    });

    test('post holds 16:00-20:00 ET on weekdays only', () {
      expect(now(MarketSession.post, eastern(2026, 7, 13, 16)), isTrue);
      expect(now(MarketSession.post, eastern(2026, 7, 13, 19, 59)), isTrue);
      expect(now(MarketSession.post, eastern(2026, 7, 13, 15, 59)), isFalse);
      expect(now(MarketSession.post, eastern(2026, 7, 13, 20)), isFalse);
      expect(now(MarketSession.post, eastern(2026, 7, 18, 17)), isFalse);
    });

    test('a cached post is stale deep in the overnight window '
        '(the 2026-07-21 field report: offline at ~01:10 ET)', () {
      expect(now(MarketSession.post, eastern(2026, 7, 14, 1, 10)), isFalse);
    });

    test('overnight follows isOvernightSession', () {
      expect(now(MarketSession.overnight, eastern(2026, 7, 13, 20)), isTrue);
      expect(now(MarketSession.overnight, eastern(2026, 7, 14, 3, 59)), isTrue);
      expect(now(MarketSession.overnight, eastern(2026, 7, 14, 12)), isFalse);
      expect(now(MarketSession.overnight, eastern(2026, 7, 18, 1)), isFalse);
    });

    test('regular and closed never claim an extended window', () {
      expect(now(MarketSession.regular, eastern(2026, 7, 13, 12)), isFalse);
      expect(now(MarketSession.closed, eastern(2026, 7, 13, 12)), isFalse);
    });
  });
}
