import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tuantuan_stock/app/cute_palette.dart';
import 'package:tuantuan_stock/data/market/cn_eastern_time.dart';
import 'package:tuantuan_stock/domain/models/candle.dart';

enum ChartDirection { up, down, flat }

typedef SkyChartAnchorBuilder =
    Widget Function(BuildContext context, Offset tipAnchor);

class DayAxisChartConfig {
  const DayAxisChartConfig({
    required this.now,
    required this.preMarketLabel,
    required this.postMarketLabel,
  });

  static const preMarketStartMinute = 4 * 60;
  static const regularStartMinute = 9 * 60 + 30;
  static const regularEndMinute = 16 * 60;
  static const postMarketEndMinute = 20 * 60;

  static const preMarketWidth = 0.15;
  static const regularWidth = 0.70;
  static const postMarketWidth = 0.15;

  final DateTime now;
  final String preMarketLabel;
  final String postMarketLabel;

  double xForInstant(DateTime instant, Size size) {
    final eastern = utcToEastern(instant);
    return xForEasternMinutes(eastern.hour * 60 + eastern.minute, size);
  }

  static double xForEasternMinutes(num minutes, Size size) {
    final clamped = minutes
        .clamp(preMarketStartMinute, postMarketEndMinute)
        .toDouble();
    final fraction = switch (clamped) {
      <= regularStartMinute =>
        (clamped - preMarketStartMinute) /
            (regularStartMinute - preMarketStartMinute) *
            preMarketWidth,
      <= regularEndMinute =>
        preMarketWidth +
            (clamped - regularStartMinute) /
                (regularEndMinute - regularStartMinute) *
                regularWidth,
      _ =>
        preMarketWidth +
            regularWidth +
            (clamped - regularEndMinute) /
                (postMarketEndMinute - regularEndMinute) *
                postMarketWidth,
    };
    return size.width * fraction;
  }

  List<double> zoneDividers(Size size) => [
    size.width * preMarketWidth,
    size.width * (preMarketWidth + regularWidth),
  ];
}

class SkyChart extends StatelessWidget {
  const SkyChart({
    super.key,
    required this.candles,
    required this.baseline,
    required this.direction,
    this.height = 220,
    this.preMarketCandles = const [],
    this.postMarketCandles = const [],
    this.dayAxis,
    this.anchorBuilder,
    this.nightDressing = false,
  });

  final List<Candle> candles;
  final List<Candle> preMarketCandles;
  final List<Candle> postMarketCandles;
  final double baseline;
  final ChartDirection direction;
  final double height;
  final DayAxisChartConfig? dayAxis;
  final SkyChartAnchorBuilder? anchorBuilder;

  /// Swaps the sky decoration to a moon + stars during the overnight
  /// session (design §4 C2). Decoration only — geometry is unaffected.
  final bool nightDressing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : SkyChartGeometry.fallbackWidth;
          final size = Size(width, height);
          final geometry = SkyChartGeometry.resolve(
            candles: candles,
            preMarketCandles: preMarketCandles,
            postMarketCandles: postMarketCandles,
            baseline: baseline,
            size: size,
            dayAxis: dayAxis,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: SkyChartPainter(
                    candles: candles,
                    preMarketCandles: preMarketCandles,
                    postMarketCandles: postMarketCandles,
                    baseline: baseline,
                    direction: direction,
                    dayAxis: dayAxis,
                    nightDressing: nightDressing,
                  ),
                ),
              ),
              if (anchorBuilder != null)
                anchorBuilder!(context, geometry.tipAnchor),
            ],
          );
        },
      ),
    );
  }
}

class MiniSpark extends StatelessWidget {
  const MiniSpark({
    super.key,
    required this.candles,
    required this.direction,
    this.height = 36,
  });

  final List<Candle> candles;
  final ChartDirection direction;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: MiniSparkPainter(candles: candles, direction: direction),
      ),
    );
  }
}

class SkyChartGeometry {
  const SkyChartGeometry({
    required this.size,
    required this.baselineY,
    required this.maxAbsPercent,
    required this.points,
    required this.zoneDividersX,
    this.tipAnchorOverride,
  });

  static const fallbackWidth = 320.0;
  static const chartPadding = EdgeInsets.fromLTRB(18, 18, 18, 18);
  static const minScalePercent = 0.01;

  final Size size;
  final double baselineY;
  final double maxAbsPercent;
  final List<Offset> points;
  final List<double> zoneDividersX;
  final Offset? tipAnchorOverride;

  Offset get tipAnchor {
    final override = tipAnchorOverride;
    if (override != null) return override;
    if (points.isEmpty) {
      return Offset(size.width / 2, baselineY);
    }

    return points.last;
  }

  static SkyChartGeometry resolve({
    required List<Candle> candles,
    List<Candle> preMarketCandles = const [],
    List<Candle> postMarketCandles = const [],
    required double baseline,
    required Size size,
    DayAxisChartConfig? dayAxis,
  }) {
    if (dayAxis != null) {
      return _resolveDayAxis(
        candles: candles,
        preMarketCandles: preMarketCandles,
        postMarketCandles: postMarketCandles,
        baseline: baseline,
        size: size,
        dayAxis: dayAxis,
      );
    }

    final baselineY = size.height / 2;
    final closes = candles
        .map((candle) => candle.close)
        .where((value) => value.isFinite)
        .toList(growable: false);

    if (closes.isEmpty || !baseline.isFinite || baseline <= 0) {
      return SkyChartGeometry(
        size: size,
        baselineY: baselineY,
        maxAbsPercent: minScalePercent,
        points: const [],
        zoneDividersX: const [],
      );
    }

    final maxAbsPercent = math.max(
      minScalePercent,
      closes
          .map((close) => ((close - baseline) / baseline).abs())
          .fold<double>(0, math.max),
    );
    final left = chartPadding.left;
    final right = math.max(left, size.width - chartPadding.right);
    final width = math.max(0, right - left);
    final topReach = math.max(0, baselineY - chartPadding.top);
    final bottomReach = math.max(
      0,
      size.height - baselineY - chartPadding.bottom,
    );
    final verticalReach = math.min(topReach, bottomReach);
    final step = closes.length <= 1 ? 0 : width / (closes.length - 1);

    final points = <Offset>[
      for (var index = 0; index < closes.length; index += 1)
        Offset(
          closes.length == 1 ? left + width / 2 : left + step * index,
          baselineY -
              ((closes[index] - baseline) / baseline) /
                  maxAbsPercent *
                  verticalReach,
        ),
    ];

    return SkyChartGeometry(
      size: size,
      baselineY: baselineY,
      maxAbsPercent: maxAbsPercent,
      points: points,
      zoneDividersX: const [],
    );
  }

  static SkyChartGeometry _resolveDayAxis({
    required List<Candle> candles,
    required List<Candle> preMarketCandles,
    required List<Candle> postMarketCandles,
    required double baseline,
    required Size size,
    required DayAxisChartConfig dayAxis,
  }) {
    final baselineY = size.height / 2;
    final zoneDividersX = dayAxis.zoneDividers(size);
    final emptyAnchor = Offset(
      dayAxis.xForInstant(dayAxis.now, size),
      baselineY,
    );
    final allCandles = [...preMarketCandles, ...candles, ...postMarketCandles];
    final validCandles = allCandles
        .where((candle) => candle.close.isFinite)
        .toList(growable: false);

    if (validCandles.isEmpty || !baseline.isFinite || baseline <= 0) {
      return SkyChartGeometry(
        size: size,
        baselineY: baselineY,
        maxAbsPercent: minScalePercent,
        points: const [],
        zoneDividersX: zoneDividersX,
        tipAnchorOverride: emptyAnchor,
      );
    }

    final maxAbsPercent = math.max(
      minScalePercent,
      validCandles
          .map((candle) => ((candle.close - baseline) / baseline).abs())
          .fold<double>(0, math.max),
    );
    final topReach = math.max(0, baselineY - chartPadding.top);
    final bottomReach = math.max(
      0,
      size.height - baselineY - chartPadding.bottom,
    );
    final verticalReach = math.min(topReach, bottomReach);
    final points = [
      for (final candle in validCandles)
        Offset(
          dayAxis.xForInstant(candle.time, size),
          baselineY -
              ((candle.close - baseline) / baseline) /
                  maxAbsPercent *
                  verticalReach,
        ),
    ]..sort((a, b) => a.dx.compareTo(b.dx));

    return SkyChartGeometry(
      size: size,
      baselineY: baselineY,
      maxAbsPercent: maxAbsPercent,
      points: points,
      zoneDividersX: zoneDividersX,
    );
  }
}

class SkyChartPainter extends CustomPainter {
  const SkyChartPainter({
    required this.candles,
    this.preMarketCandles = const [],
    this.postMarketCandles = const [],
    required this.baseline,
    required this.direction,
    this.dayAxis,
    this.nightDressing = false,
  });

  final List<Candle> candles;
  final List<Candle> preMarketCandles;
  final List<Candle> postMarketCandles;
  final double baseline;
  final ChartDirection direction;
  final DayAxisChartConfig? dayAxis;
  final bool nightDressing;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = SkyChartGeometry.resolve(
      candles: candles,
      preMarketCandles: preMarketCandles,
      postMarketCandles: postMarketCandles,
      baseline: baseline,
      size: size,
      dayAxis: dayAxis,
    );
    final clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );

    canvas.save();
    canvas.clipRRect(clip);
    _drawBackdrop(canvas, size, geometry.baselineY);
    _drawSky(canvas, size, geometry.baselineY);
    _drawWater(canvas, size, geometry.baselineY);
    _drawBaseline(canvas, size, geometry.baselineY);
    if (dayAxis case final dayAxis?) {
      _drawDayAxisZones(canvas, size, geometry, dayAxis);
    }

    if (geometry.points.length >= 2) {
      _drawGainFill(canvas, size, geometry);
      _drawLine(canvas, size, geometry);
      _drawNodes(canvas, geometry.points);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(SkyChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.preMarketCandles != preMarketCandles ||
        oldDelegate.postMarketCandles != postMarketCandles ||
        oldDelegate.baseline != baseline ||
        oldDelegate.direction != direction ||
        oldDelegate.dayAxis != dayAxis ||
        oldDelegate.nightDressing != nightDressing;
  }

  void _drawDayAxisZones(
    Canvas canvas,
    Size size,
    SkyChartGeometry geometry,
    DayAxisChartConfig dayAxis,
  ) {
    final dividerPaint = Paint()
      ..color = CuteColors.borderSoft
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final x in geometry.zoneDividersX) {
      canvas.drawLine(
        Offset(x, SkyChartGeometry.chartPadding.top / 2),
        Offset(x, size.height - SkyChartGeometry.chartPadding.bottom / 2),
        dividerPaint,
      );
    }

    _drawZoneLabel(
      canvas,
      size,
      dayAxis.preMarketLabel,
      size.width * DayAxisChartConfig.preMarketWidth / 2,
    );
    _drawZoneLabel(
      canvas,
      size,
      dayAxis.postMarketLabel,
      size.width *
          (DayAxisChartConfig.preMarketWidth +
              DayAxisChartConfig.regularWidth +
              DayAxisChartConfig.postMarketWidth / 2),
    );
  }

  void _drawZoneLabel(Canvas canvas, Size size, String label, double centerX) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: CuteColors.textSubtle,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(0, size.width));
    final dx = (centerX - painter.width / 2)
        .clamp(4.0, math.max(4.0, size.width - painter.width - 4))
        .toDouble();
    painter.paint(canvas, Offset(dx, 10));
  }

  void _drawBackdrop(Canvas canvas, Size size, double baselineY) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = CuteColors.surface)
      ..drawRect(
        Rect.fromLTWH(0, baselineY, size.width, size.height - baselineY),
        Paint()..color = CuteColors.water,
      );
  }

  void _drawSky(Canvas canvas, Size size, double baselineY) {
    final gridPaint = Paint()
      ..color = CuteColors.gridWarm
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final y in [baselineY * 0.34, baselineY * 0.67]) {
      _drawDottedLine(
        canvas,
        Offset(SkyChartGeometry.chartPadding.left, y),
        Offset(size.width - SkyChartGeometry.chartPadding.right, y),
        gridPaint,
      );
    }

    if (nightDressing) {
      _drawMoon(canvas, Offset(size.width - 48, 38));
      _drawStars(canvas, size);
      return;
    }

    switch (direction) {
      case ChartDirection.up:
        _drawSun(canvas, Offset(size.width - 48, 38));
        _drawCloud(canvas, Offset(54, 48), CuteColors.cloud);
      case ChartDirection.down:
        _drawRainCloud(canvas, Offset(size.width - 58, 46));
      case ChartDirection.flat:
        _drawCloud(canvas, Offset(size.width - 54, 42), CuteColors.cloud);
        _drawCloud(canvas, const Offset(58, 56), CuteColors.peachSurface);
    }
  }

  void _drawWater(Canvas canvas, Size size, double baselineY) {
    final wavePaint = Paint()
      ..color = CuteColors.waterRipple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var x = 26.0; x < size.width; x += 54) {
      canvas.drawArc(
        Rect.fromLTWH(x, baselineY + 26, 28, 12),
        math.pi,
        math.pi,
        false,
        wavePaint,
      );
    }

    _drawFish(
      canvas,
      Offset(size.width * 0.24, baselineY + (size.height - baselineY) * 0.58),
    );
  }

  void _drawBaseline(Canvas canvas, Size size, double baselineY) {
    final paint = Paint()
      ..color = CuteColors.waterLine
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    _drawDashedLine(
      canvas,
      Offset(12, baselineY),
      Offset(size.width - 12, baselineY),
      paint,
    );
  }

  void _drawGainFill(Canvas canvas, Size size, SkyChartGeometry geometry) {
    final points = geometry.points;
    final areaPath = Path()..moveTo(points.first.dx, geometry.baselineY);
    for (final point in points) {
      areaPath.lineTo(point.dx, point.dy);
    }
    areaPath
      ..lineTo(points.last.dx, geometry.baselineY)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, geometry.baselineY));
    canvas.drawPath(
      areaPath,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CuteColors.upBackground, CuteColors.surface],
        ).createShader(Rect.fromLTWH(0, 0, size.width, geometry.baselineY)),
    );
    canvas.restore();
  }

  void _drawLine(Canvas canvas, Size size, SkyChartGeometry geometry) {
    final path = Path()
      ..moveTo(geometry.points.first.dx, geometry.points.first.dy);
    for (final point in geometry.points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final shadowPaint = Paint()
      ..color = switch (direction) {
        ChartDirection.up => CuteColors.upLineShadow,
        ChartDirection.down => CuteColors.downLineShadow,
        ChartDirection.flat => CuteColors.shadowPeachSoft,
      }
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path.shift(const Offset(0, 5)), shadowPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = _lineGradient().createShader(Offset.zero & size);
    canvas.drawPath(path, linePaint);
  }

  void _drawNodes(Canvas canvas, List<Offset> points) {
    final fill = Paint()..color = CuteColors.card;
    final stroke = Paint()
      ..color = switch (direction) {
        ChartDirection.up => CuteColors.upNodeStrong,
        ChartDirection.down => CuteColors.downNodeStrong,
        ChartDirection.flat => CuteColors.peachDeep,
      }
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final point in _sampledPoints(points)) {
      canvas
        ..drawCircle(point, 6, fill)
        ..drawCircle(point, 6, stroke);
    }
  }

  LinearGradient _lineGradient() {
    return switch (direction) {
      ChartDirection.up => const LinearGradient(
        colors: [CuteColors.matchaLight, CuteColors.matchaEnd],
      ),
      ChartDirection.down => const LinearGradient(
        colors: [CuteColors.downLight, CuteColors.down],
      ),
      ChartDirection.flat => const LinearGradient(
        colors: [CuteColors.peach, CuteColors.peachDeep],
      ),
    };
  }

  Iterable<Offset> _sampledPoints(List<Offset> points) {
    if (points.length <= 5) {
      return points;
    }

    final last = points.length - 1;
    final indexes = <int>{
      0,
      (last * 0.25).round(),
      (last * 0.5).round(),
      (last * 0.75).round(),
      last,
    };
    return indexes.map((index) => points[index]);
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    for (var x = start.dx; x <= end.dx; x += 12) {
      canvas.drawCircle(Offset(x, start.dy), 1.8, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    for (var x = start.dx; x < end.dx; x += 14) {
      canvas.drawLine(
        Offset(x, start.dy),
        Offset(math.min(x + 8, end.dx), end.dy),
        paint,
      );
    }
  }

  void _drawSun(Canvas canvas, Offset center) {
    final rayPaint = Paint()
      ..color = CuteColors.sunRay
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 8; index += 1) {
      final angle = index * math.pi / 4;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * 14,
        center + Offset(math.cos(angle), math.sin(angle)) * 20,
        rayPaint,
      );
    }
    canvas
      ..drawCircle(center, 11, Paint()..color = CuteColors.sun)
      ..drawCircle(
        center,
        11,
        Paint()
          ..color = CuteColors.sunStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  void _drawMoon(Canvas canvas, Offset center) {
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: 12)),
      Path()..addOval(
        Rect.fromCircle(center: center + const Offset(-7, -4), radius: 10),
      ),
    );
    canvas
      ..drawPath(crescent, Paint()..color = CuteColors.sun)
      ..drawPath(
        crescent,
        Paint()
          ..color = CuteColors.sunStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CuteColors.sunRay
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    for (final (center, radius) in [
      (const Offset(52, 42), 4.0),
      (const Offset(88, 26), 2.6),
      (Offset(size.width - 92, 52), 3.2),
    ]) {
      canvas
        ..drawLine(
          center + Offset(0, -radius),
          center + Offset(0, radius),
          paint,
        )
        ..drawLine(
          center + Offset(-radius, 0),
          center + Offset(radius, 0),
          paint,
        );
    }
  }

  void _drawCloud(Canvas canvas, Offset center, Color color) {
    final paint = Paint()..color = color;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center + const Offset(0, 7),
            width: 48,
            height: 20,
          ),
          const Radius.circular(12),
        ),
        paint,
      )
      ..drawCircle(center + const Offset(-16, 3), 11, paint)
      ..drawCircle(center + const Offset(0, -3), 15, paint)
      ..drawCircle(center + const Offset(17, 5), 10, paint);
  }

  void _drawRainCloud(Canvas canvas, Offset center) {
    _drawCloud(canvas, center, CuteColors.rainyCloud);
    final stroke = Paint()
      ..color = CuteColors.rainyCloudStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(0, 7),
          width: 50,
          height: 22,
        ),
        const Radius.circular(12),
      ),
      stroke,
    );

    final dropPaint = Paint()
      ..color = CuteColors.rainyDrop
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final offset in const [
      Offset(-16, 26),
      Offset(0, 31),
      Offset(16, 26),
    ]) {
      canvas.drawLine(
        center + offset,
        center + offset + const Offset(-3, 8),
        dropPaint,
      );
    }
  }

  void _drawFish(Canvas canvas, Offset center) {
    final bodyPaint = Paint()..color = CuteColors.peach;
    final tailPaint = Paint()..color = CuteColors.peachDeep;
    final strokePaint = Paint()
      ..color = CuteColors.peachShadow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final body = Rect.fromCenter(center: center, width: 22, height: 12);
    final tail = Path()
      ..moveTo(center.dx - 11, center.dy)
      ..lineTo(center.dx - 22, center.dy - 7)
      ..lineTo(center.dx - 22, center.dy + 7)
      ..close();

    canvas
      ..drawPath(tail, tailPaint)
      ..drawOval(body, bodyPaint)
      ..drawPath(tail, strokePaint)
      ..drawOval(body, strokePaint)
      ..drawCircle(
        center + const Offset(6, -2),
        1.4,
        Paint()..color = CuteColors.text,
      );
  }
}

class MiniSparkPainter extends CustomPainter {
  const MiniSparkPainter({required this.candles, required this.direction});

  final List<Candle> candles;
  final ChartDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final points = _points(size);
    if (points.length < 2) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final shadowPaint = Paint()
      ..color = switch (direction) {
        ChartDirection.up => CuteColors.upLineShadow,
        ChartDirection.down => CuteColors.downLineShadow,
        ChartDirection.flat => CuteColors.shadowPeachSoft,
      }
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = _lineGradient().createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(MiniSparkPainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.direction != direction;
  }

  List<Offset> _points(Size size) {
    final closes = candles
        .map((candle) => candle.close)
        .where((value) => value.isFinite)
        .toList(growable: false);
    if (closes.isEmpty) {
      return const [];
    }

    final minClose = closes.reduce(math.min);
    final maxClose = closes.reduce(math.max);
    final span = math.max(
      maxClose - minClose,
      SkyChartGeometry.minScalePercent,
    );
    final left = 2.0;
    final right = math.max(left, size.width - 2);
    final width = right - left;
    final step = closes.length <= 1 ? 0 : width / (closes.length - 1);
    const verticalPadding = 4.0;
    final height = math.max(0, size.height - verticalPadding * 2);

    return [
      for (var index = 0; index < closes.length; index += 1)
        Offset(
          closes.length == 1 ? left + width / 2 : left + step * index,
          verticalPadding + (1 - (closes[index] - minClose) / span) * height,
        ),
    ];
  }

  LinearGradient _lineGradient() {
    return switch (direction) {
      ChartDirection.up => const LinearGradient(
        colors: [CuteColors.matchaLight, CuteColors.matchaEnd],
      ),
      ChartDirection.down => const LinearGradient(
        colors: [CuteColors.downLight, CuteColors.down],
      ),
      ChartDirection.flat => const LinearGradient(
        colors: [CuteColors.peach, CuteColors.peachDeep],
      ),
    };
  }
}
