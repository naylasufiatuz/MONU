import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/core/formatters.dart';

class TrendPoint {
  const TrendPoint(this.time, this.value);

  final DateTime time;

  /// null = sensor gagal dibaca (tidak digambar, garis diputus).
  final double? value;
}

/// Grafik garis lengkap: sumbu, garis ambang putus-putus, dan petunjuk nilai
/// saat disentuh/diarahkan. Jeda data yang panjang tidak disambung garis.
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.start,
    required this.end,
    required this.unit,
    required this.decimals,
    required this.minSpan,
    this.color = AppColors.forest,
    this.warningLine,
    this.checkLine,
    this.height = 230,
  });

  final List<TrendPoint> points;
  final DateTime start;
  final DateTime end;
  final String unit;
  final int decimals;
  final double minSpan;
  final Color color;
  final double? warningLine;
  final double? checkLine;
  final double height;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  double? _touchX;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: MouseRegion(
        onHover: (event) => setState(() => _touchX = event.localPosition.dx),
        onExit: (_) => setState(() => _touchX = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => setState(() => _touchX = d.localPosition.dx),
          onHorizontalDragUpdate: (d) =>
              setState(() => _touchX = d.localPosition.dx),
          child: CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              points: widget.points,
              start: widget.start,
              end: widget.end,
              unit: widget.unit,
              decimals: widget.decimals,
              minSpan: widget.minSpan,
              color: widget.color,
              warningLine: widget.warningLine,
              checkLine: widget.checkLine,
              touchX: _touchX,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.start,
    required this.end,
    required this.unit,
    required this.decimals,
    required this.minSpan,
    required this.color,
    required this.warningLine,
    required this.checkLine,
    required this.touchX,
  });

  final List<TrendPoint> points;
  final DateTime start;
  final DateTime end;
  final String unit;
  final int decimals;
  final double minSpan;
  final Color color;
  final double? warningLine;
  final double? checkLine;
  final double? touchX;

  static const double _left = 42;
  static const double _right = 10;
  static const double _top = 12;
  static const double _bottom = 26;

  TextStyle get _small => AppText.caption.copyWith(fontSize: 10);

  TextPainter _tp(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect plot = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final List<TrendPoint> valid =
        points.where((p) => p.value != null).toList();

    // ---- rentang sumbu Y ----
    double lo = double.infinity;
    double hi = -double.infinity;
    for (final TrendPoint p in valid) {
      lo = math.min(lo, p.value!);
      hi = math.max(hi, p.value!);
    }
    for (final double? t in <double?>[warningLine, checkLine]) {
      if (t != null) {
        lo = math.min(lo, t);
        hi = math.max(hi, t);
      }
    }
    if (lo.isInfinite) {
      lo = 0;
      hi = 1;
    }
    double span = hi - lo;
    if (span < minSpan) {
      final double mid = (hi + lo) / 2;
      lo = mid - minSpan / 2;
      hi = mid + minSpan / 2;
      span = minSpan;
    }
    lo -= span * 0.12;
    hi += span * 0.12;
    final double yRange = hi - lo;

    double yOf(double v) => plot.bottom - (v - lo) / yRange * plot.height;

    final int totalMs = math.max(1, end.difference(start).inMilliseconds);
    double xOf(DateTime t) {
      final double f = t.difference(start).inMilliseconds / totalMs;
      return plot.left + f.clamp(0.0, 1.0).toDouble() * plot.width;
    }

    // ---- garis kisi dan label Y ----
    final Paint gridPaint = Paint()
      ..color = AppColors.forest.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final double y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final double v = hi - yRange * i / 4;
      final TextPainter tp = _tp(Fmt.number(v, decimals: decimals), _small);
      tp.paint(canvas, Offset(plot.left - 6 - tp.width, y - tp.height / 2));
    }

    // ---- label waktu (sumbu X) ----
    final bool longRange = end.difference(start) > const Duration(hours: 36);
    String timeLabel(DateTime t) =>
        longRange ? '${t.day}/${t.month}' : Fmt.hourMinute(t);
    final List<DateTime> ticks = <DateTime>[
      start,
      start.add(Duration(milliseconds: totalMs ~/ 2)),
      end,
    ];
    for (int i = 0; i < ticks.length; i++) {
      final TextPainter tp = _tp(timeLabel(ticks[i]), _small);
      double x = xOf(ticks[i]) - tp.width / 2;
      if (i == 0) x = plot.left;
      if (i == 2) x = plot.right - tp.width;
      tp.paint(canvas, Offset(x, plot.bottom + 6));
    }

    if (valid.isEmpty) {
      final TextPainter tp = _tp('Tidak ada data pada rentang ini', _small);
      tp.paint(
        canvas,
        Offset(plot.center.dx - tp.width / 2, plot.center.dy - tp.height / 2),
      );
      return;
    }

    // ---- garis ambang putus-putus ----
    void dashed(double value, Color c, String text) {
      if (value < lo || value > hi) return;
      final double y = yOf(value);
      final Paint p = Paint()
        ..color = c
        ..strokeWidth = 1.4;
      double x = plot.left;
      while (x < plot.right) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 6, plot.right), y), p);
        x += 10;
      }
      final TextPainter tp =
          _tp(text, _small.copyWith(color: c, fontWeight: FontWeight.w600));
      tp.paint(canvas, Offset(plot.right - tp.width - 2, y - tp.height - 1));
    }

    if (warningLine != null) dashed(warningLine!, AppColors.warning, 'Waspada');
    if (checkLine != null) dashed(checkLine!, AppColors.danger, 'Periksa');

    // ---- jeda waktu yang terlalu panjang = garis diputus ----
    double breakMs = double.infinity;
    if (valid.length > 2) {
      final List<int> deltas = <int>[];
      for (int i = 1; i < valid.length; i++) {
        deltas.add(valid[i].time.difference(valid[i - 1].time).inMilliseconds);
      }
      deltas.sort();
      final int median = deltas[deltas.length ~/ 2];
      if (median > 0) breakMs = median * 3.0;
    }

    final List<List<Offset>> segments = <List<Offset>>[];
    List<Offset> current = <Offset>[];
    TrendPoint? prev;
    for (final TrendPoint p in valid) {
      if (prev != null &&
          p.time.difference(prev.time).inMilliseconds > breakMs) {
        segments.add(current);
        current = <Offset>[];
      }
      current.add(Offset(xOf(p.time), yOf(p.value!)));
      prev = p;
    }
    if (current.isNotEmpty) segments.add(current);

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    for (final List<Offset> seg in segments) {
      if (seg.length == 1) {
        canvas.drawCircle(seg.first, 3, Paint()..color = color);
        continue;
      }
      final Path path = Path()..moveTo(seg.first.dx, seg.first.dy);
      for (int i = 1; i < seg.length; i++) {
        path.lineTo(seg[i].dx, seg[i].dy);
      }
      final Path fill = Path.from(path)
        ..lineTo(seg.last.dx, plot.bottom)
        ..lineTo(seg.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(plot),
      );
      canvas.drawPath(path, linePaint);
    }

    // ---- petunjuk nilai saat disentuh ----
    final double? tx = touchX;
    if (tx != null) {
      TrendPoint nearest = valid.first;
      double best = double.infinity;
      for (final TrendPoint p in valid) {
        final double d = (xOf(p.time) - tx).abs();
        if (d < best) {
          best = d;
          nearest = p;
        }
      }
      final Offset o = Offset(xOf(nearest.time), yOf(nearest.value!));

      canvas.drawLine(
        Offset(o.dx, plot.top),
        Offset(o.dx, plot.bottom),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(o, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        o,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = color,
      );

      final String when =
          longRange ? Fmt.dateTime(nearest.time) : Fmt.clock(nearest.time);
      final TextPainter v = _tp(
        '${Fmt.number(nearest.value, decimals: decimals)} $unit',
        AppText.label.copyWith(fontSize: 12),
      );
      final TextPainter t = _tp(when, _small);
      final double w = math.max(v.width, t.width) + 20;
      final double h = v.height + t.height + 14;

      double bx = o.dx - w / 2;
      bx = bx.clamp(plot.left, math.max(plot.left, plot.right - w)).toDouble();
      double by = o.dy - h - 12;
      if (by < 0) by = o.dy + 14;

      final RRect box = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, w, h),
        const Radius.circular(12),
      );
      canvas.drawRRect(box, Paint()..color = Colors.white.withValues(alpha: 0.96));
      canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.4),
      );
      v.paint(canvas, Offset(bx + 10, by + 6));
      t.paint(canvas, Offset(bx + 10, by + 8 + v.height));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}