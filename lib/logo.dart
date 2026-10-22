import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Wattly logo: a W inside a usage ring, on an orange rounded square.
/// Drawn in code (same geometry as `branding/icon.svg`) so it stays sharp at
/// any size.
class WattlyLogo extends StatelessWidget {
  const WattlyLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Wattly logo',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: const CustomPaint(painter: _LogoPainter()),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  static const _box = Rect.fromLTWH(0, 0, 256, 256);
  static const _center = Offset(128, 132);
  static const _radius = 84.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 256);

    canvas.drawRRect(
      RRect.fromRectAndRadius(_box, const Radius.circular(58)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB63D), Color(0xFFFF9500)],
        ).createShader(_box),
    );

    // Ring: a faint full track with a 75% progress arc starting at 12 o'clock.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      _center,
      _radius,
      stroke..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawArc(
      Rect.fromCircle(center: _center, radius: _radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      stroke..color = Colors.white,
    );

    canvas.drawPath(
      Path()
        ..moveTo(88, 112)
        ..lineTo(110, 164)
        ..lineTo(128, 130)
        ..lineTo(146, 164)
        ..lineTo(168, 112),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
