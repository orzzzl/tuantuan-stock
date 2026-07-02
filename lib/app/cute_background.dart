import 'package:flutter/material.dart';
import 'package:tuantuan_stock/app/cute_palette.dart';

class CuteBackground extends StatelessWidget {
  const CuteBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CuteColors.cream,
        gradient: CuteColors.backdropGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _RadialBlob(
            alignment: Alignment(-0.9, -0.9),
            color: CuteColors.peachBlob,
            sizeFactor: 0.72,
          ),
          const _RadialBlob(
            alignment: Alignment(1, 1),
            color: CuteColors.blobMatcha,
            sizeFactor: 0.82,
          ),
          const _RadialBlob(
            alignment: Alignment(0.78, -0.6),
            color: CuteColors.lavenderBlob,
            sizeFactor: 0.62,
          ),
          child,
        ],
      ),
    );
  }
}

class _RadialBlob extends StatelessWidget {
  const _RadialBlob({
    required this.alignment,
    required this.color,
    required this.sizeFactor,
  });

  final Alignment alignment;
  final Color color;
  final double sizeFactor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.biggest.shortestSide;
        final size = shortestSide * sizeFactor;

        return Align(
          alignment: alignment,
          child: IgnorePointer(
            child: SizedBox.square(
              dimension: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color, color.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
