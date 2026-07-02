import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuantuan_stock/features/chart/plane_rider.dart';

void main() {
  for (final state in PlaneRiderState.values) {
    for (final width in [40.0, 60.0, 80.0]) {
      testWidgets('PlaneRider pumps $state at ${width}px width', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: PlaneRider(state: state, size: width),
            ),
          ),
        );

        final riderFinder = find.byType(PlaneRider);
        final customPaintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is PlaneRiderPainter &&
              (widget.painter! as PlaneRiderPainter).state == state,
        );
        final renderedSize = tester.getSize(riderFinder);

        expect(riderFinder, findsOneWidget);
        expect(customPaintFinder, findsOneWidget);
        expect(renderedSize.width, width);
        expect(
          renderedSize.height,
          closeTo(
            width *
                PlaneRider.logicalSize.height /
                PlaneRider.logicalSize.width,
            0.001,
          ),
        );
      });
    }
  }

  test('face metric stays circular for every state', () {
    expect(PlaneRiderPainter.faceRadius, greaterThan(0));
    expect(PlaneRiderPainter.faceCenter.dx, PlaneRider.logicalSize.width / 2);
  });
}
