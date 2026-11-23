import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Grafik garis mini (tanpa sumbu), untuk kartu sensor.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 32,
    this.minSpan = 1,
  });

  final List<double> values;
  final Color color;
  final double height;

  /// Rentang minimum yang digambar, supaya noise kecil tidak terlihat
  /// seperti lonjakan besar.
  final double minSpan;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: color, minSpan: minSpan),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.minSpan,
  });

  final List<double> values;
  final Color color;
  final double minSpan;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    double lo = values.reduce(math.min);
    double hi = values.reduce(math.max);
    double span = hi - lo;
    if (span < minSpan) {
      final double mid = (hi + lo) / 2;
      lo = mid - minSpan / 2;
      hi = mid + minSpan / 2;
      span = minSpan;
    }

    final double top = size.height * 0.12;
    final double h = size.height * 0.76;
    final double dx = size.width / (values.length - 1);

    Offset point(int i) =>
        Offset(i * dx, top + h - ((values[i] - lo) / span) * h);

    final Path line = Path()..moveTo(point(0).dx, point(0).dy);
    for (int i = 1; i < values.length; i++) {
      final Offset prev = point(i - 1);
      final Offset cur = point(i);
      final double midX = (prev.dx + cur.dx) / 2;
      line.cubicTo(midX, prev.dy, midX, cur.dy, cur.dx, cur.dy);
    }

    final Path fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    final Offset last = point(values.length - 1);
    canvas.drawCircle(last, 3.2, Paint()..color = Colors.white);
    canvas.drawCircle(
      last,
      3.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}