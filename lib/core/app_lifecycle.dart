import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLifecycleStateProvider = StateProvider<AppLifecycleState>(
  (ref) => initialLiveRefreshLifecycleState(),
);

AppLifecycleState initialLiveRefreshLifecycleState() {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.detached
      ? AppLifecycleState.resumed
      : state;
}

bool isLiveRefreshForeground(AppLifecycleState state) {
  return state == AppLifecycleState.resumed;
}

class AppLifecycleReporter extends ConsumerStatefulWidget {
  const AppLifecycleReporter({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleReporter> createState() =>
      _AppLifecycleReporterState();
}

class _AppLifecycleReporterState extends ConsumerState<AppLifecycleReporter>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(appLifecycleStateProvider.notifier).state =
        initialLiveRefreshLifecycleState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleStateProvider.notifier).state = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
