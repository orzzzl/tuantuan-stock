import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/data/market/yahoo_client.dart';
import 'package:tuantuan_stock/data/market/yahoo_quote_repository.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';

const _aaplQuoteJson = <String, Object?>{
  'symbol': 'AAPL',
  'regularMarketPrice': 294.38,
  'regularMarketChange': 5.02,
  'regularMarketChangePercent': 1.73,
  'regularMarketOpen': 290.1,
  'regularMarketDayHigh': 295.2,
  'regularMarketDayLow': 289.5,
  'regularMarketPreviousClose': 289.36,
  'regularMarketVolume': 51234567,
  'marketCap': 4323663937536,
  'trailingPE': 36.63,
  'forwardPE': 31.05,
  'regularMarketTime': 1782936000,
  'marketState': 'POST',
  'postMarketChangePercent': 0.088,
};

/// The AAPL fixture with the session fields replaced; a null field is
/// removed entirely, matching Yahoo omitting it from the payload.
Map<String, Object?> _quoteWith({
  String? marketState,
  double? pre,
  double? post,
}) {
  return {
    ..._aaplQuoteJson,
    'marketState': marketState,
    'preMarketChangePercent': pre,
    'postMarketChangePercent': post,
  }..removeWhere((_, value) => value == null);
}

const _gspcQuoteJson = <String, Object?>{
  'symbol': '^GSPC',
  'regularMarketPrice': 7483.23,
  'regularMarketChange': -16.13,
  'regularMarketChangePercent': -0.22,
  'regularMarketOpen': 7501.0,
  'regularMarketDayHigh': 7512.4,
  'regularMarketDayLow': 7461.9,
  'regularMarketPreviousClose': 7499.36,
  'regularMarketVolume': 2345678901,
  'regularMarketTime': 1782936000,
};

/// In-memory Yahoo: serves the cookie/crumb dance, v7 quote and v8 chart,
/// recording calls so tests can assert on traffic shape.
class _FakeYahoo {
  _FakeYahoo({
    this.crumbs = const ['crumb-1'],
    this.rejectedCrumbs = const {},
    this.quoteResults = const [],
    this.quoteStatusOverride,
    this.chartBaselines = const {},
  });

  final List<String> crumbs;
  final Set<String> rejectedCrumbs;
  final List<Map<String, Object?>> quoteResults;
  final int? quoteStatusOverride;

  /// `'SYMBOL:range'` -> chartPreviousClose served by the v8 endpoint;
  /// unknown keys get a 404 (YTD enrichment then degrades to null).
  final Map<String, double> chartBaselines;

  int cookieCalls = 0;
  int crumbCalls = 0;
  int quoteCalls = 0;
  final quoteRequests = <http.Request>[];
  final chartRequests = <http.Request>[];
  final chartCallsBySymbol = <String, int>{};

  Future<http.Response> handle(http.Request request) async {
    final url = request.url;
    if (url.host == 'fc.yahoo.com') {
      cookieCalls++;
      return http.Response(
        '',
        404,
        headers: {
          'set-cookie':
              'A3=cookie-$cookieCalls; Expires=Wed, 01 Jan 2031 '
              '00:00:00 GMT; Domain=.yahoo.com; Path=/',
        },
      );
    }
    if (url.path == '/v1/test/getcrumb') {
      expect(request.headers['Cookie'], 'A3=cookie-$cookieCalls');
      crumbCalls++;
      return http.Response(crumbs[crumbCalls - 1], 200);
    }
    if (url.path == '/v7/finance/quote') {
      quoteCalls++;
      quoteRequests.add(request);
      if (quoteStatusOverride != null) {
        return http.Response('throttled', quoteStatusOverride!);
      }
      if (rejectedCrumbs.contains(url.queryParameters['crumb'])) {
        return http.Response('{"error":"Invalid Crumb"}', 401);
      }
      final wanted = url.queryParameters['symbols']!.split(',');
      final result = quoteResults
          .where((q) => wanted.contains(q['symbol']))
          .toList();
      return http.Response(
        '{"quoteResponse":{"result":${_jsonList(result)},"error":null}}',
        200,
      );
    }
    if (url.path.startsWith('/v8/finance/chart/')) {
      final symbol = url.pathSegments.last;
      chartRequests.add(request);
      chartCallsBySymbol.update(symbol, (n) => n + 1, ifAbsent: () => 1);
      final key = '$symbol:${url.queryParameters['range']}';
      final baseline = chartBaselines[key];
      if (baseline == null) {
        return http.Response('{"chart":{"result":null}}', 404);
      }
      return http.Response(
        '{"chart":{"result":[{'
        '"meta":{"chartPreviousClose":$baseline},'
        '"timestamp":[1000,2000,3000],'
        '"indicators":{"quote":[{'
        '"open":[1.0,2.0,3.0],'
        '"high":[1.5,2.5,3.5],'
        '"low":[0.5,1.5,2.5],'
        '"close":[1.2,null,3.2]'
        '}]}}],"error":null}}',
        200,
      );
    }
    return http.Response('unexpected ${url.path}', 500);
  }

  YahooClient client({List<Duration>? waits}) => YahooClient(
    httpClient: MockClient(handle),
    wait: (duration) async => waits?.add(duration),
  );
}

String _jsonList(List<Map<String, Object?>> items) =>
    '[${items.map(_jsonObject).join(',')}]';

String _jsonObject(Map<String, Object?> item) {
  final fields = item.entries
      .map((e) => '"${e.key}":${e.value is String ? '"${e.value}"' : e.value}')
      .join(',');
  return '{$fields}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('YahooQuoteRepository', () {
    test('maps a batched v7 quote to the domain Quote', () async {
      final yahoo = _FakeYahoo(
        quoteResults: const [_aaplQuoteJson, _gspcQuoteJson],
        chartBaselines: const {'AAPL:ytd': 271.86, '^GSPC:ytd': 6900.0},
      );
      final repo = YahooQuoteRepository(yahoo.client());

      final quotes = await repo.quotes(['AAPL', '^GSPC']);

      expect(yahoo.quoteCalls, 1, reason: 'one batched call, not per-symbol');
      final aapl = quotes['AAPL']!;
      expect(aapl.price, 294.38);
      expect(aapl.dayChange, 5.02);
      expect(aapl.dayChangePct, 1.73);
      expect(aapl.open, 290.1);
      expect(aapl.high, 295.2);
      expect(aapl.low, 289.5);
      expect(aapl.prevClose, 289.36);
      expect(aapl.volume, 51234567);
      expect(aapl.marketCap, 4323663937536.0);
      expect(aapl.trailingPe, 36.63);
      expect(aapl.forwardPe, 31.05);
      expect(aapl.asOf, DateTime.utc(2026, 7, 1, 20));
      expect(
        aapl.ytdChangePct,
        closeTo((294.38 - 271.86) / 271.86 * 100, 1e-9),
        reason: 'price vs the ytd chartPreviousClose',
      );
      expect(aapl.session, MarketSession.post);
      expect(aapl.extChangePct, 0.088);
    });

    test(
      'quoteSnapshots returns v7 quotes without YTD chart requests',
      () async {
        final yahoo = _FakeYahoo(
          quoteResults: const [_aaplQuoteJson],
          chartBaselines: const {'AAPL:ytd': 271.86},
        );

        final quotes = await YahooQuoteRepository(
          yahoo.client(),
        ).quoteSnapshots(['AAPL']);

        expect(yahoo.quoteCalls, 1);
        expect(yahoo.chartRequests, isEmpty);
        expect(quotes['AAPL']!.price, 294.38);
        expect(quotes['AAPL']!.ytdChangePct, isNull);
      },
    );

    test('leaves ytdChangePct null when the ytd chart fetch fails', () async {
      // No chartBaselines configured -> the v8 endpoint 404s.
      final yahoo = _FakeYahoo(quoteResults: const [_aaplQuoteJson]);

      final quote = await YahooQuoteRepository(yahoo.client()).quote('AAPL');

      expect(quote.ytdChangePct, isNull);
      expect(quote.price, 294.38, reason: 'quote itself must still succeed');
    });

    test('caches the YTD baseline across refreshes', () async {
      final yahoo = _FakeYahoo(
        quoteResults: const [_aaplQuoteJson],
        chartBaselines: const {'AAPL:ytd': 271.86},
      );
      final repo = YahooQuoteRepository(yahoo.client());

      await repo.quotes(['AAPL']);
      await repo.quotes(['AAPL']);

      expect(yahoo.quoteCalls, 2);
      expect(
        yahoo.chartCallsBySymbol['AAPL'],
        1,
        reason: 'the ytd baseline is constant within a year',
      );
    });

    test(
      'uses the persisted current-year YTD baseline without refetching',
      () async {
        final cache = MarketCacheStore(SharedPreferencesAsync());
        await cache.writeYtdBaseline(
          symbol: 'AAPL',
          year: 2026,
          baseline: 271.86,
        );
        final yahoo = _FakeYahoo(
          quoteResults: const [_aaplQuoteJson],
          chartBaselines: const {'AAPL:ytd': 123.45},
        );
        final repo = YahooQuoteRepository(
          yahoo.client(),
          cache: cache,
          now: () => DateTime.utc(2026, 7, 8),
        );

        final quote = (await repo.quotes(['AAPL']))['AAPL']!;

        expect(yahoo.chartRequests, isEmpty);
        expect(
          quote.ytdChangePct,
          closeTo((294.38 - 271.86) / 271.86 * 100, 1e-9),
        );
      },
    );

    test(
      'chart() sends the per-range v8 request and maps the series',
      () async {
        const requestByRange = <ChartRange, (String, String)>{
          ChartRange.day: ('1d', '5m'),
          ChartRange.week: ('5d', '1d'),
          ChartRange.month: ('1mo', '1d'),
          ChartRange.quarter: ('3mo', '1d'),
          ChartRange.ytd: ('ytd', '1d'),
          ChartRange.year: ('1y', '1d'),
          ChartRange.year5: ('5y', '1wk'),
          ChartRange.all: ('max', '1mo'),
        };
        const baselineByYahooRange = <String, double>{
          '1d': 289.36,
          '5d': 288.1,
          '1mo': 280.4,
          '3mo': 250.9,
          'ytd': 271.86,
          '1y': 240.5,
          '5y': 130.2,
          'max': 0.51,
        };
        final yahoo = _FakeYahoo(
          chartBaselines: {
            for (final MapEntry(key: range, value: baseline)
                in baselineByYahooRange.entries)
              'AAPL:$range': baseline,
          },
        );
        final repo = YahooQuoteRepository(yahoo.client());

        for (final MapEntry(key: range, value: (yahooRange, interval))
            in requestByRange.entries) {
          final series = await repo.chart('AAPL', range);
          final query = yahoo.chartRequests.last.url.queryParameters;

          expect(query['range'], yahooRange);
          expect(query['interval'], interval);
          expect(
            query['includePrePost'],
            range == ChartRange.day ? 'true' : isNull,
            reason: 'extended-hours bars only make sense on the day chart',
          );
          expect(
            series.baseline,
            baselineByYahooRange[yahooRange],
            reason: 'baseline == chartPreviousClose of the same response',
          );
          expect(
            series.candles.map((c) => c.close),
            [1.2, 3.2],
            reason: 'the null-padded unfinished bar is skipped',
          );
          expect(
            series.candles.first.time,
            DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
          );
        }
      },
    );

    test(
      'maps every marketState to session + state-matched ext field',
      () async {
        // Both ext fields are present so a wrong-field read cannot pass.
        const pre = 0.42;
        const post = -0.31;
        const expected = <String, (MarketSession, double?)>{
          'PRE': (MarketSession.pre, pre),
          'REGULAR': (MarketSession.regular, null),
          'POST': (MarketSession.post, post),
          'POSTPOST': (MarketSession.post, post),
          'PREPRE': (MarketSession.post, post),
          'CLOSED': (MarketSession.closed, null),
          'SOME_FUTURE_STATE': (MarketSession.closed, null),
        };

        for (final MapEntry(key: state, value: (session, extChangePct))
            in expected.entries) {
          final yahoo = _FakeYahoo(
            quoteResults: [
              _quoteWith(marketState: state, pre: pre, post: post),
            ],
          );

          final quote = await YahooQuoteRepository(
            yahoo.client(),
          ).quote('AAPL');

          expect(quote.session, session, reason: state);
          expect(quote.extChangePct, extChangePct, reason: state);
        }
      },
    );

    test('null ext field means no extended data, not zero', () async {
      for (final state in const ['PRE', 'POST']) {
        final yahoo = _FakeYahoo(
          quoteResults: [_quoteWith(marketState: state)],
        );

        final quote = await YahooQuoteRepository(yahoo.client()).quote('AAPL');

        expect(quote.extChangePct, isNull, reason: state);
      }
    });

    test(
      'sends browser UA, cookie and crumb on the authenticated call',
      () async {
        final yahoo = _FakeYahoo(quoteResults: const [_aaplQuoteJson]);

        await YahooQuoteRepository(yahoo.client()).quote('AAPL');

        final request = yahoo.quoteRequests.single;
        expect(request.headers['User-Agent'], contains('Mozilla/5.0'));
        expect(request.headers['Cookie'], 'A3=cookie-1');
        expect(request.url.queryParameters['crumb'], 'crumb-1');
        expect(request.url.queryParameters['symbols'], 'AAPL');
      },
    );

    test('refreshes cookie+crumb once on 401 and retries', () async {
      final yahoo = _FakeYahoo(
        crumbs: const ['stale', 'fresh'],
        rejectedCrumbs: const {'stale'},
        quoteResults: const [_aaplQuoteJson],
      );

      final quote = await YahooQuoteRepository(yahoo.client()).quote('AAPL');

      expect(quote.price, 294.38);
      expect(yahoo.quoteCalls, 2);
      expect(yahoo.cookieCalls, 2);
      expect(yahoo.crumbCalls, 2);
      expect(yahoo.quoteRequests.last.url.queryParameters['crumb'], 'fresh');
    });

    test('serves the index strip through the same seam', () async {
      final yahoo = _FakeYahoo(quoteResults: const [_gspcQuoteJson]);

      final quotes = await YahooQuoteRepository(
        yahoo.client(),
      ).quotes(indexStripSymbols);

      final gspc = quotes['^GSPC']!;
      expect(gspc.price, 7483.23);
      expect(gspc.prevClose, 7499.36);
      expect(gspc.marketCap, isNull, reason: 'indices have no market cap');
    });

    test('throws NotFoundFailure for a symbol Yahoo does not return', () async {
      final yahoo = _FakeYahoo(quoteResults: const []);

      expect(
        () => YahooQuoteRepository(yahoo.client()).quote('NOPE'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('backs off on 429 then throws RateLimitFailure', () async {
      final yahoo = _FakeYahoo(
        quoteResults: const [_aaplQuoteJson],
        quoteStatusOverride: 429,
      );
      final waits = <Duration>[];

      await expectLater(
        YahooQuoteRepository(yahoo.client(waits: waits)).quote('AAPL'),
        throwsA(isA<RateLimitFailure>()),
      );
      expect(yahoo.quoteCalls, 3);
      expect(
        waits,
        containsAllInOrder(const [Duration(seconds: 1), Duration(seconds: 2)]),
      );
    });

    test('maps transport errors to NetworkFailure', () async {
      final client = YahooClient(
        httpClient: MockClient((_) => throw http.ClientException('boom')),
        wait: (_) async {},
      );

      expect(
        () => YahooQuoteRepository(client).chart('AAPL', ChartRange.day),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('YahooClient', () {
    test('spaces consecutive requests by the minimum interval', () async {
      final yahoo = _FakeYahoo(
        chartBaselines: const {'AAPL:1d': 271.86, '^GSPC:1d': 6900.0},
      );
      final waits = <Duration>[];
      final frozen = DateTime.utc(2026, 7, 2, 12);
      final client = YahooClient(
        httpClient: MockClient(yahoo.handle),
        now: () => frozen,
        wait: (duration) async => waits.add(duration),
      );
      final repo = YahooQuoteRepository(client);

      await repo.chart('AAPL', ChartRange.day);
      await repo.chart('^GSPC', ChartRange.day);

      expect(waits, [const Duration(milliseconds: 400)]);
    });
  });
}
