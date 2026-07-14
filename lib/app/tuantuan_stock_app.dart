import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuantuan_stock/app/app_router.dart';
import 'package:tuantuan_stock/app/app_theme.dart';
import 'package:tuantuan_stock/app/cute_background.dart';
import 'package:tuantuan_stock/core/app_lifecycle.dart';
import 'package:tuantuan_stock/data/market/overnight_polling.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';

class TuanTuanStockApp extends ConsumerWidget {
  const TuanTuanStockApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the overnight clock alive for the app's lifetime; the provider's
    // value is void, so this never rebuilds the tree.
    ref.watch(overnightPollingProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      locale: locale,
      theme: buildAppTheme(),
      builder: (context, child) {
        return AppLifecycleReporter(
          child: CuteBackground(child: child ?? const SizedBox.shrink()),
        );
      },
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
