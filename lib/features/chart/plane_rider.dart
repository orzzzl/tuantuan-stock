import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tuantuan_stock/app/cute_palette.dart';

enum PlaneRiderState { climbing, diving, underwater }

class PlaneRider extends StatelessWidget {
  const PlaneRider({
    super.key,
    required this.state,
    this.size = 66,
    this.nightcap = false,
  });

  static const logicalSize = Size(66, 48);

  final PlaneRiderState state;
  final double size;

  /// Dresses the mascot with a nightcap during the overnight session
  /// (design §4 C2). Decoration only — pose and layout are unaffected.
  final bool nightcap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * logicalSize.height / logicalSize.width,
      child: CustomPaint(
        painter: PlaneRiderPainter(state: state, nightcap: nightcap),
      ),
    );
  }
}

class PlaneRiderPainter extends CustomPainter {
  const PlaneRiderPainter({required this.state, this.nightcap = false});

  static const logicalSize = PlaneRider.logicalSize;
  static const faceCenter = Offset(33, 16);
  static const faceRadius = 10.2;

  final PlaneRiderState state;
  final bool nightcap;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / logicalSize.width,
      size.height / logicalSize.height,
    );
    final offset = Offset(
      (size.width - logicalSize.width * scale) / 2,
      (size.height - logicalSize.height * scale) / 2,
    );

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    _drawTiltedRider(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlaneRiderPainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.nightcap != nightcap;
  }

  void _drawTiltedRider(Canvas canvas) {
    canvas.save();
    canvas.translate(logicalSize.width / 2, logicalSize.height / 2);
    canvas.rotate(_tiltRadians);
    canvas.translate(-logicalSize.width / 2, -logicalSize.height / 2);

    switch (state) {
      case PlaneRiderState.climbing:
        _drawContrail(canvas);
        _drawSparkle(canvas, const Offset(57, 8));
      case PlaneRiderState.diving:
        _drawWindStreaks(canvas);
      case PlaneRiderState.underwater:
        _drawBubbles(canvas);
    }

    _drawPlane(canvas);
    if (_isPanic) {
      _drawPanicArms(canvas);
    }
    _drawMascot(canvas);
    canvas.restore();
  }

  double get _tiltRadians {
    return switch (state) {
      PlaneRiderState.climbing => -14 * math.pi / 180,
      PlaneRiderState.diving ||
      PlaneRiderState.underwater => 18 * math.pi / 180,
    };
  }

  bool get _isPanic => state != PlaneRiderState.climbing;

  void _drawContrail(Canvas canvas) {
    canvas
      ..drawCircle(
        const Offset(3, 34),
        3.2,
        Paint()..color = CuteColors.borderSoft,
      )
      ..drawCircle(
        const Offset(10, 32),
        2.3,
        Paint()..color = CuteColors.shadowWarm,
      );
  }

  void _drawWindStreaks(Canvas canvas) {
    final paint = Paint()
      ..color = CuteColors.borderSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final shift in const [0.0, 7.0, 14.0]) {
      canvas.drawLine(
        Offset(2 + shift, 29 + shift * 0.25),
        Offset(9 + shift, 25 + shift * 0.25),
        paint,
      );
    }
  }

  void _drawBubbles(Canvas canvas) {
    final fill = Paint()..color = CuteColors.waterBubble;
    final stroke = Paint()
      ..color = CuteColors.waterBubbleStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final bubble in const [
      _Bubble(Offset(44, 8), 2.8),
      _Bubble(Offset(49, 3), 1.9),
      _Bubble(Offset(40, 2), 1.3),
      _Bubble(Offset(4, 24), 2.6),
      _Bubble(Offset(10, 28), 1.7),
    ]) {
      canvas
        ..drawCircle(bubble.center, bubble.radius, fill)
        ..drawCircle(bubble.center, bubble.radius, stroke);
    }
  }

  void _drawPlane(Canvas canvas) {
    final planeFill = switch (state) {
      PlaneRiderState.climbing => CuteColors.peach,
      PlaneRiderState.diving ||
      PlaneRiderState.underwater => CuteColors.downLight,
    };
    final wingFill = switch (state) {
      PlaneRiderState.climbing => CuteColors.peachDeep,
      PlaneRiderState.diving || PlaneRiderState.underwater => CuteColors.down,
    };
    final strokeColor = switch (state) {
      PlaneRiderState.climbing => CuteColors.peachShadow,
      PlaneRiderState.diving ||
      PlaneRiderState.underwater => CuteColors.downShadow,
    };
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final tail = Path()
      ..moveTo(14, 31)
      ..lineTo(17, 19)
      ..lineTo(24, 28)
      ..close();
    final wing = Path()
      ..moveTo(32, 34)
      ..lineTo(24, 44)
      ..quadraticBezierTo(22, 46, 25, 46)
      ..lineTo(38, 40)
      ..close();

    canvas
      ..drawPath(tail, Paint()..color = planeFill)
      ..drawPath(tail, stroke)
      ..drawOval(
        Rect.fromCenter(center: const Offset(35, 33), width: 44, height: 15),
        Paint()..color = planeFill,
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(35, 33), width: 44, height: 15),
        stroke..strokeWidth = 1.8,
      )
      ..drawPath(wing, Paint()..color = wingFill)
      ..drawPath(wing, stroke..strokeWidth = 1.4)
      ..drawCircle(
        const Offset(57, 33),
        2.4,
        Paint()..color = CuteColors.propeller,
      )
      ..drawLine(
        const Offset(57, 25),
        const Offset(57, 41),
        Paint()
          ..color = CuteColors.propeller
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
  }

  void _drawPanicArms(Canvas canvas) {
    final paint = Paint()
      ..color = CuteColors.matchaEnd
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawLine(const Offset(34, 13), const Offset(41, 5), paint)
      ..drawLine(const Offset(32, 13), const Offset(25, 6), paint);
  }

  void _drawMascot(Canvas canvas) {
    if (!nightcap) {
      _drawSprout(canvas);
    }
    canvas
      ..drawCircle(
        faceCenter,
        faceRadius,
        Paint()..color = CuteColors.matchaLight,
      )
      ..drawCircle(
        faceCenter,
        faceRadius,
        Paint()
          ..color = CuteColors.matchaMascotShadow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

    if (nightcap) {
      _drawNightcap(canvas);
    }
    if (_isPanic) {
      _drawPanicFace(canvas);
    } else {
      _drawHappyFace(canvas);
    }
  }

  void _drawNightcap(Canvas canvas) {
    final cap = Path()
      ..moveTo(24.5, 11.5)
      ..quadraticBezierTo(27, 3.5, 34, 3)
      ..quadraticBezierTo(41, 2.8, 45.5, 4.5)
      ..lineTo(41.5, 11)
      ..quadraticBezierTo(33, 7.5, 24.5, 11.5)
      ..close();
    final stroke = Paint()
      ..color = CuteColors.lavenderText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..drawPath(cap, Paint()..color = CuteColors.lavenderRing)
      ..drawPath(cap, stroke);

    final band = Path()
      ..moveTo(24, 12.2)
      ..quadraticBezierTo(33, 7.8, 42.2, 11.6);
    canvas.drawPath(
      band,
      Paint()
        ..color = CuteColors.lavenderBlob
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    canvas
      ..drawCircle(
        const Offset(46.5, 4.5),
        2.6,
        Paint()..color = CuteColors.lavenderBlob,
      )
      ..drawCircle(const Offset(46.5, 4.5), 2.6, stroke..strokeWidth = 1);
  }

  void _drawSprout(Canvas canvas) {
    final paint = Paint()
      ..color = CuteColors.matcha
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (_isPanic) {
      final path = Path()
        ..moveTo(32, 8)
        ..quadraticBezierTo(31, 2, 26, 2);
      canvas.drawPath(path, paint);
      return;
    }

    final path = Path()
      ..moveTo(32, 7)
      ..quadraticBezierTo(35, 3, 38, 6);
    canvas.drawPath(path, paint);
  }

  void _drawHappyFace(Canvas canvas) {
    _drawCheeks(canvas);
    _drawEye(canvas, const Offset(29.8, 15.5), hasHighlight: true);
    _drawEye(canvas, const Offset(36.2, 15.5), hasHighlight: true);

    final smile = Path()
      ..moveTo(30, 18.5)
      ..quadraticBezierTo(33, 22, 36, 18.5);
    canvas.drawPath(
      smile,
      Paint()
        ..color = CuteColors.textDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawPanicFace(Canvas canvas) {
    final browPaint = Paint()
      ..color = CuteColors.textDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(27.2, 12)
          ..quadraticBezierTo(28.8, 10.8, 30.4, 11.8),
        browPaint,
      )
      ..drawPath(
        Path()
          ..moveTo(38.8, 12)
          ..quadraticBezierTo(37.2, 10.8, 35.6, 11.8),
        browPaint,
      );

    _drawEye(canvas, const Offset(29.8, 15.8), radius: 2, hasHighlight: true);
    _drawEye(canvas, const Offset(36.2, 15.8), radius: 2, hasHighlight: true);
    _drawCheeks(canvas);
    canvas
      ..drawOval(
        Rect.fromCenter(center: const Offset(33, 21), width: 4, height: 5.2),
        Paint()..color = CuteColors.textDark,
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(33, 22.2), width: 2.4, height: 2),
        Paint()..color = CuteColors.downNode,
      );
  }

  void _drawEye(
    Canvas canvas,
    Offset center, {
    double radius = 1.8,
    required bool hasHighlight,
  }) {
    canvas.drawCircle(center, radius, Paint()..color = CuteColors.textDark);
    if (hasHighlight) {
      canvas.drawCircle(
        center + Offset(radius * 0.3, -radius * 0.3),
        radius * 0.35,
        Paint()..color = CuteColors.card,
      );
    }
  }

  void _drawCheeks(Canvas canvas) {
    final paint = Paint()..color = CuteColors.cheek;
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: const Offset(28.5, 19.7),
          width: 5,
          height: 3.4,
        ),
        paint,
      )
      ..drawOval(
        Rect.fromCenter(
          center: const Offset(37.5, 19.7),
          width: 5,
          height: 3.4,
        ),
        paint,
      );
  }

  void _drawSparkle(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = CuteColors.sunRay
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawLine(
        center + const Offset(0, -4),
        center + const Offset(0, 4),
        paint,
      )
      ..drawLine(
        center + const Offset(-4, 0),
        center + const Offset(4, 0),
        paint,
      )
      ..drawLine(
        center + const Offset(-2.6, -2.6),
        center + const Offset(2.6, 2.6),
        paint,
      )
      ..drawLine(
        center + const Offset(-2.6, 2.6),
        center + const Offset(2.6, -2.6),
        paint,
      );
  }
}

class _Bubble {
  const _Bubble(this.center, this.radius);

  final Offset center;
  final double radius;
}
