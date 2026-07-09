import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tuantuan_stock/app/cute_palette.dart';
import 'package:tuantuan_stock/data/market/market_providers.dart';
import 'package:tuantuan_stock/data/watchlist/watchlist_providers.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';
import 'package:tuantuan_stock/l10n/localized_sets.dart';

/// A stock plus its resolved row labels: curated trending rows carry
/// hand-written lines, search results derive theirs from the locale rules
/// in [AppLocalizationSets].
typedef _LabeledStock = ({Stock stock, String title, String subtitle});

/// Matches for [query], provider-scoped so rapid re-queries share one fetch.
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<Stock>, String>(
      (ref, query) => ref.watch(searchRepositoryProvider).search(query),
    );

const _debounce = Duration(milliseconds: 350);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static const backButtonKey = Key('search.backButton');
  static const searchFieldKey = Key('search.field');

  static Key toggleKey(String symbol) => Key('search.toggle.$symbol');

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Timer? _debounceTimer;
  String _query = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final watched = (ref.watch(watchlistProvider).valueOrNull ?? const [])
        .toSet();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: SearchScreen.backButtonKey,
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(localizations.searchTitle),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                key: SearchScreen.searchFieldKey,
                autofocus: true,
                onChanged: _onTextChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: localizations.searchHint,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: CuteColors.textDisabled,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _StockList(
                      title: localizations.searchTrendingTitle,
                      rows: _trendingRows(localizations),
                      watched: watched,
                      onToggle: _toggleWatch,
                    )
                  : _ResultsView(
                      query: _query,
                      watched: watched,
                      onToggle: _toggleWatch,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleWatch(Stock stock, bool isWatched) {
    final repository = ref.read(watchlistRepositoryProvider);
    isWatched ? repository.remove(stock.symbol) : repository.add(stock.symbol);
  }
}

/// Curated rows for the empty query; both label lines are hand-localized,
/// and no logos so the ticker-ring shows.
List<_LabeledStock> _trendingRows(AppLocalizations localizations) => [
  (
    stock: Stock(
      symbol: 'META',
      name: localizations.trendingMetaName,
      exchange: 'NMS',
    ),
    title: localizations.trendingMetaName,
    subtitle: localizations.trendingMetaSubtitle,
  ),
  (
    stock: Stock(
      symbol: 'SPY',
      name: localizations.trendingSpyName,
      exchange: 'PCX',
    ),
    title: localizations.trendingSpyName,
    subtitle: localizations.trendingSpySubtitle,
  ),
  (
    stock: Stock(
      symbol: 'AAPL',
      name: localizations.trendingAaplName,
      exchange: 'NMS',
    ),
    title: localizations.trendingAaplName,
    subtitle: localizations.trendingAaplSubtitle,
  ),
  (
    stock: Stock(
      symbol: 'NVDA',
      name: localizations.trendingNvdaName,
      exchange: 'NMS',
    ),
    title: localizations.trendingNvdaName,
    subtitle: localizations.trendingNvdaSubtitle,
  ),
  (
    stock: Stock(
      symbol: 'TSLA',
      name: localizations.trendingTslaName,
      exchange: 'NMS',
    ),
    title: localizations.trendingTslaName,
    subtitle: localizations.trendingTslaSubtitle,
  ),
];

class _ResultsView extends ConsumerWidget {
  const _ResultsView({
    required this.query,
    required this.watched,
    required this.onToggle,
  });

  final String query;
  final Set<String> watched;
  final void Function(Stock stock, bool isWatched) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    return ref
        .watch(searchResultsProvider(query))
        .when(
          loading: () => _StatusMessage(
            message: localizations.searchLoadingLabel,
            showSpinner: true,
          ),
          error: (error, stackTrace) =>
              _StatusMessage(message: localizations.searchErrorLabel),
          data: (stocks) => stocks.isEmpty
              ? _StatusMessage(message: localizations.searchNoResultsLabel)
              : _StockList(
                  title: localizations.searchResultsTitle(query),
                  rows: [
                    for (final stock in stocks)
                      (
                        stock: stock,
                        title: localizations.stockTitle(stock, stock.symbol),
                        subtitle: localizations.stockSubtitle(
                          stock,
                          stock.symbol,
                        ),
                      ),
                  ],
                  watched: watched,
                  onToggle: onToggle,
                ),
        );
  }
}

class _StockList extends StatelessWidget {
  const _StockList({
    required this.title,
    required this.rows,
    required this.watched,
    required this.onToggle,
  });

  final String title;
  final List<_LabeledStock> rows;
  final Set<String> watched;
  final void Function(Stock stock, bool isWatched) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: CuteColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        for (final row in rows)
          _StockRow(
            row: row,
            isWatched: watched.contains(row.stock.symbol),
            isLast: row == rows.last,
            onToggle: onToggle,
          ),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.row,
    required this.isWatched,
    required this.isLast,
    required this.onToggle,
  });

  final _LabeledStock row;
  final bool isWatched;
  final bool isLast;
  final void Function(Stock stock, bool isWatched) onToggle;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final stock = row.stock;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: CuteColors.borderList, width: 2),
              ),
      ),
      child: Row(
        children: [
          _StockAvatar(stock: stock),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: CuteColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  row.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: CuteColors.textFaint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _ExchangeTag(exchange: stock.exchange),
          const SizedBox(width: 6),
          _WatchToggle(
            key: SearchScreen.toggleKey(stock.symbol),
            isWatched: isWatched,
            label: isWatched
                ? localizations.searchRemoveButtonLabel
                : localizations.searchAddButtonLabel,
            onTap: () => onToggle(stock, isWatched),
          ),
        ],
      ),
    );
  }
}

class _StockAvatar extends StatelessWidget {
  const _StockAvatar({required this.stock});

  final Stock stock;

  /// Ring/ink pairs for the no-logo fallback, picked stably per symbol.
  static const _fallbackTints = [
    (CuteColors.upRing, CuteColors.up),
    (CuteColors.peachBorder, CuteColors.peachText),
    (CuteColors.lavenderRing, CuteColors.lavenderText),
    (CuteColors.waterBubbleStroke, CuteColors.blueText),
    (CuteColors.downRing, CuteColors.down),
  ];

  @override
  Widget build(BuildContext context) {
    final logoAsset = stock.logoAsset;
    final tintIndex =
        stock.symbol.codeUnits.fold(0, (sum, unit) => sum + unit) %
        _fallbackTints.length;
    final (ring, ink) = logoAsset == null
        ? _fallbackTints[tintIndex]
        : (CuteColors.borderLogo, CuteColors.text);

    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CuteColors.card,
        border: Border.all(color: ring, width: 2),
      ),
      child: logoAsset == null
          ? _tickerLabel(ink)
          : ClipOval(
              child: Image.asset(
                logoAsset,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _tickerLabel(ink),
              ),
            ),
    );
  }

  Widget _tickerLabel(Color ink) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: FittedBox(
        child: Text(
          stock.symbol,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
      ),
    );
  }
}

class _ExchangeTag extends StatelessWidget {
  const _ExchangeTag({required this.exchange});

  final String exchange;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final label = switch (exchange) {
      'NMS' || 'NGM' || 'NCM' => localizations.exchangeTagNasdaq,
      'NYQ' || 'ASE' || 'PCX' => localizations.exchangeTagNyse,
      'BTS' => localizations.exchangeTagCboe,
      _ => exchange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: CuteColors.peachSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: CuteColors.peachText,
        ),
      ),
    );
  }
}

class _WatchToggle extends StatelessWidget {
  const _WatchToggle({
    super.key,
    required this.isWatched,
    required this.label,
    required this.onTap,
  });

  final bool isWatched;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: isWatched
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: CuteColors.upBackground,
                  border: Border.all(color: CuteColors.upBorder, width: 2),
                )
              : const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: CuteColors.upGradient,
                  boxShadow: [
                    BoxShadow(
                      color: CuteColors.matchaShadow,
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
          child: Icon(
            isWatched ? Icons.check_rounded : Icons.add_rounded,
            size: 18,
            color: isWatched ? CuteColors.upTextAlt : CuteColors.card,
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, this.showSpinner = false});

  final String message;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: CuteColors.matcha,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CuteColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
