import 'dart:io';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/data/market/cn_market_client.dart';
import 'package:tuantuan_stock/data/market/cn_quote_repository.dart';
import 'package:tuantuan_stock/data/market/cn_search_repository.dart';
import 'package:tuantuan_stock/data/market/cn_stock_repository.dart';
import 'package:tuantuan_stock/data/market/cn_symbols.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/data_failure.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/repositories/quote_repository.dart';

// Chinese provider-payload literals, written as Unicode escapes so the
// hand-written source stays ASCII (AGENTS.md: no Chinese outside *.arb).
const _zhApple = '\u82f9\u679c'; // "Apple"
const _zhDowJones = '\u9053\u743c\u65af'; // "Dow Jones"
const _zhAppleHospitalityReit = // "Apple Hospitality REIT"
    '\u82f9\u679c\u9152\u5e97\u623f\u5730\u4ea7\u4fe1\u6258';
// The market-token spellings observed in the Tencent payload (report §6).
const _zhNotOpen = '\u672a\u5f00\u76d8'; // "not open yet"
const _zhPreTrading = '\u76d8\u524d\u4ea4\u6613'; // "pre-market trading"
const _zhTrading = '\u4ea4\u6613\u4e2d'; // "trading"
const _zhClosed = '\u5df2\u6536\u76d8'; // "closed"
const _zhPostTrading = '\u76d8\u540e\u4ea4\u6613'; // "post-market trading"

/// Raw provider bytes captured by the task-16 probes — GBK stays GBK so the
/// decode path is exercised end to end.
Uint8List _fixture(String name) =>
    File('test/fixtures/provider_v2/$name').readAsBytesSync();

/// In-memory Tencent/Sina: byte bodies per host, recording requests so tests
/// can assert on traffic shape (one batch per source, headers, URL forms).
class _FakeCnHosts {
  _FakeCnHosts({
    this.tencentQuote,
    this.sinaQuote,
    this.suggest,
    this.kline,
    this.sinaQuoteStatus = 200,
    this.klineStatus = 200,
  });

  Uint8List? tencentQuote;
  Uint8List? sinaQuote;
  Uint8List? suggest;
  Uint8List? kline;
  final int sinaQuoteStatus;
  final int klineStatus;

  final requests = <Uri>[];

  int count(String host) => requests.where((uri) => uri.host == host).length;

  CnMarketClient client() => CnMarketClient(httpClient: MockClient(_handle));

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request.url);
    switch (request.url.host) {
      case 'qt.gtimg.cn':
        return http.Response.bytes(tencentQuote!, 200);
      case 'hq.sinajs.cn':
        expect(request.headers['Referer'], 'https://finance.sina.com.cn');
        return http.Response.bytes(sinaQuote!, sinaQuoteStatus);
      case 'suggest3.sinajs.cn':
        expect(request.headers['Referer'], 'https://finance.sina.com.cn');
        return http.Response.bytes(suggest!, 200);
      case 'web.ifzq.gtimg.cn':
        return http.Response.bytes(kline!, klineStatus);
    }
    fail('unexpected host ${request.url.host}');
  }
}

/// Chart-seam stand-in for the Yahoo delegate that task 18 replaces.
class _FakeChartDelegate implements QuoteRepository {
  _FakeChartDelegate({this.baseline = 300.0});

  final double baseline;
  final chartCalls = <(String, ChartRange)>[];

  @override
  Future<ChartSeries> chart(String symbol, ChartRange range) async {
    chartCalls.add((symbol, range));
    return ChartSeries(baseline: baseline, candles: const []);
  }

  @override
  Future<Quote> quote(String symbol) => throw UnimplementedError();

  @override
  Future<Map<String, Quote>> quotes(List<String> symbols) =>
      throw UnimplementedError();
}

CnQuoteRepository _quoteRepository(
  _FakeCnHosts hosts, {
  _FakeChartDelegate? chartDelegate,
}) => CnQuoteRepository(
  hosts.client(),
  chartDelegate: chartDelegate ?? _FakeChartDelegate(),
);

/// A minimal Tencent quote row with the identity/price positions filled the
/// way `qt.gtimg.cn` fills them (report §4.1).
String _tencentRow({
  required String query,
  required String zhName,
  required String fullCode,
  required String enName,
}) {
  final fields = List.filled(67, '0');
  fields[1] = zhName;
  fields[2] = fullCode;
  fields[3] = '100.0';
  fields[4] = '99.0';
  fields[5] = '99.5';
  fields[6] = '1000';
  fields[30] = '2026-07-07 16:00:01';
  fields[31] = '1.0';
  fields[32] = '1.01';
  fields[33] = '101.0';
  fields[34] = '98.0';
  fields[46] = enName;
  return 'v_$query="${fields.join('~')}";';
}

Uint8List _gbkBytes(String text) => Uint8List.fromList(gbk.encode(text));

void main() {
  group('symbol mapping (report §5)', () {
    test('Tencent quote symbols keep dots and pin the indices', () {
      expect(tencentQuoteSymbol('AAPL'), 'usAAPL');
      expect(tencentQuoteSymbol('BRK.B'), 'usBRK.B');
      expect(tencentQuoteSymbol('SPY'), 'usSPY');
      expect(tencentQuoteSymbol('^GSPC'), 'usINX');
      expect(tencentQuoteSymbol('^IXIC'), 'usIXIC');
      expect(tencentQuoteSymbol('^DJI'), 'usDJI');
    });

    test('Sina quote symbols lowercase, keep dots, refuse indices', () {
      expect(sinaQuoteSymbol('AAPL'), 'gb_aapl');
      expect(sinaQuoteSymbol('BRK.B'), 'gb_brk.b');
      expect(sinaQuoteSymbol('^GSPC'), null);
    });

    test('suggest symbols uppercase and restore the class-share dot', () {
      expect(appSymbolFromSuggest('aapl'), 'AAPL');
      expect(appSymbolFromSuggest(r'brk$b'), 'BRK.B');
    });

    test('exchange codes from Tencent full-code suffixes', () {
      expect(exchangeFromTencentFullCode('AAPL.OQ'), 'NMS');
      expect(exchangeFromTencentFullCode('BRK.B.N'), 'NYQ');
      expect(exchangeFromTencentFullCode('SPY.AM'), 'PCX');
      expect(exchangeFromTencentFullCode('.DJI'), '');
    });
  });

  group('Eastern time', () {
    test('easternToUtc applies EDT in summer and EST in winter', () {
      expect(
        easternToUtc(DateTime.parse('2026-07-07 16:00:01')),
        DateTime.utc(2026, 7, 7, 20, 0, 1),
      );
      expect(
        easternToUtc(DateTime.parse('2026-01-15 12:00:00')),
        DateTime.utc(2026, 1, 15, 17, 0, 0),
      );
    });

    test('DST flips on the 2026 US boundaries', () {
      // 2026: DST starts Mar 8 02:00, ends Nov 1 02:00.
      expect(
        easternToUtc(DateTime.parse('2026-03-08 01:59:00')),
        DateTime.utc(2026, 3, 8, 6, 59),
      );
      expect(
        easternToUtc(DateTime.parse('2026-03-08 03:00:00')),
        DateTime.utc(2026, 3, 8, 7, 0),
      );
      expect(
        easternToUtc(DateTime.parse('2026-11-01 02:00:00')),
        DateTime.utc(2026, 11, 1, 7, 0),
      );
    });

    test('easternMinutesOfDay reads the Sina extended timestamps', () {
      expect(easternMinutesOfDay('Jul 08 04:12AM EDT'), 4 * 60 + 12);
      expect(easternMinutesOfDay('Jul 07 07:59PM EDT'), 19 * 60 + 59);
      expect(easternMinutesOfDay('Jan 02 12:00AM EST'), 0);
      expect(easternMinutesOfDay(''), null);
      expect(easternMinutesOfDay('not a time'), null);
    });
  });

  group('session tokens (report §6)', () {
    test('all six observed spellings map to the right session', () {
      expect(
        sessionFromMarketTokens(
          'US_close_$_zhNotOpen|USB_open_$_zhPreTrading|USA_close_$_zhNotOpen',
        ),
        MarketSession.pre,
      );
      expect(
        sessionFromMarketTokens(
          'US_open_$_zhTrading|USB_close_$_zhClosed|USA_close_$_zhNotOpen',
        ),
        MarketSession.regular,
      );
      expect(
        sessionFromMarketTokens(
          'US_close_$_zhClosed|USB_close_$_zhClosed|USA_open_$_zhPostTrading',
        ),
        MarketSession.post,
      );
      expect(
        sessionFromMarketTokens(
          'US_close_$_zhNotOpen|USB_close_$_zhNotOpen|USA_close_$_zhNotOpen',
        ),
        MarketSession.closed,
      );
    });
  });

  group('quoteSnapshots', () {
    test('maps the Tencent batch with one request per source', () async {
      final hosts = _FakeCnHosts(
        tencentQuote: _fixture('tencent_quote_batch.gbk.txt'),
        sinaQuote: _fixture('sina_quote_batch.gbk.txt'),
        kline: _fixture('tencent_kline_day1_regular.json'),
      );
      final quotes = await _quoteRepository(
        hosts,
      ).quoteSnapshots(['AAPL', 'MSFT', 'BRK.B']);

      final aapl = quotes['AAPL']!;
      expect(aapl.price, 310.66);
      expect(aapl.prevClose, 312.66);
      expect(aapl.open, 315.29);
      expect(aapl.high, 315.48);
      expect(aapl.low, 310.15);
      expect(aapl.volume, 42490002);
      expect(aapl.dayChange, -2.00);
      // The audit line: percent POINTS, exactly as the payload spells them.
      expect(aapl.dayChangePct, -0.64);
      expect(aapl.marketCap, closeTo(4562774015000, 1e6));
      expect(aapl.trailingPe, 37.61);
      expect(aapl.forwardPe, null);
      expect(aapl.ytdChangePct, null);
      expect(aapl.asOf, DateTime.utc(2026, 7, 7, 20, 0, 1));
      expect(aapl.session, MarketSession.regular);
      expect(aapl.extChangePct, null);

      expect(quotes['MSFT']!.price, 388.84);
      // Dotted tickers have no Sina row (§5) — quote fine, no ext figure.
      expect(quotes['BRK.B']!.price, 504.00);
      expect(quotes['BRK.B']!.extChangePct, null);

      // One watchlist refresh = one batched request per source, no
      // serialized per-symbol fan-out.
      expect(hosts.count('qt.gtimg.cn'), 1);
      expect(hosts.count('hq.sinajs.cn'), 1);
      expect(hosts.count('web.ifzq.gtimg.cn'), 1);
      expect(
        hosts.requests.firstWhere((uri) => uri.host == 'qt.gtimg.cn').path,
        '/q=usAAPL,usMSFT,usBRK.B',
      );
      expect(
        hosts.requests.firstWhere((uri) => uri.host == 'hq.sinajs.cn').path,
        '/list=gb_aapl,gb_msft,gb_brk.b',
      );
    });

    test('pre-market: pre-stamped Sina figure becomes the chip', () async {
      final hosts = _FakeCnHosts(
        tencentQuote: _fixture('tencent_quote_aapl_premarket.gbk.txt'),
        sinaQuote: _fixture('sina_quote_aapl_premarket.gbk.txt'),
        kline: _fixture('tencent_kline_day1_premarket.json'),
      );
      final quotes = await _quoteRepository(hosts).quoteSnapshots(['AAPL']);
      expect(quotes['AAPL']!.session, MarketSession.pre);
      expect(quotes['AAPL']!.extChangePct, 0.17);
    });

    test('post-market: post-stamped Sina figure becomes the chip', () async {
      final hosts = _FakeCnHosts(
        tencentQuote: _fixture('tencent_quote_aapl_postmarket.gbk.txt'),
        sinaQuote: _fixture('sina_quote_aapl_postmarket.gbk.txt'),
        kline: _fixture('tencent_kline_day1_postmarket.json'),
      );
      final quotes = await _quoteRepository(hosts).quoteSnapshots(['AAPL']);
      expect(quotes['AAPL']!.session, MarketSession.post);
      expect(quotes['AAPL']!.extChangePct, 0.82);
    });

    test('a stale post figure never renders as a pre chip', () async {
      final hosts = _FakeCnHosts(
        tencentQuote: _fixture('tencent_quote_aapl_premarket.gbk.txt'),
        // Batch fixture: AAPL's ext figure is stamped `Jul 07 07:59PM EDT`.
        sinaQuote: _fixture('sina_quote_batch.gbk.txt'),
        kline: _fixture('tencent_kline_day1_premarket.json'),
      );
      final quotes = await _quoteRepository(hosts).quoteSnapshots(['AAPL']);
      expect(quotes['AAPL']!.session, MarketSession.pre);
      expect(quotes['AAPL']!.extChangePct, null);
    });

    test('indices skip Sina entirely and carry no cap/PE', () async {
      final hosts = _FakeCnHosts(
        tencentQuote: _fixture('tencent_quote_indices.gbk.txt'),
        kline: _fixture('tencent_kline_day1_regular.json'),
      );
      final quotes = await _quoteRepository(
        hosts,
      ).quoteSnapshots(['^GSPC', '^IXIC', '^DJI']);

      expect(quotes['^GSPC']!.price, 7503.85);
      expect(quotes['^GSPC']!.marketCap, null);
      expect(quotes['^GSPC']!.trailingPe, null);
      expect(quotes['^DJI']!.dayChangePct, -0.25);
      expect(hosts.count('hq.sinajs.cn'), 0);
      expect(
        hosts.requests.firstWhere((uri) => uri.host == 'qt.gtimg.cn').path,
        '/q=usINX,usIXIC,usDJI',
      );
    });

    test('Sina/session failures degrade to chip-less quotes', () async {
      final hosts = _FakeCnHosts(
        tencentQuote: _fixture('tencent_quote_batch.gbk.txt'),
        sinaQuote: _gbkBytes('server error'),
        sinaQuoteStatus: 500,
        kline: _gbkBytes('server error'),
        klineStatus: 500,
      );
      final quotes = await _quoteRepository(hosts).quoteSnapshots(['AAPL']);
      expect(quotes['AAPL']!.price, 310.66);
      expect(quotes['AAPL']!.session, MarketSession.closed);
      expect(quotes['AAPL']!.extChangePct, null);
    });

    test('a malformed Tencent body fails the refresh loudly', () async {
      final hosts = _FakeCnHosts(
        tencentQuote: _gbkBytes('<html>not a quote feed</html>'),
        sinaQuote: _fixture('sina_quote_batch.gbk.txt'),
        kline: _fixture('tencent_kline_day1_regular.json'),
      );
      await expectLater(
        _quoteRepository(hosts).quoteSnapshots(['AAPL']),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('unknown symbols are absent and quote() maps to NotFound', () async {
      final hosts = _FakeCnHosts(
        tencentQuote: _gbkBytes('v_pv_none_match="1";'),
        sinaQuote: _gbkBytes('var hq_str_gb_zzzz="";'),
        kline: _fixture('tencent_kline_day1_regular.json'),
      );
      final repository = _quoteRepository(hosts);
      expect(await repository.quoteSnapshots(['ZZZZ']), isEmpty);
      await expectLater(
        repository.quote('ZZZZ'),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('quotes() YTD decoration and the chart seam', () {
    test('quotes() adds the YTD percent from the delegated chart', () async {
      final delegate = _FakeChartDelegate(baseline: 300);
      final hosts = _FakeCnHosts(
        tencentQuote: _fixture('tencent_quote_batch.gbk.txt'),
        sinaQuote: _fixture('sina_quote_batch.gbk.txt'),
        kline: _fixture('tencent_kline_day1_regular.json'),
      );
      final repository = _quoteRepository(hosts, chartDelegate: delegate);

      final quotes = await repository.quotes(['AAPL']);
      expect(
        quotes['AAPL']!.ytdChangePct,
        closeTo((310.66 - 300) / 300 * 100, 1e-9),
      );
      expect(delegate.chartCalls, [('AAPL', ChartRange.ytd)]);

      // The baseline is constant within a year: no second chart fetch.
      await repository.quotes(['AAPL']);
      expect(delegate.chartCalls, hasLength(1));
    });

    test('chart() delegates until task 18 moves it to CN endpoints', () async {
      final delegate = _FakeChartDelegate();
      final repository = _quoteRepository(
        _FakeCnHosts(),
        chartDelegate: delegate,
      );
      await repository.chart('AAPL', ChartRange.day);
      expect(delegate.chartCalls, [('AAPL', ChartRange.day)]);
    });
  });

  group('identity', () {
    test(
      'stocks() maps names, zh names and exchanges from GBK bytes',
      () async {
        final hosts = _FakeCnHosts(
          tencentQuote: _fixture('tencent_quote_batch.gbk.txt'),
        );
        final stocks = await CnStockRepository(
          hosts.client(),
        ).stocks(['AAPL', 'MSFT', 'BRK.B']);

        expect(stocks['AAPL']!.name, 'Apple Inc.');
        expect(stocks['AAPL']!.zhName, _zhApple);
        expect(stocks['AAPL']!.exchange, 'NMS');
        expect(stocks['AAPL']!.logoUrl, null);
        expect(stocks['BRK.B']!.name, 'Berkshire Hathaway Inc. New');
        expect(stocks['BRK.B']!.exchange, 'NYQ');
        expect(hosts.count('qt.gtimg.cn'), 1);
      },
    );

    test('index identities have zh names and no exchange', () async {
      final hosts = _FakeCnHosts(
        tencentQuote: _fixture('tencent_quote_indices.gbk.txt'),
      );
      final stocks = await CnStockRepository(hosts.client()).stocks(['^DJI']);
      expect(stocks['^DJI']!.name, 'Dow Jones');
      expect(stocks['^DJI']!.zhName, _zhDowJones);
      expect(stocks['^DJI']!.exchange, '');
    });
  });

  group('search', () {
    test('suggest matches resolve to Tencent identities in order', () async {
      final hosts = _FakeCnHosts(
        suggest: _fixture('sina_suggest_apple.gbk.txt'),
        tencentQuote: _gbkBytes(
          [
            _tencentRow(
              query: 'usAAPL',
              zhName: _zhApple,
              fullCode: 'AAPL.OQ',
              enName: 'Apple Inc.',
            ),
            _tencentRow(
              query: 'usAAPY',
              zhName: '',
              fullCode: 'AAPY.OQ',
              enName: 'Kurv Yield Premium Strategy Apple ETF',
            ),
            _tencentRow(
              query: 'usAPLE',
              zhName: _zhAppleHospitalityReit,
              fullCode: 'APLE.N',
              enName: 'Apple Hospitality REIT Inc.',
            ),
            _tencentRow(
              query: 'usPAPL',
              zhName: '',
              fullCode: 'PAPL.AM',
              enName: 'Pineapple Financial Inc.',
            ),
          ].join('\n'),
        ),
      );
      final results = await CnSearchRepository(hosts.client()).search('apple');

      expect(results.map((stock) => stock.symbol).toList(), [
        'AAPL',
        'AAPY',
        'APLE',
        'PAPL',
      ]);
      expect(results.first.name, 'Apple Inc.');
      expect(results.first.zhName, _zhApple);
      expect(results.first.exchange, 'NMS');
      expect(results[1].zhName, null);
      expect(results[2].exchange, 'NYQ');
      // One suggest + one identity batch; no per-result fan-out.
      expect(hosts.count('suggest3.sinajs.cn'), 1);
      expect(hosts.count('qt.gtimg.cn'), 1);
    });

    test('Chinese queries work and are percent-encoded', () async {
      final hosts = _FakeCnHosts(
        suggest: _fixture('sina_suggest_pingguo.gbk.txt'),
        tencentQuote: _gbkBytes(
          _tencentRow(
            query: 'usAAPL',
            zhName: _zhApple,
            fullCode: 'AAPL.OQ',
            enName: 'Apple Inc.',
          ),
        ),
      );
      final results = await CnSearchRepository(hosts.client()).search(_zhApple);

      // AAPX is in the suggest payload but unknown to the identity batch
      // here — dropped rather than rendered without an identity.
      expect(results.map((stock) => stock.symbol).toList(), ['AAPL']);
      final suggestUri = hosts.requests.firstWhere(
        (uri) => uri.host == 'suggest3.sinajs.cn',
      );
      expect(suggestUri.path, contains('key=${Uri.encodeComponent(_zhApple)}'));
    });

    test('non-US listing types are filtered out', () async {
      final hosts = _FakeCnHosts(
        suggest: _gbkBytes(
          'var suggestvalue="Foo HK,31,00700,00700,Foo HK,,Foo HK,99,1,,,;'
          'Apple,41,aapl,aapl,Apple,,Apple,99,1,,,";',
        ),
        tencentQuote: _gbkBytes(
          _tencentRow(
            query: 'usAAPL',
            zhName: _zhApple,
            fullCode: 'AAPL.OQ',
            enName: 'Apple Inc.',
          ),
        ),
      );
      final results = await CnSearchRepository(hosts.client()).search('foo');
      expect(results.map((stock) => stock.symbol).toList(), ['AAPL']);
    });

    test('blank queries return empty without touching the network', () async {
      final hosts = _FakeCnHosts();
      final results = await CnSearchRepository(hosts.client()).search('   ');
      expect(results, isEmpty);
      expect(hosts.requests, isEmpty);
    });
  });
}
