import 'package:flutter/material.dart';

/// Semibold iOS-style disclosure chevron. The stock Cupertino chevron is too
/// light at list-row sizes.
class ChevronIcon extends StatelessWidget {
  const ChevronIcon({super.key, this.size = 14, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size * 0.62,
        height: size,
        child: CustomPaint(painter: _ChevronPainter(color)),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.17;
    canvas.drawPath(
      Path()
        ..moveTo(stroke / 2, stroke / 2)
        ..lineTo(size.width - stroke / 2, size.height / 2)
        ..lineTo(stroke / 2, size.height - stroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}

/// Heavy rounded plus, like a bold SF Symbols "plus".
class PlusIcon extends StatelessWidget {
  const PlusIcon({super.key, this.size = 18, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _PlusPainter(color)),
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  const _PlusPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.19;
    final inset = stroke / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawLine(Offset(inset, size.height / 2),
        Offset(size.width - inset, size.height / 2), paint);
    canvas.drawLine(Offset(size.width / 2, inset),
        Offset(size.width / 2, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}
