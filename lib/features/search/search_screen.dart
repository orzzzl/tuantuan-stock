import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tuantuan_stock/app/candy_card.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  static const backButtonKey = Key('search.backButton');

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.searchTitle)),
      body: Center(
        child: CandyCard(
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizations.searchPlaceholder),
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
