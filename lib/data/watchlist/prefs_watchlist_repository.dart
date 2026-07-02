import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuantuan_stock/domain/repositories/watchlist_repository.dart';

/// [WatchlistRepository] backed by shared_preferences: the symbol list is one
/// JSON array on device. Local-first — no account, no network.
class PrefsWatchlistRepository implements WatchlistRepository {
  PrefsWatchlistRepository(this._prefs);

  static const storageKey = 'watchlist.symbols.v1';

  final SharedPreferencesAsync _prefs;
  final _watchers = <MultiStreamController<List<String>>>[];

  /// In-memory truth once loaded; mutations update it synchronously so
  /// watchers reflect a change before the disk write settles.
  List<String>? _symbols;

  /// Chains mutations so concurrent add/remove cannot lose an update.
  Future<void> _writes = Future.value();

  /// The single initial disk read, shared by every concurrent [_load].
  Future<List<String>>? _firstRead;

  @override
  Stream<List<String>> watch() {
    return Stream.multi((controller) async {
      final current = await _load();
      // No await between registering and emitting: a mutation cannot slip
      // in and leave this watcher with a stale first value.
      _watchers.add(controller);
      controller.onCancel = () => _watchers.remove(controller);
      controller.add(current);
    });
  }

  @override
  Future<List<String>> symbols() => _load();

  @override
  Future<void> add(String symbol) {
    return _mutate(
      (symbols) => symbols.contains(symbol) ? null : [...symbols, symbol],
    );
  }

  @override
  Future<void> remove(String symbol) {
    return _mutate(
      (symbols) => symbols.contains(symbol)
          ? symbols.where((s) => s != symbol).toList()
          : null,
    );
  }

  Future<List<String>> _load() async {
    var loaded = _symbols;
    if (loaded == null) {
      final read = await (_firstRead ??= _read());
      // A mutation may have filled _symbols while the read was in flight;
      // that in-memory state is newer than the disk snapshot, so it wins.
      loaded = _symbols ??= read;
    }
    return List.unmodifiable(loaded);
  }

  Future<List<String>> _read() async {
    final raw = await _prefs.getString(storageKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<Object?>).cast<String>();
  }

  /// Applies [change] (null = no-op), notifies watchers, then persists.
  Future<void> _mutate(List<String>? Function(List<String>) change) {
    return _writes = _writes.then((_) async {
      final changed = change(await _load());
      if (changed == null) return;
      _symbols = changed;
      final snapshot = List<String>.unmodifiable(changed);
      for (final watcher in List.of(_watchers)) {
        watcher.add(snapshot);
      }
      await _prefs.setString(storageKey, jsonEncode(changed));
    });
  }
}
