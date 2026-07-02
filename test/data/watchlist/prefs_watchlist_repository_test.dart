import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tuantuan_stock/data/watchlist/prefs_watchlist_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One in-memory store per test = one simulated device; building a second
  // repository over the same store simulates an app restart.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  PrefsWatchlistRepository repository() =>
      PrefsWatchlistRepository(SharedPreferencesAsync());

  test('first run starts empty', () async {
    expect(await repository().symbols(), isEmpty);
  });

  test('add and remove update the snapshot in order', () async {
    final repo = repository();

    await repo.add('AAPL');
    await repo.add('TSLA');
    await repo.add('NVDA');
    await repo.remove('TSLA');

    expect(await repo.symbols(), ['AAPL', 'NVDA']);
  });

  test('symbols persist across a restart', () async {
    final firstRun = repository();
    await firstRun.add('AAPL');
    await firstRun.add('^GSPC');

    final secondRun = repository();

    expect(await secondRun.symbols(), ['AAPL', '^GSPC']);
  });

  test('duplicate add is a no-op and emits nothing', () async {
    final repo = repository();
    await repo.add('AAPL');
    final emitted = <List<String>>[];
    final sub = repo.watch().listen(emitted.add);
    await pumpEventQueue();

    await repo.add('AAPL');
    await pumpEventQueue();

    expect(await repo.symbols(), ['AAPL']);
    expect(emitted, [
      ['AAPL'],
    ], reason: 'only the initial snapshot, no duplicate-add event');
    await sub.cancel();
  });

  test('removing an unknown symbol is a no-op', () async {
    final repo = repository();
    await repo.add('AAPL');

    await repo.remove('MSFT');

    expect(await repo.symbols(), ['AAPL']);
  });

  test('a watcher gets the current list, then every change', () async {
    final repo = repository();
    await repo.add('AAPL');

    final emitted = <List<String>>[];
    final sub = repo.watch().listen(emitted.add);
    await pumpEventQueue();
    await repo.add('TSLA');
    await repo.remove('AAPL');
    await pumpEventQueue();

    expect(emitted, [
      ['AAPL'],
      ['AAPL', 'TSLA'],
      ['TSLA'],
    ]);
    await sub.cancel();
  });

  test('two watchers both see a change immediately', () async {
    final repo = repository();
    final first = <List<String>>[];
    final second = <List<String>>[];
    final subs = [
      repo.watch().listen(first.add),
      repo.watch().listen(second.add),
    ];
    await pumpEventQueue();

    await repo.add('NVDA');
    await pumpEventQueue();

    expect(first, [
      <String>[],
      ['NVDA'],
    ]);
    expect(second, first);
    for (final sub in subs) {
      await sub.cancel();
    }
  });

  test('concurrent unawaited mutations do not lose updates', () async {
    final repo = repository();

    await Future.wait([
      repo.add('AAPL'),
      repo.add('TSLA'),
      repo.add('AAPL'),
      repo.add('NVDA'),
    ]);

    expect(await repo.symbols(), ['AAPL', 'TSLA', 'NVDA']);
    expect(
      await repository().symbols(),
      ['AAPL', 'TSLA', 'NVDA'],
      reason: 'the persisted copy has all writes too',
    );
  });

  test('the snapshot cannot be mutated by callers', () async {
    final repo = repository();
    await repo.add('AAPL');

    final snapshot = await repo.symbols();

    expect(() => snapshot.add('HACK'), throwsUnsupportedError);
  });
}
