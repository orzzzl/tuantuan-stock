import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuantuan_stock/core/live_polling.dart';
import 'package:tuantuan_stock/data/market/alpaca_overnight_client.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/data/market/live_market_refresh.dart';
import 'package:tuantuan_stock/data/market/market_cache_store.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/data/market/overnight_quote_coordinator.dart';
import 'package:tuantuan_stock/data/market/overnight_quote_repository.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';

/// The overnight clock (design §5.3): drives [OvernightQuoteCoordinator.tick]
/// at the locked extended cadence while the ET clock is inside the Blue Ocean
/// window and the app is foregrounded, and sleeps until the next window start
/// otherwise. Its schedule reads the window classifier and app lifecycle
/// only — never `Quote.session` (design §5.2a). Watched once at the app root;
/// consumers read values through the coordinator's snapshot provider.
final overnightPollingProvider = Provider<void>((ref) {
  final coordinator = ref.watch(overnightQuoteCoordinatorProvider);
  final clock = ref.watch(liveRefreshClockProvider);
  final ticks = livePollingStream<OvernightSnapshot>(
    ref: ref,
    fetch: () async {
      final snapshot = await coordinator.tick();
      // Rethrowing the failure here lets livePollingStream count consecutive
      // misses for its backoff; consumers only ever see empty snapshots.
      if (snapshot.failed) throw const OvernightFeedFailure();
      return snapshot;
    },
    interval: (_) =>
        isOvernightSession(clock()) ? extendedSessionRefreshInterval : null,
    nullIntervalDelay: (_) => overnightWindowRefreshDelay(clock()),
  );
  final subscription = ticks.listen(
    (_) {},
    onError: (Object error, StackTrace stackTrace) {},
  );
  ref.onDispose(subscription.cancel);
});

/// Re-applies the overnight merge to the latest batch of [source] whenever a
/// new snapshot lands, so an overnight tick re-renders the already-fetched CN
/// quotes without a CN refetch (design §5.2). Snapshots that change nothing
/// are not re-emitted.
Stream<CachedQuoteBatch> overnightRemergedBatches(
  Ref ref,
  Stream<CachedQuoteBatch> source,
) {
  return _remergedStream(ref, source, (batch, snapshot, now) {
    var changed = false;
    final merged = <String, Quote>{};
    for (final MapEntry(:key, :value) in batch.quotes.entries) {
      final quote = mergeOvernightQuote(value, key, snapshot, now: now);
      changed = changed || !identical(quote, value);
      merged[key] = quote;
    }
    if (!changed) return null;
    return CachedQuoteBatch(
      quotes: merged,
      fetchedAt: batch.fetchedAt,
      isStale: batch.isStale,
    );
  });
}

/// [overnightRemergedBatches] for a single-symbol quote stream.
Stream<Quote> overnightRemergedQuotes(
  Ref ref,
  String symbol,
  Stream<Quote> source,
) {
  return _remergedStream(ref, source, (quote, snapshot, now) {
    final merged = mergeOvernightQuote(quote, symbol, snapshot, now: now);
    return identical(merged, quote) ? null : merged;
  });
}

Stream<T> _remergedStream<T extends Object>(
  Ref ref,
  Stream<T> source,
  T? Function(T latest, OvernightSnapshot snapshot, DateTime now) remerge,
) {
  final controller = StreamController<T>();
  T? latest;

  ref.listen(overnightSnapshotProvider, (previous, next) {
    final current = latest;
    final snapshot = next.valueOrNull;
    if (current == null || snapshot == null || controller.isClosed) return;
    final now = ref.read(liveRefreshClockProvider)();
    final merged = remerge(current, snapshot, now);
    if (merged == null) return;
    latest = merged;
    controller.add(merged);
  });

  final subscription = source.listen(
    (value) {
      latest = value;
      controller.add(value);
    },
    onError: controller.addError,
    onDone: controller.close,
  );
  ref.onDispose(() {
    subscription.cancel();
    if (!controller.isClosed) controller.close();
  });
  return controller.stream;
}
