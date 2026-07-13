import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  MarketCacheStore cache() => MarketCacheStore(SharedPreferencesAsync());

  test('quote snapshots persist and read back by requested symbols', () async {
    final store = cache();
    final fetchedAt = DateTime.utc(2026, 7, 8, 5, 30);

    await store.writeQuoteSnapshots({
      'AAA': _quote(1),
      'BBB': _quote(-2),
    }, fetchedAt);

    final cached = await store.readQuoteSnapshots(['BBB', 'AAA']);

    expect(cached, isNotNull);
    expect(cached!.isStale, isTrue);
    expect(cached.fetchedAt, fetchedAt);
    expect(cached.quotes.keys, ['BBB', 'AAA']);
    expect(cached.quotes['AAA']!.dayChangePct, 1);
  });

  test('stock identities persist and corrupt entries are dropped', () async {
    final store = cache();
    await store.writeStocks({
      'AAA': const Stock(symbol: 'AAA', name: 'Alpha Inc', exchange: 'NMS'),
    });

    expect((await store.readStocks(['AAA']))['AAA']!.name, 'Alpha Inc');
    expect(
      (await store.readStocks(['AAA']))['AAA']!.logoAsset,
      isNull,
      reason: 'AAA is not in the bundled pack',
    );

    await SharedPreferencesAsync().setString(
      MarketCacheStore.stocksKey,
      '{"version":1,"stocks":{"AAA":"bad"}}',
    );

    expect(await store.readStocks(['AAA']), isEmpty);
  });

  test('stock logo is derived from the bundled pack at read time', () async {
    final store = cache();
    await store.writeStocks({
      'AAPL': const Stock(symbol: 'AAPL', name: 'Apple Inc.', exchange: 'NMS'),
    });

    final aapl = (await store.readStocks(['AAPL']))['AAPL']!;
    expect(aapl.logoAsset, 'assets/logos/aapl.png');
  });

  test('corrupt quote cache is ignored and removed', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(MarketCacheStore.quoteSnapshotsKey, '{bad json');

    expect(await cache().readQuoteSnapshots(['AAA']), isNull);
    expect(await prefs.getString(MarketCacheStore.quoteSnapshotsKey), isNull);
  });

  group('ext points (task 27)', () {
    const day = '2026-07-08';

    test('appended points read back as flat candles per session', () async {
      final store = cache();
      await store.appendExtPoints(
        easternDate: day,
        session: MarketSession.pre,
        points: {
          'AAPL': (time: DateTime.utc(2026, 7, 8, 8, 12), price: 311.19),
          'MSFT': (time: DateTime.utc(2026, 7, 8, 8, 12), price: 388.5),
        },
      );
      await store.appendExtPoints(
        easternDate: day,
        session: MarketSession.pre,
        points: {
          'AAPL': (time: DateTime.utc(2026, 7, 8, 8, 13), price: 311.42),
        },
      );
      await store.appendExtPoints(
        easternDate: day,
        session: MarketSession.post,
        points: {
          'AAPL': (time: DateTime.utc(2026, 7, 8, 20, 15), price: 313.22),
        },
      );

      final aapl = (await store.readExtPoints('AAPL'))!;
      expect(aapl.easternDate, day);
      expect(aapl.pre, hasLength(2));
      expect(aapl.pre.first.time, DateTime.utc(2026, 7, 8, 8, 12));
      expect(aapl.pre.first.close, 311.19);
      expect(aapl.pre.first.open, 311.19);
      expect(aapl.pre.last.close, 311.42);
      expect(aapl.post.single.time, DateTime.utc(2026, 7, 8, 20, 15));
      expect(aapl.post.single.close, 313.22);

      expect((await store.readExtPoints('MSFT'))!.pre, hasLength(1));
      expect((await store.readExtPoints('ZZZZ'))!.pre, isEmpty);
    });

    test('a repeat of the latest minute stamp is skipped', () async {
      final store = cache();
      final stamp = DateTime.utc(2026, 7, 8, 8, 12);
      await store.appendExtPoints(
        easternDate: day,
        session: MarketSession.pre,
        points: {'AAPL': (time: stamp, price: 311.19)},
      );
      await store.appendExtPoints(
        easternDate: day,
        session: MarketSession.pre,
        points: {'AAPL': (time: stamp, price: 311.19)},
      );

      expect((await store.readExtPoints('AAPL'))!.pre, hasLength(1));
    });

    test('a new Eastern date wipes the previous day', () async {
      final store = cache();
      await store.appendExtPoints(
        easternDate: day,
        session: MarketSession.post,
        points: {
          'AAPL': (time: DateTime.utc(2026, 7, 8, 20, 15), price: 313.22),
        },
      );
      await store.appendExtPoints(
        easternDate: '2026-07-09',
        session: MarketSession.pre,
        points: {'AAPL': (time: DateTime.utc(2026, 7, 9, 8, 5), price: 314.0)},
      );

      final aapl = (await store.readExtPoints('AAPL'))!;
      expect(aapl.easternDate, '2026-07-09');
      expect(aapl.post, isEmpty);
      expect(aapl.pre.single.close, 314.0);
    });

    test('corrupt ext store is dropped; bad rows are skipped', () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setString(MarketCacheStore.extPointsKey, '{bad json');
      expect(await cache().readExtPoints('AAPL'), isNull);
      expect(await prefs.getString(MarketCacheStore.extPointsKey), isNull);

      await prefs.setString(
        MarketCacheStore.extPointsKey,
        '{"version":1,"date":"$day","symbols":{"AAPL":{"pre":'
        '[{"t":"not a time","p":1},"bad",{"t":"2026-07-08T08:12:00.000Z",'
        '"p":311.19}]}}}',
      );
      final aapl = (await cache().readExtPoints('AAPL'))!;
      expect(aapl.pre.single.close, 311.19);
    });
  });
}

Quote _quote(double dayChangePct) {
  return Quote(
    price: 100,
    dayChange: dayChangePct,
    dayChangePct: dayChangePct,
    open: 99,
    high: 104,
    low: 96,
    prevClose: 100,
    volume: 1000,
    marketCap: 1e11,
    ytdChangePct: 10,
    asOf: DateTime.utc(2026, 7, 8, 5),
    session: MarketSession.regular,
  );
}
