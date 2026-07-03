import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tuantuan_stock/app/candy_card.dart';
import 'package:tuantuan_stock/app/cute_palette.dart';
import 'package:tuantuan_stock/data/watchlist/watchlist_providers.dart';
import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/domain/models/chart_range.dart';
import 'package:tuantuan_stock/domain/models/chart_series.dart';
import 'package:tuantuan_stock/domain/models/quote.dart';
import 'package:tuantuan_stock/domain/models/stock.dart';
import 'package:tuantuan_stock/features/chart/plane_rider.dart';
import 'package:tuantuan_stock/features/chart/sky_chart.dart';
import 'package:tuantuan_stock/features/detail/stock_detail_providers.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';
import 'package:tuantuan_stock/l10n/localized_sets.dart';

/// Rider pose from the line tip: below the waterline it drowns (adorably);
/// above it the last segment's slope picks climbing vs diving.
PlaneRiderState riderStateFor(List<Candle> candles, double baseline) {
  final tip = candles.last.close;
  if (tip < baseline) return PlaneRiderState.underwater;
  if (candles.length >= 2 && tip < candles[candles.length - 2].close) {
    return PlaneRiderState.diving;
  }
  return PlaneRiderState.climbing;
}

class StockDetailScreen extends ConsumerStatefulWidget {
  const StockDetailScreen({super.key, required this.symbol});

  static const backButtonKey = Key('detail.backButton');
  static const searchButtonKey = Key('detail.searchButton');
  static const watchToggleKey = Key('detail.watchToggle');
  static const heroKey = Key('detail.hero');
  static Key rangeChipKey(ChartRange range) =>
      Key('detail.range.${range.name}');

  final String symbol;

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  var _range = ChartRange.day;

  String get _symbol => widget.symbol.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final quote = ref.watch(detailQuoteProvider(_symbol));
    final stock = ref.watch(detailStockProvider(_symbol)).valueOrNull;
    final isWatched =
        ref.watch(watchlistProvider).valueOrNull?.contains(_symbol) ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: StockDetailScreen.backButtonKey,
          tooltip: localizations.backButton,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: _Header(symbol: _symbol, stock: stock),
        actions: [
          IconButton(
            key: StockDetailScreen.watchToggleKey,
            tooltip: isWatched
                ? localizations.removeFromWatchlistTooltip
                : localizations.addToWatchlistTooltip,
            icon: Icon(
              isWatched ? Icons.star_rounded : Icons.star_border_rounded,
              color: isWatched ? CuteColors.peach : CuteColors.textMuted,
            ),
            onPressed: () {
              final repository = ref.read(watchlistRepositoryProvider);
              isWatched ? repository.remove(_symbol) : repository.add(_symbol);
            },
          ),
          IconButton(
            key: StockDetailScreen.searchButtonKey,
            tooltip: localizations.searchTitle,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: quote.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: CandyCard(
            margin: const EdgeInsets.all(24),
            child: Text(
              localizations.detailErrorLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CuteColors.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        data: (quote) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _PriceHero(
              quote: quote,
              range: _range,
              series: ref
                  .watch(detailChartProvider((symbol: _symbol, range: _range)))
                  .valueOrNull,
            ),
            const SizedBox(height: 14),
            _RangeChips(
              selected: _range,
              onSelected: (range) => setState(() => _range = range),
            ),
            const SizedBox(height: 10),
            _ChartCard(symbol: _symbol, range: _range),
            const SizedBox(height: 14),
            _StatsGrid(quote: quote),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.symbol, this.stock});

  final String symbol;
  final Stock? stock;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        _LogoAvatar(symbol: symbol, stock: stock),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stock?.name ?? symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: CuteColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                stock?.zhName ?? symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: CuteColors.textFaint,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({required this.symbol, this.stock});

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
    final logoUrl = stock?.logoUrl;
    final tintIndex =
        symbol.codeUnits.fold(0, (sum, unit) => sum + unit) %
        _fallbackTints.length;
    final (ring, ink) = logoUrl == null
        ? _fallbackTints[tintIndex]
        : (CuteColors.borderLogo, CuteColors.text);

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
      ),
      child: logoUrl == null
          ? _tickerLabel(ink)
          : ClipOval(
              child: Image.network(
                logoUrl,
                width: 22,
                height: 22,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _tickerLabel(ink),
              ),
            ),
    );
  }

  Text _tickerLabel(Color ink) => Text(
    symbol.length > 4 ? symbol.substring(0, 4) : symbol,
    style: TextStyle(color: ink, fontSize: 7, fontWeight: FontWeight.w900),
  );
}

class _PriceHero extends StatelessWidget {
  const _PriceHero({required this.quote, required this.range, this.series});

  final Quote quote;
  final ChartRange range;

  /// The selected range's series; null while it loads (the hero then falls
  /// back to today's change rather than showing nothing).
  final ChartSeries? series;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    // Robinhood mode (owner, 2026-07-02): the change line follows the
    // selected range — 1日 shows the official day change, longer ranges show
    // price vs the range baseline with the range's own label.
    final baseline = range == ChartRange.day ? null : series?.baseline;
    final (change, changePct, periodLabel) = baseline == null || baseline == 0
        ? (quote.dayChange, quote.dayChangePct, localizations.todayLabel)
        : (
            quote.price - baseline,
            (quote.price - baseline) / baseline * 100,
            localizations.chartRangeLabels[range.index],
          );
    final up = changePct >= 0;
    final changeLine = [
      up ? '▲' : '▼',
      (up ? '+' : '-') + localizations.formatPrice(change.abs()),
      localizations.formatSignedPercent(changePct / 100),
      periodLabel,
    ].join(' ');
    final extendedTag = _extendedTag(localizations, quote);

    return Container(
      key: StockDetailScreen.heroKey,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        gradient: up ? CuteColors.upGradient : CuteColors.downGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: up ? CuteColors.matchaShadow : CuteColors.downShadow,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.currentPriceLabel,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            localizations.formatPrice(quote.price),
            style: textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  changeLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (extendedTag != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    extendedTag,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// `盘前/盘后 ±x.x%` chip content when an extended session is in progress.
  String? _extendedTag(AppLocalizations localizations, Quote quote) {
    final extChangePct = quote.extChangePct;
    if (extChangePct == null) return null;
    final label = switch (quote.session) {
      MarketSession.pre => localizations.preMarketSessionLabel,
      MarketSession.post => localizations.postMarketSessionLabel,
      MarketSession.regular || MarketSession.closed => null,
    };
    if (label == null) return null;
    return '$label ${localizations.formatSignedPercent(extChangePct / 100)}';
  }
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.selected, required this.onSelected});

  final ChartRange selected;
  final ValueChanged<ChartRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context).chartRangeLabels;

    // Eight ranges don't fit one phone-width row; wrap onto a second one so
    // every chip stays visible.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (i, range) in ChartRange.values.indexed)
          _RangeChip(
            key: StockDetailScreen.rangeChipKey(range),
            label: labels[i],
            selected: range == selected,
            onTap: () => onSelected(range),
          ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
          maxLines: 1,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: selected ? Colors.white : CuteColors.textMuted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends ConsumerWidget {
  const _ChartCard({required this.symbol, required this.range});

  final String symbol;
  final ChartRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final series = ref.watch(
      detailChartProvider((symbol: symbol, range: range)),
    );

    return CandyCard(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 236,
        child: series.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              localizations.chartErrorLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CuteColors.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          data: (series) {
            if (series.candles.length < 2) {
              return Center(
                child: Text(
                  localizations.chartEmptyLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CuteColors.textSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }
            final up = series.candles.last.close >= series.baseline;
            return SkyChart(
              candles: series.candles,
              baseline: series.baseline,
              direction: up ? ChartDirection.up : ChartDirection.down,
              height: 224,
              baselineLabel: range == ChartRange.day ? null : '',
              anchorBuilder: (context, tipAnchor) => Positioned(
                left: tipAnchor.dx - 28,
                top: tipAnchor.dy - 40,
                child: PlaneRider(
                  state: riderStateFor(series.candles, series.baseline),
                  size: 52,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final cells = [
      (
        localizations.statOpenLabel,
        localizations.formatPrice(quote.open),
        CuteColors.text,
      ),
      (
        localizations.statHighLabel,
        localizations.formatPrice(quote.high),
        CuteColors.up,
      ),
      (
        localizations.statLowLabel,
        localizations.formatPrice(quote.low),
        CuteColors.down,
      ),
      (
        localizations.statPrevCloseLabel,
        localizations.formatPrice(quote.prevClose),
        CuteColors.text,
      ),
      (
        localizations.statVolumeLabel,
        localizations.formatCompactNumber(quote.volume),
        CuteColors.text,
      ),
      (
        localizations.statMarketCapLabel,
        switch (quote.marketCap) {
          null => '—',
          final cap => localizations.formatCompactNumber(cap),
        },
        CuteColors.text,
      ),
      (
        localizations.statPeLabel,
        switch (quote.trailingPe) {
          null => '—',
          final pe => localizations.formatPrice(pe),
        },
        CuteColors.text,
      ),
      (
        localizations.statForwardPeLabel,
        switch (quote.forwardPe) {
          null => '—',
          final pe => localizations.formatPrice(pe),
        },
        CuteColors.text,
      ),
    ];

    return Column(
      children: [
        for (var row = 0; row < (cells.length / 3).ceil(); row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var column = 0; column < 3; column++) ...[
                if (column > 0) const SizedBox(width: 8),
                Expanded(
                  child: row * 3 + column < cells.length
                      ? _StatCell(cell: cells[row * 3 + column])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.cell});

  final (String, String, Color) cell;

  @override
  Widget build(BuildContext context) {
    final (label, value, valueColor) = cell;
    final textTheme = Theme.of(context).textTheme;

    return CandyCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: 16,
      shadowOffset: const Offset(0, 3),
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
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
