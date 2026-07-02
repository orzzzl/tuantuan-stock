import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tuantuan_stock/app/app_router.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  static const detailButtonKey = Key('watchlist.detailButton');
  static const searchButtonKey = Key('watchlist.searchButton');

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.watchlistTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizations.watchlistPlaceholder),
            const SizedBox(height: 16),
            FilledButton(
              key: detailButtonKey,
              onPressed: () => context.push(stockPath(sampleStockSymbol)),
              child: Text(localizations.openDetailButton),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: searchButtonKey,
              onPressed: () => context.push('/search'),
              child: Text(localizations.openSearchButton),
            ),
          ],
        ),
      ),
    );
  }
}
