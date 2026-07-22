import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tuantuan_stock/app/app_router.dart';
import 'package:tuantuan_stock/app/candy_card.dart';
import 'package:tuantuan_stock/app/cute_palette.dart';
import 'package:tuantuan_stock/core/live_polling.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/data/watchlist/watchlist_providers.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/features/chart/sky_chart.dart';
import 'package:tuantuan_stock/features/watchlist/watchlist_race_providers.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';
import 'package:tuantuan_stock/l10n/localized_sets.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  static const searchButtonKey = Key('watchlist.searchButton');
  static const sortByChangeKey = Key('watchlist.sort.dayChange');
  static const sortByMarketCapKey = Key('watchlist.sort.marketCap');
  static const sortByYtdKey = Key('watchlist.sort.ytd');
  static const emptySearchButtonKey = Key('watchlist.emptySearchButton');
  static Key rowKey(String symbol) => Key('watchlist.row.$symbol');
  static Key headlineKey(String symbol) => Key('watchlist.headline.$symbol');
  static Key medalKey(String symbol) => Key('watchlist.medal.$symbol');
  static Key sessionTagKey(String symbol) => Key('watchlist.session.$symbol');

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  /// Symbols swiped away but possibly not yet flushed out of the repository
  /// stream — keeps the [Dismissible] out of the tree the frame it is
  /// dismissed. Pruned once the stream catches up; undo re-surfaces the row.
  final _dismissed = <String>{};

  Future<void> _refresh() async {
    ref.invalidate(indexStripQuotesProvider);
    ref.invalidate(watchlistQuotesProvider);
    ref.invalidate(watchlistYtdQuotesProvider);
    ref.invalidate(watchlistStocksProvider);
    ref.invalidate(daySparkProvider);
    try {
      await ref.read(watchlistQuotesProvider.future);
    } on Exception {
      // The error state renders inline; the indicator just needs to settle.
    }
  }

  void _remove(String symbol) {
    final localizations = AppLocalizations.of(context);
    setState(() => _dismissed.add(symbol));
    ref.read(watchlistRepositoryProvider).remove(symbol);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(localizations.removedSnackLabel(symbol)),
          action: SnackBarAction(
            label: localizations.undoRemoveButtonLabel,
            onPressed: () {
              setState(() => _dismissed.remove(symbol));
              ref.read(watchlistRepositoryProvider).add(symbol);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final symbols = ref.watch(watchlistProvider).valueOrNull;
    if (symbols != null) {
      // The repository stream has caught up with anything swiped away; a
      // symbol re-added later must not stay hidden.
      _dismissed.retainAll(symbols);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.brandTitle),
        actions: [
          IconButton(
            key: WatchlistScreen.searchButtonKey,
            tooltip: localizations.searchTitle,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const _IndexStrip(),
            const SizedBox(height: 14),
            if (symbols == null)
              const _CenteredSpinner()
            else if (symbols.isEmpty)
              const _EmptyNudge()
            else
              ..._raceSlivers(localizations),
          ],
        ),
      ),
    );
  }

  List<Widget> _raceSlivers(AppLocalizations localizations) {
    final sort = ref.watch(watchlistSortProvider);
    final board = ref.watch(raceBoardProvider);
    final quoteBatch = ref.watch(watchlistQuotesProvider).valueOrNull;

    return [
      _RaceHeader(
        sort: sort,
        onChanged: (next) =>
            ref.read(watchlistSortProvider.notifier).state = next,
      ),
      if (quoteBatch?.isStale ?? false) ...[
        const SizedBox(height: 8),
        _StaleQuoteCue(fetchedAt: quoteBatch!.fetchedAt),
      ],
      const SizedBox(height: 10),
      ...board.when(
        loading: () => const [_RaceSkeletonList()],
        error: (error, stackTrace) => [
          CandyCard(
            child: Text(
              localizations.watchlistErrorLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CuteColors.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        data: (raceBoard) => [
          for (final entry in raceBoard.entries)
            if (!_dismissed.contains(entry.symbol))
              _RaceRow(entry: entry, sort: sort, onRemove: _remove),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              localizations.watchlistFooterHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CuteColors.textSubtle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ];
  }
}

class _StaleQuoteCue extends StatelessWidget {
  const _StaleQuoteCue({required this.fetchedAt});

  final DateTime fetchedAt;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: CuteColors.cream,
        border: Border.all(color: CuteColors.borderSoft, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        localizations.watchlistStaleAsOfLabel(
          localizations.formatShortDateTime(fetchedAt),
        ),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: CuteColors.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _RaceSkeletonList extends StatelessWidget {
  const _RaceSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _RaceSkeletonRow(),
          ),
      ],
    );
  }
}

class _RaceSkeletonRow extends StatelessWidget {
  const _RaceSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return CandyCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 18,
      shadowOffset: const Offset(0, 3),
      child: const SizedBox(
        height: 40,
        child: Row(
          children: [
            _SkeletonBlock(width: 34, height: 34, radius: 17),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SkeletonBlock(width: 92, height: 10, radius: 999),
                  SizedBox(height: 8),
                  _SkeletonBlock(width: 132, height: 8, radius: 999),
                ],
              ),
            ),
            SizedBox(width: 8),
            _SkeletonBlock(width: 52, height: 24, radius: 999),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkeletonBlock(width: 56, height: 10, radius: 999),
                SizedBox(height: 8),
                _SkeletonBlock(width: 46, height: 14, radius: 999),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CuteColors.cream,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class _IndexStrip extends ConsumerWidget {
  const _IndexStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final quotes = ref.watch(indexStripQuotesProvider).valueOrNull?.quotes;
    final labels = {
      '^GSPC': localizations.indexSp500Label,
      '^IXIC': localizations.indexNasdaqLabel,
      '^DJI': localizations.indexDowLabel,
    };

    return Row(
      children: [
        for (final (i, symbol) in indexStripSymbols.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _IndexChip(label: labels[symbol]!, quote: quotes?[symbol]),
          ),
        ],
      ],
    );
  }
}

class _IndexChip extends StatelessWidget {
  const _IndexChip({required this.label, this.quote});

  final String label;
  final Quote? quote;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final up = (quote?.dayChangePct ?? 0) >= 0;
    final tint = quote == null
        ? CuteColors.surface
        : up
        ? CuteColors.upBackground
        : CuteColors.downBackground;
    final border = quote == null
        ? CuteColors.borderSoft
        : up
        ? CuteColors.upBorder
        : CuteColors.downRing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: border, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: CuteColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quote == null ? '—' : localizations.formatPrice(quote!.price),
            maxLines: 1,
            style: textTheme.titleSmall?.copyWith(
              color: CuteColors.text,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (quote != null)
            Text(
              localizations.formatSignedPercent(quote!.dayChangePct / 100),
              maxLines: 1,
              style: textTheme.bodySmall?.copyWith(
                color: up ? CuteColors.up : CuteColors.down,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _RaceHeader extends StatelessWidget {
  const _RaceHeader({required this.sort, required this.onChanged});

  final WatchlistSort sort;
  final ValueChanged<WatchlistSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // No section title: with the market-cap/YTD sorts the list isn't only
    // today's race, so the chips speak for themselves.
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _SortChip(
          key: WatchlistScreen.sortByChangeKey,
          label: localizations.sortByDayChangeLabel,
          selected: sort == WatchlistSort.dayChange,
          onTap: () => onChanged(WatchlistSort.dayChange),
        ),
        const SizedBox(width: 6),
        _SortChip(
          key: WatchlistScreen.sortByMarketCapKey,
          label: localizations.sortByMarketCapLabel,
          selected: sort == WatchlistSort.marketCap,
          onTap: () => onChanged(WatchlistSort.marketCap),
        ),
        const SizedBox(width: 6),
        _SortChip(
          key: WatchlistScreen.sortByYtdKey,
          label: localizations.sortByYtdLabel,
          selected: sort == WatchlistSort.ytd,
          onTap: () => onChanged(WatchlistSort.ytd),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? CuteColors.peachGradient : null,
          color: selected ? null : CuteColors.surface,
          border: Border.all(
            color: selected ? CuteColors.peachShadow : CuteColors.borderSoft,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: selected ? Colors.white : CuteColors.textMuted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RaceRow extends ConsumerWidget {
  const _RaceRow({
    required this.entry,
    required this.sort,
    required this.onRemove,
  });

  final RaceEntry entry;
  final WatchlistSort sort;
  final void Function(String symbol) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final quote = entry.quote;
    final up = quote.dayChangePct >= 0;
    final subtitle = [
      localizations.stockSubtitle(entry.stock, entry.symbol),
      if (entry.ytdRank != null) localizations.ytdRankLabel(entry.ytdRank!),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('watchlist.dismiss.${entry.symbol}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onRemove(entry.symbol),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: CuteColors.downBackground,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: CuteColors.down,
          ),
        ),
        child: GestureDetector(
          key: WatchlistScreen.rowKey(entry.symbol),
          onTap: () => context.push(stockPath(entry.symbol)),
          child: CandyCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            borderRadius: 18,
            shadowOffset: const Offset(0, 3),
            child: Row(
              children: [
                _BadgedAvatar(entry: entry),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.stockTitle(entry.stock, entry.symbol),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: CuteColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
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
                const SizedBox(width: 8),
                _RowSpark(symbol: entry.symbol, up: up),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // The headline figure follows the active sort: the
                    // market-cap race shows market caps, the others price.
                    Text(
                      sort == WatchlistSort.marketCap
                          ? switch (quote.marketCap) {
                              null => '—',
                              final cap => localizations.formatCompactNumber(
                                cap,
                              ),
                            }
                          : localizations.formatPrice(quote.price),
                      key: WatchlistScreen.headlineKey(entry.symbol),
                      style: textTheme.titleSmall?.copyWith(
                        color: CuteColors.text,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Likewise the pill: the YTD race shows the YTD move.
                    _ChangePill(
                      changePct: sort == WatchlistSort.ytd
                          ? entry.ytdChangePct
                          : quote.dayChangePct,
                    ),
                    if (_extendedTag(
                          localizations,
                          quote,
                          ref.watch(liveRefreshClockProvider),
                        )
                        case final tag?)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          tag,
                          key: WatchlistScreen.sessionTagKey(entry.symbol),
                          style: textTheme.bodySmall?.copyWith(
                            color: CuteColors.lavenderText,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `盘前/盘后/夜盘 ±x.x%` when an extended session is in progress; null
  /// hides the line entirely.
  String? _extendedTag(
    AppLocalizations localizations,
    Quote quote,
    DateTime Function() clock,
  ) {
    final extChangePct = quote.extChangePct;
    if (extChangePct == null) return null;
    final label = switch (quote.session) {
      MarketSession.pre => localizations.preMarketSessionLabel,
      MarketSession.post => localizations.postMarketSessionLabel,
      MarketSession.overnight => localizations.overnightSessionLabel,
      MarketSession.regular || MarketSession.closed => null,
    };
    if (label == null) return null;
    // Offline refreshes keep serving the last cached quote, so a cached
    // session can outlive its own window; only render it while current.
    if (!isExtendedSessionWindowNow(quote.session, clock())) return null;
    return '$label ${localizations.formatSignedPercent(extChangePct / 100)}';
  }
}

class _RowSpark extends ConsumerWidget {
  const _RowSpark({required this.symbol, required this.up});

  final String symbol;
  final bool up;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(daySparkProvider(symbol)).valueOrNull;

    return SizedBox(
      width: 52,
      height: 28,
      child: series == null || series.candles.length < 2
          ? const SizedBox.shrink()
          : MiniSpark(
              candles: series.candles,
              direction: up ? ChartDirection.up : ChartDirection.down,
              height: 28,
            ),
    );
  }
}

class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.changePct});

  /// Percent shown in the pill; null (YTD not resolved yet) renders a muted
  /// placeholder instead of a direction.
  final double? changePct;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final changePct = this.changePct;
    final up = (changePct ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: changePct == null
            ? CuteColors.cream
            : up
            ? CuteColors.upBackground
            : CuteColors.downBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        changePct == null
            ? '—'
            : [
                up ? '▲' : '▼',
                localizations.formatSignedPercent(changePct / 100),
              ].join(' '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: changePct == null
              ? CuteColors.textMuted
              : up
              ? CuteColors.up
              : CuteColors.down,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BadgedAvatar extends StatelessWidget {
  const _BadgedAvatar({required this.entry});

  static const _medals = ['🥇', '🥈', '🥉'];

  final RaceEntry entry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: _StockAvatar(symbol: entry.symbol, stock: entry.stock),
          ),
          Positioned(
            left: -3,
            top: -3,
            child: entry.dayRank <= _medals.length
                ? Text(
                    _medals[entry.dayRank - 1],
                    key: WatchlistScreen.medalKey(entry.symbol),
                    style: const TextStyle(fontSize: 15),
                  )
                : Container(
                    key: WatchlistScreen.medalKey(entry.symbol),
                    width: 17,
                    height: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: CuteColors.cream,
                      border: Border.all(
                        color: CuteColors.borderSoft,
                        width: 1.5,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      entry.dayRank.toString(),
                      style: const TextStyle(
                        color: CuteColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StockAvatar extends StatelessWidget {
  const _StockAvatar({required this.symbol, this.stock});

  /// Ring/ink pairs for the no-logo fallback, picked stably per symbol.
  static const _fallbackTints = [
    (CuteColors.upRing, CuteColors.up),
    (CuteColors.peachBorder, CuteColors.peachText),
    (CuteColors.lavenderRing, CuteColors.lavenderText),
    (CuteColors.waterLine, CuteColors.blueText),
  ];

  final String symbol;
  final Stock? stock;

  @override
  Widget build(BuildContext context) {
    final logoAsset = stock?.logoAsset;
    final tintIndex =
        symbol.codeUnits.fold(0, (sum, unit) => sum + unit) %
        _fallbackTints.length;
    final (ring, ink) = logoAsset == null
        ? _fallbackTints[tintIndex]
        : (CuteColors.borderLogo, CuteColors.text);

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
      ),
      child: logoAsset == null
          ? _tickerLabel(ink)
          : ClipOval(
              child: Image.asset(
                logoAsset,
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _tickerLabel(ink),
              ),
            ),
    );
  }

  Text _tickerLabel(Color ink) => Text(
    symbol.length > 4 ? symbol.substring(0, 4) : symbol,
    style: TextStyle(color: ink, fontSize: 8, fontWeight: FontWeight.w900),
  );
}

class _EmptyNudge extends StatelessWidget {
  const _EmptyNudge();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return CandyCard(
      margin: const EdgeInsets.only(top: 36),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            localizations.emptyWatchlistEmoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          Text(
            localizations.emptyWatchlistTitle,
            style: textTheme.titleMedium?.copyWith(
              color: CuteColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.emptyWatchlistHint,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: CuteColors.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: WatchlistScreen.emptySearchButtonKey,
            onPressed: () => context.push('/search'),
            child: Text(localizations.emptySearchButtonLabel),
          ),
        ],
      ),
    );
  }
}
