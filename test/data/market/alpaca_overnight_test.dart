import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tuantuan_stock/data/market/alpaca_overnight_client.dart';
import 'package:tuantuan_stock/data/market/overnight_quote_coordinator.dart';
import 'package:tuantuan_stock/data/market/overnight_quote_repository.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';

final _now = DateTime.utc(2026, 7, 13, 6, 54);

String _fixture() => File(
  'test/fixtures/provider_v3c/alpaca_latest_quotes.json',
).readAsStringSync();

Quote _regularQuote() => Quote(
  price: 315,
  dayChange: 1,
  dayChangePct: 0.32,
  open: 314,
  high: 316,
  low: 313,
  prevClose: 314,
  volume: 100,
  asOf: _now,
  session: MarketSession.closed,
);

class _FakeClient implements OvernightQuoteClient {
  _FakeClient({this.enabled = true, this.response = const {}});

  bool enabled;
  Map<String, OvernightQuote> response;
  final calls = <List<String>>[];
  Completer<Map<String, OvernightQuote>>? pending;

  @override
  bool get isEnabled => enabled;

  @override
  Future<Map<String, OvernightQuote>> latestQuotes(List<String> symbols) {
    calls.add(List.of(symbols));
    return pending?.future ?? Future.value(response);
  }
}

void main() {
  group('AlpacaOvernightClient', () {
    test(
      'parses one sanitized latest-quotes batch and sends only auth headers',
      () async {
        late http.Request request;
        final client = AlpacaOvernightClient(
          httpClient: MockClient((value) async {
            request = value;
            return http.Response(
              _fixture(),
              200,
              headers: {'x-ratelimit-remaining': '197'},
            );
          }),
          keyId: 'test-key',
          secretKey: 'test-secret',
        );

        final quotes = await client.latestQuotes(['AAPL', 'MSFT']);

        expect(request.url.host, 'data.alpaca.markets');
        expect(request.url.path, '/v2/stocks/quotes/latest');
        expect(request.url.queryParameters, {
          'symbols': 'AAPL,MSFT',
          'feed': 'overnight',
        });
        expect(request.headers['APCA-API-KEY-ID'], 'test-key');
        expect(quotes['AAPL']!.midpoint, closeTo(315.84, 0.000001));
        expect(
          quotes['MSFT']!.timestamp,
          DateTime.parse('2026-07-13T06:53:50.306467Z'),
        );
        expect(client.lastRateLimitRemaining, 197);
      },
    );

    test(
      'missing symbols, malformed JSON, 429, and timeout silently return no values',
      () async {
        final missing = AlpacaOvernightClient(
          httpClient: MockClient(
            (_) async => http.Response('{"quotes": {}}', 200),
          ),
          keyId: 'key',
          secretKey: 'secret',
        );
        final malformed = AlpacaOvernightClient(
          httpClient: MockClient((_) async => http.Response('{not json', 200)),
          keyId: 'key',
          secretKey: 'secret',
        );
        final limited = AlpacaOvernightClient(
          httpClient: MockClient(
            (_) async =>
                http.Response('', 429, headers: {'x-ratelimit-remaining': '0'}),
          ),
          keyId: 'key',
          secretKey: 'secret',
        );
        final timeout = AlpacaOvernightClient(
          httpClient: MockClient((_) => Completer<http.Response>().future),
          keyId: 'key',
          secretKey: 'secret',
          timeout: const Duration(milliseconds: 1),
        );

        expect(await missing.latestQuotes(['AAPL']), isEmpty);
        expect(await malformed.latestQuotes(['AAPL']), isEmpty);
        expect(await limited.latestQuotes(['AAPL']), isEmpty);
        expect(await timeout.latestQuotes(['AAPL']), isEmpty);
        expect(limited.lastRateLimitRemaining, 0);
      },
    );
  });

  group('OvernightQuoteCoordinator', () {
    test(
      'batches the consumer union and unregister affects the next tick',
      () async {
        final client = _FakeClient(
          response: {
            'AAPL': OvernightQuote(midpoint: 315.84, timestamp: _now),
            'MSFT': OvernightQuote(midpoint: 386.42, timestamp: _now),
            'TSLA': OvernightQuote(midpoint: 399.41, timestamp: _now),
          },
        );
        final coordinator = OvernightQuoteCoordinator(
          client: client,
          now: () => _now,
          isInOvernightWindow: (_) => true,
        );
        coordinator.register('watchlist', ['MSFT', 'AAPL']);
        coordinator.register('detail', ['TSLA']);

        final first = await coordinator.tick();
        coordinator.unregister('detail');
        final second = await coordinator.tick();

        expect(client.calls, [
          ['AAPL', 'MSFT', 'TSLA'],
          ['AAPL', 'MSFT'],
        ]);
        expect(first.quotes.keys, containsAll(['AAPL', 'MSFT', 'TSLA']));
        expect(second.quotes.keys, unorderedEquals(['AAPL', 'MSFT']));
        coordinator.dispose();
      },
    );

    test(
      'concurrent ticks share one request and defer registry changes',
      () async {
        final client = _FakeClient()
          ..pending = Completer<Map<String, OvernightQuote>>();
        final coordinator = OvernightQuoteCoordinator(
          client: client,
          now: () => _now,
          isInOvernightWindow: (_) => true,
        );
        coordinator.register('watchlist', ['AAPL']);

        final first = coordinator.tick();
        coordinator.register('detail', ['TSLA']);
        final second = coordinator.tick();
        expect(identical(first, second), isTrue);
        expect(client.calls, [
          ['AAPL'],
        ]);

        client.pending!.complete({
          'AAPL': OvernightQuote(midpoint: 315.84, timestamp: _now),
        });
        await first;
        await coordinator.tick();
        expect(client.calls, [
          ['AAPL'],
          ['AAPL', 'TSLA'],
        ]);
        coordinator.dispose();
      },
    );

    test('no key or outside window performs zero requests', () async {
      final noKey = _FakeClient(enabled: false);
      final outside = _FakeClient();
      final disabledCoordinator = OvernightQuoteCoordinator(
        client: noKey,
        now: () => _now,
        isInOvernightWindow: (_) => true,
      )..register('watchlist', ['AAPL']);
      final outsideCoordinator = OvernightQuoteCoordinator(
        client: outside,
        now: () => _now,
        isInOvernightWindow: (_) => false,
      )..register('watchlist', ['AAPL']);

      expect((await disabledCoordinator.tick()).quotes, isEmpty);
      expect((await outsideCoordinator.tick()).quotes, isEmpty);
      expect(noKey.calls, isEmpty);
      expect(outside.calls, isEmpty);
      disabledCoordinator.dispose();
      outsideCoordinator.dispose();
    });
  });

  group('overnight merge', () {
    test(
      'uses the quote midpoint for the move and leaves the regular price intact',
      () {
        final merged = mergeOvernightQuote(
          _regularQuote(),
          'AAPL',
          OvernightSnapshot(
            quotes: {'AAPL': OvernightQuote(midpoint: 315.84, timestamp: _now)},
            fetchedAt: _now,
          ),
          now: _now,
        );

        expect(merged.price, 315);
        expect(merged.session, MarketSession.overnight);
        expect(merged.extChangePct, closeTo(0.2666667, 0.000001));
      },
    );

    test(
      'stale, absent, and failed snapshots preserve the underlying quote',
      () {
        final quote = _regularQuote();
        final stale = OvernightSnapshot(
          quotes: {
            'AAPL': OvernightQuote(
              midpoint: 315.84,
              timestamp: _now.subtract(
                overnightQuoteMaxAge + const Duration(seconds: 1),
              ),
            ),
          },
          fetchedAt: _now,
        );

        expect(mergeOvernightQuote(quote, 'AAPL', stale, now: _now), quote);
        expect(
          mergeOvernightQuote(
            quote,
            'MSFT',
            OvernightSnapshot.empty(_now),
            now: _now,
          ),
          quote,
        );
      },
    );
  });
}
