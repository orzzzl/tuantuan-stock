import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuantuan_stock/core/app_lifecycle.dart';

const liveRefreshMaxBackoffInterval = Duration(minutes: 5);

Stream<T> livePollingStream<T>({
  required Ref ref,
  required Future<T> Function() fetch,
  required Duration? Function(T? latestValue) interval,
  T? seed,
  bool emitSeed = false,
  bool fetchImmediately = true,
  List<ProviderListenable<Object?>> rescheduleWhen = const [],
}) {
  late final StreamController<T> controller;
  Timer? timer;
  T? latestValue = seed;
  var hasValue = seed != null;
  var consecutiveFailures = 0;
  var fetching = false;
  var disposed = false;
  var lifecycle = ref.read(appLifecycleStateProvider);

  late void Function({required bool immediate}) schedule;
  late Future<void> Function() runFetch;

  Duration backoff(Duration base) {
    var next = base;
    for (var i = 0; i < consecutiveFailures; i++) {
      next *= 2;
      if (next >= liveRefreshMaxBackoffInterval) {
        return liveRefreshMaxBackoffInterval;
      }
    }
    return next;
  }

  schedule = ({required bool immediate}) {
    timer?.cancel();
    if (disposed || !isLiveRefreshForeground(lifecycle)) return;
    Duration delay;
    if (immediate && !hasValue) {
      delay = Duration.zero;
    } else {
      final base = interval(hasValue ? latestValue : null);
      if (base == null) return;
      delay = immediate
          ? Duration.zero
          : consecutiveFailures == 0
          ? base
          : backoff(base);
    }
    timer = Timer(delay, () {
      unawaited(runFetch());
    });
  };

  runFetch = () async {
    if (disposed || fetching || !isLiveRefreshForeground(lifecycle)) return;
    fetching = true;
    try {
      final value = await fetch();
      if (disposed) return;
      latestValue = value;
      hasValue = true;
      consecutiveFailures = 0;
      controller.add(value);
    } on Object catch (error, stackTrace) {
      if (disposed) return;
      consecutiveFailures += 1;
      if (!hasValue) controller.addError(error, stackTrace);
    } finally {
      fetching = false;
      if (!disposed) schedule(immediate: false);
    }
  };

  ref.listen<AppLifecycleState>(appLifecycleStateProvider, (previous, next) {
    lifecycle = next;
    if (!isLiveRefreshForeground(next)) {
      timer?.cancel();
      return;
    }
    schedule(immediate: true);
  });
  for (final trigger in rescheduleWhen) {
    ref.listen<Object?>(trigger, (previous, next) {
      schedule(immediate: false);
    });
  }

  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
  });

  controller = StreamController<T>(
    onListen: () {
      if (emitSeed && hasValue) controller.add(latestValue as T);
      schedule(immediate: fetchImmediately);
    },
    onCancel: () {
      disposed = true;
      timer?.cancel();
    },
  );
  return controller.stream;
}
