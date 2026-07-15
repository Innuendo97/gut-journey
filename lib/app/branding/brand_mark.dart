import 'package:flutter/material.dart';

/// The Gut Journey mark: a winding "journey route" — a filled start dot, a
/// serpentine path and a destination ring — echoing a gut without being
/// literal. Drawn in code so the same source produces the in-app logo, the
/// launcher icons and the splash (rasterized by
/// `tool/branding/render_brand_assets_test.dart`).
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({required this.stroke});

  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;

    final route = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.105
      ..strokeCap = StrokeCap.round;

    // Three horizontal runs joined by U-turns: a serpentine walked bottom
    // to top, from the origin dot to the destination ring.
    const y1 = 0.755;
    const y2 = 0.54;
    const y3 = 0.325;
    final uTurn = Radius.circular(w * ((y1 - y2) / 2));
    final path = Path()
      ..moveTo(w * 0.34, w * y1)
      ..lineTo(w * 0.68, w * y1)
      ..arcToPoint(Offset(w * 0.68, w * y2), radius: uTurn, clockwise: false)
      ..lineTo(w * 0.32, w * y2)
      ..arcToPoint(Offset(w * 0.32, w * y3), radius: uTurn)
      ..lineTo(w * 0.575, w * y3);

    canvas
      ..drawPath(path, route)
      // Origin: where the journey starts.
      ..drawCircle(
        Offset(w * 0.185, w * y1),
        w * 0.062,
        Paint()..color = stroke,
      )
      // Destination: an open ring, still to be reached.
      ..drawCircle(
        Offset(w * 0.775, w * y3),
        w * 0.088,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.055,
      );
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

/// The mark as a widget, for in-app use (onboarding, about). Defaults to the
/// theme's primary color.
class BrandMark extends StatelessWidget {
  const BrandMark({required this.size, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: BrandMarkPainter(
      stroke: color ?? Theme.of(context).colorScheme.primary,
    ),
  );
}
