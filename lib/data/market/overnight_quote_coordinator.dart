import 'dart:async';

import 'package:tuantuan_stock/data/market/alpaca_overnight_client.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';

const overnightQuoteMaxAge = Duration(minutes: 20);

/// Immutable result from one overnight fetch. Quotes omitted from [quotes]
/// have no usable overnight value for this tick.
class OvernightSnapshot {
  OvernightSnapshot({
    required Map<String, OvernightQuote> quotes,
    required this.fetchedAt,
  }) : quotes = Map.unmodifiable(quotes);

  factory OvernightSnapshot.empty(DateTime fetchedAt) =>
      OvernightSnapshot(quotes: const {}, fetchedAt: fetchedAt);

  final Map<String, OvernightQuote> quotes;
  final DateTime fetchedAt;
}

/// Owns the whole-app overnight request path. Consumers only manage their
/// symbols here; task 34 owns the polling/lifecycle clock that calls [tick].
class OvernightQuoteCoordinator {
  OvernightQuoteCoordinator({
    required this.client,
    DateTime Function()? now,
    bool Function(DateTime)? isInOvernightWindow,
  }) : _now = now ?? DateTime.now,
       _isInOvernightWindow = isInOvernightWindow ?? isOvernightSession,
       _snapshot = OvernightSnapshot.empty((now ?? DateTime.now)().toUtc());

  final OvernightQuoteClient client;
  final DateTime Function() _now;
  final bool Function(DateTime) _isInOvernightWindow;
  final _symbolsByConsumer = <Object, Set<String>>{};
  final _snapshots = StreamController<OvernightSnapshot>.broadcast();

  OvernightSnapshot _snapshot;
  Future<OvernightSnapshot>? _inFlight;

  OvernightSnapshot get snapshot => _snapshot;
  Stream<OvernightSnapshot> get snapshots => _snapshots.stream;

  /// Replaces one consumer's requested symbols. Empty input is equivalent to
  /// unregistering that consumer.
  void register(Object consumer, Iterable<String> symbols) {
    final normalized = {
      for (final symbol in symbols)
        if (symbol.trim().isNotEmpty) symbol.trim().toUpperCase(),
    };
    if (normalized.isEmpty) {
      _symbolsByConsumer.remove(consumer);
    } else {
      _symbolsByConsumer[consumer] = normalized;
    }
  }

  void unregister(Object consumer) => _symbolsByConsumer.remove(consumer);

  /// Performs one union-batched tick. Concurrent calls share one Future, so
  /// a registry change during a request can affect only the following tick.
  Future<OvernightSnapshot> tick() {
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<OvernightSnapshot> _fetch() async {
    final fetchedAt = _now().toUtc();
    if (!client.isEnabled || !_isInOvernightWindow(fetchedAt)) {
      return _publish(OvernightSnapshot.empty(fetchedAt));
    }

    final symbols = {
      for (final requested in _symbolsByConsumer.values) ...requested,
    }.toList()..sort();
    if (symbols.isEmpty) return _publish(OvernightSnapshot.empty(fetchedAt));

    try {
      final quotes = await client.latestQuotes(symbols);
      final fresh = {
        for (final MapEntry(:key, :value) in quotes.entries)
          if (symbols.contains(key) &&
              !value.timestamp.toUtc().isBefore(
                fetchedAt.subtract(overnightQuoteMaxAge),
              ))
            key: value,
      };
      return _publish(OvernightSnapshot(quotes: fresh, fetchedAt: fetchedAt));
    } on Object {
      return _publish(OvernightSnapshot.empty(fetchedAt));
    }
  }

  OvernightSnapshot _publish(OvernightSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_snapshots.isClosed) _snapshots.add(snapshot);
    return snapshot;
  }

  void dispose() => _snapshots.close();
}
