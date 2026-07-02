import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tuantuan_stock/data/market/yahoo_client.dart';
import 'package:tuantuan_stock/data/market/yahoo_company_profiles.dart';
import 'package:tuantuan_stock/data/market/yahoo_quote_repository.dart';
import 'package:tuantuan_stock/data/market/yahoo_search_repository.dart';
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
  'regularMarketTime': 1782936000,
};

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

/// In-memory Yahoo: serves the cookie/crumb dance, v7 quote, v1 search and
/// v10 quoteSummary, recording calls so tests can assert on traffic shape.
class _FakeYahoo {
  _FakeYahoo({
    this.crumbs = const ['crumb-1'],
    this.rejectedCrumbs = const {},
    this.quoteResults = const [],
    this.searchResults = const [],
    this.websiteBySymbol = const {},
    this.quoteStatusOverride,
  });

  final List<String> crumbs;
  final Set<String> rejectedCrumbs;
  final List<Map<String, Object?>> quoteResults;
  final List<Map<String, Object?>> searchResults;
  final Map<String, String> websiteBySymbol;
  final int? quoteStatusOverride;

  int cookieCalls = 0;
  int crumbCalls = 0;
  int quoteCalls = 0;
  final quoteRequests = <http.Request>[];
  final summaryCallsBySymbol = <String, int>{};

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
    if (url.path == '/v1/finance/search') {
      return http.Response('{"quotes":${_jsonList(searchResults)}}', 200);
    }
    if (url.path.startsWith('/v10/finance/quoteSummary/')) {
      final symbol = url.pathSegments.last;
      summaryCallsBySymbol.update(symbol, (n) => n + 1, ifAbsent: () => 1);
      final website = websiteBySymbol[symbol];
      final profile = website == null ? '{}' : '{"website":"$website"}';
      return http.Response(
        '{"quoteSummary":{"result":[{"assetProfile":$profile}],'
        '"error":null}}',
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
  group('YahooQuoteRepository', () {
    test('maps a batched v7 quote to the domain Quote', () async {
      final yahoo = _FakeYahoo(
        quoteResults: const [_aaplQuoteJson, _gspcQuoteJson],
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
      expect(aapl.asOf, DateTime.utc(2026, 7, 1, 20));
      expect(aapl.ytdChangePct, isNull, reason: 'lands with task 06');
      expect(aapl.session, MarketSession.closed, reason: 'task 06');
      expect(aapl.extChangePct, isNull, reason: 'task 06');
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
        () => YahooSearchRepository(
          client,
          YahooCompanyProfiles(client),
        ).search('apple'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('YahooSearchRepository', () {
    _FakeYahoo searchFake() => _FakeYahoo(
      searchResults: const [
        {
          'symbol': 'AAPL',
          'shortname': 'Apple Inc.',
          'exchange': 'NMS',
          'quoteType': 'EQUITY',
        },
        {
          'symbol': 'SHOP.TO',
          'shortname': 'Shopify Inc.',
          'exchange': 'TOR',
          'quoteType': 'EQUITY',
        },
        {
          'symbol': 'VOO',
          'shortname': 'Vanguard S&P 500 ETF',
          'exchange': 'PCX',
          'quoteType': 'ETF',
        },
        {
          'symbol': '^GSPC',
          'shortname': 'S&P 500',
          'exchange': 'SNP',
          'quoteType': 'INDEX',
        },
      ],
      websiteBySymbol: const {'AAPL': 'https://www.apple.com'},
    );

    test('filters to US equities/ETFs and resolves logos', () async {
      final yahoo = searchFake();
      final client = yahoo.client();
      final repo = YahooSearchRepository(client, YahooCompanyProfiles(client));

      final stocks = await repo.search('apple');

      expect(stocks.map((s) => s.symbol), ['AAPL', 'VOO']);
      final aapl = stocks.first;
      expect(aapl.name, 'Apple Inc.');
      expect(aapl.exchange, 'NMS');
      expect(
        aapl.logoUrl,
        'https://www.google.com/s2/favicons?domain=www.apple.com&sz=128',
      );
      expect(stocks.last.logoUrl, isNull, reason: 'no website in profile');
    });

    test('caches profile lookups across searches', () async {
      final yahoo = searchFake();
      final client = yahoo.client();
      final repo = YahooSearchRepository(client, YahooCompanyProfiles(client));

      await repo.search('apple');
      await repo.search('apple');

      expect(yahoo.summaryCallsBySymbol['AAPL'], 1);
    });
  });

  group('YahooClient', () {
    test('spaces consecutive requests by the minimum interval', () async {
      final yahoo = _FakeYahoo(searchResults: const []);
      final waits = <Duration>[];
      final frozen = DateTime.utc(2026, 7, 2, 12);
      final client = YahooClient(
        httpClient: MockClient(yahoo.handle),
        now: () => frozen,
        wait: (duration) async => waits.add(duration),
      );
      final repo = YahooSearchRepository(client, YahooCompanyProfiles(client));

      await repo.search('a');
      await repo.search('b');

      expect(waits, [const Duration(milliseconds: 400)]);
    });
  });
}
