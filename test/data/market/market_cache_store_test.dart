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
      'AAA': const Stock(
        symbol: 'AAA',
        name: 'Alpha Inc',
        exchange: 'NMS',
        logoUrl: 'https://example.com/a.png',
      ),
    });

    expect((await store.readStocks(['AAA']))['AAA']!.logoUrl, isNotNull);

    await SharedPreferencesAsync().setString(
      MarketCacheStore.stocksKey,
      '{"version":1,"stocks":{"AAA":"bad"}}',
    );

    expect(await store.readStocks(['AAA']), isEmpty);
  });

  test('corrupt quote cache is ignored and removed', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(MarketCacheStore.quoteSnapshotsKey, '{bad json');

    expect(await cache().readQuoteSnapshots(['AAA']), isNull);
    expect(await prefs.getString(MarketCacheStore.quoteSnapshotsKey), isNull);
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
