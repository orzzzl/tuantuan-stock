import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuantuan_stock/core/live_polling.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';

/// True while [session]'s extended window contains the current ET instant
/// (see [isExtendedSessionWindowNow]).
///
/// Offline refreshes keep serving the last cached quote, so a cached session
/// can outlive its own window with no new emission to rebuild the UI. This
/// provider re-arms a timer for the next minute boundary (window edges are
/// minute-aligned) and invalidates itself there, so watchers re-evaluate an
/// already-rendered tag the moment its window closes.
final extendedSessionWindowProvider = Provider.autoDispose
    .family<bool, MarketSession>((ref, session) {
      final now = ref.watch(liveRefreshClockProvider)();
      final untilNextMinute = Duration(
        milliseconds:
            Duration.millisecondsPerMinute -
            now.millisecondsSinceEpoch % Duration.millisecondsPerMinute,
      );
      final timer = Timer(untilNextMinute, ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      return isExtendedSessionWindowNow(session, now);
    });
