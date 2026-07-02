import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tuantuan_stock/app/candy_card.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';

class StockDetailScreen extends StatelessWidget {
  const StockDetailScreen({super.key, required this.symbol});

  static const backButtonKey = Key('detail.backButton');

  final String symbol;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final displaySymbol = symbol.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(localizations.detailTitle(displaySymbol))),
      body: Center(
        child: CandyCard(
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizations.detailPlaceholder(displaySymbol)),
              const SizedBox(height: 16),
              OutlinedButton(
                key: backButtonKey,
                onPressed: () => context.pop(),
                child: Text(localizations.backButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
