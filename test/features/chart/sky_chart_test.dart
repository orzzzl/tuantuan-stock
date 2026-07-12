import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/domain/models/candle.dart';
import 'package:tuantuan_stock/features/chart/sky_chart.dart';
import 'package:tuantuan_stock/l10n/generated/app_localizations.dart';

void main() {
  const chartSize = Size(320, 220);
  const baseline = 100.0;

  final cases = <_ChartCase>[
    _ChartCase(
      name: 'up-day',
      closes: [100, 102, 104, 105],
      direction: ChartDirection.up,
      firstPointMatcher: equals(chartSize.height / 2),
      tipMatcher: lessThan(chartSize.height / 2),
    ),
    _ChartCase(
      name: 'down-day',
      closes: [100, 98, 96, 95],
      direction: ChartDirection.down,
      firstPointMatcher: equals(chartSize.height / 2),
      tipMatcher: greaterThan(chartSize.height / 2),
    ),
    _ChartCase(
      name: 'gap-up open',
      closes: [103, 104, 106, 105],
      direction: ChartDirection.up,
      firstPointMatcher: lessThan(chartSize.height / 2),
      tipMatcher: lessThan(chartSize.height / 2),
    ),
    _ChartCase(
      name: 'gap-down open',
      closes: [97, 96, 95, 98],
      direction: ChartDirection.down,
      firstPointMatcher: greaterThan(chartSize.height / 2),
      tipMatcher: greaterThan(chartSize.height / 2),
    ),
  ];

  for (final chartCase in cases) {
    testWidgets('${chartCase.name} keeps the baseline exactly centered', (
      tester,
    ) async {
      final candles = _candles(chartCase.closes);
      final geometry = SkyChartGeometry.resolve(
        candles: candles,
        baseline: baseline,
        size: chartSize,
      );
      Offset? anchor;

      expect(geometry.baselineY, chartSize.height / 2);
      expect(geometry.points.first.dy, chartCase.firstPointMatcher);
      expect(geometry.tipAnchor.dy, chartCase.tipMatcher);

      await tester.pumpWidget(
        _localizedChart(
          SizedBox(
            width: chartSize.width,
            child: SkyChart(
              candles: candles,
              baseline: baseline,
              direction: chartCase.direction,
              height: chartSize.height,
              anchorBuilder: (context, tipAnchor) {
                anchor = tipAnchor;
                return Positioned(
                  left: tipAnchor.dx,
                  top: tipAnchor.dy,
                  child: const SizedBox(
                    key: Key('skyChart.tipAnchor'),
                    width: 1,
                    height: 1,
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(SkyChart), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is SkyChartPainter,
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('skyChart.tipAnchor')), findsOneWidget);
      expect(anchor, geometry.tipAnchor);
    });
  }

  test('1D day axis maps Eastern times into locked zone widths', () {
    const size = Size(100, 100);
    final geometry = SkyChartGeometry.resolve(
      preMarketCandles: [_dayCandle(4, 0, 99)],
      candles: [
        _dayCandle(9, 30, 100),
        _dayCandle(12, 45, 101),
        _dayCandle(16, 0, 102),
      ],
      postMarketCandles: [_dayCandle(20, 0, 103)],
      baseline: baseline,
      size: size,
      dayAxis: _dayAxisAt(12, 45),
    );

    expect(geometry.zoneDividersX, [closeTo(15, 0.001), closeTo(85, 0.001)]);
    expect(geometry.points.map((point) => point.dx), [
      closeTo(0, 0.001),
      closeTo(15, 0.001),
      closeTo(50, 0.001),
      closeTo(85, 0.001),
      closeTo(100, 0.001),
    ]);
  });

  test('empty 1D day axis anchors the plane on the current-time baseline', () {
    const size = Size(100, 100);
    final geometry = SkyChartGeometry.resolve(
      candles: const [],
      baseline: baseline,
      size: size,
      dayAxis: _dayAxisAt(12, 45),
    );

    expect(geometry.points, isEmpty);
    expect(geometry.tipAnchor.dx, closeTo(50, 0.001));
    expect(geometry.tipAnchor.dy, size.height / 2);
  });

  test('default geometry keeps stretch-to-fit behavior for other ranges', () {
    final geometry = SkyChartGeometry.resolve(
      candles: _candles([100, 101, 102]),
      baseline: baseline,
      size: chartSize,
    );

    expect(geometry.zoneDividersX, isEmpty);
    expect(geometry.points.first.dx, SkyChartGeometry.chartPadding.left);
    expect(
      geometry.points.last.dx,
      chartSize.width - SkyChartGeometry.chartPadding.right,
    );
  });

  testWidgets('MiniSpark renders the compact row variant', (tester) async {
    await tester.pumpWidget(
      _localizedChart(
        SizedBox(
          width: 120,
          child: MiniSpark(
            candles: _candles([100, 101, 99, 103]),
            direction: ChartDirection.up,
          ),
        ),
      ),
    );

    expect(find.byType(MiniSpark), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is MiniSparkPainter,
      ),
      findsOneWidget,
    );
  });
}

Widget _localizedChart(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

DayAxisChartConfig _dayAxisAt(int hour, int minute) {
  return DayAxisChartConfig(
    now: easternToUtc(DateTime.utc(2026, 7, 2, hour, minute)),
    preMarketLabel: 'Pre',
    postMarketLabel: 'Post',
  );
}

List<Candle> _candles(List<double> closes) {
  return [
    for (var index = 0; index < closes.length; index += 1)
      Candle(
        time: DateTime.utc(2026, 7, 1, index),
        open: closes[index],
        high: closes[index],
        low: closes[index],
        close: closes[index],
      ),
  ];
}

Candle _dayCandle(int hour, int minute, double close) {
  return Candle(
    time: easternToUtc(DateTime.utc(2026, 7, 2, hour, minute)),
    open: close,
    high: close,
    low: close,
    close: close,
  );
}

class _ChartCase {
  const _ChartCase({
    required this.name,
    required this.closes,
    required this.direction,
    required this.firstPointMatcher,
    required this.tipMatcher,
  });

  final String name;
  final List<double> closes;
  final ChartDirection direction;
  final Matcher firstPointMatcher;
  final Matcher tipMatcher;
}
