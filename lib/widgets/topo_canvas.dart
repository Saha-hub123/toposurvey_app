import 'dart:math';
import 'package:flutter/material.dart';
import '../models/anchor_node.dart';
import '../models/survey_point.dart';
import '../services/multilateration_engine.dart';

class TopoCanvas extends StatelessWidget {
  final List<AnchorNode> anchors;
  final List<SurveyPoint> points;
  final MultilaterationResult? liveRover;
  final Map<String, double> liveDistances;

  const TopoCanvas({
    super.key,
    required this.anchors,
    required this.points,
    this.liveRover,
    this.liveDistances = const {},
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _TopoPainter(
              anchors: anchors,
              points: points,
              liveRover: liveRover,
              liveDistances: liveDistances,
            ),
          ),
        );
      },
    );
  }
}

class _TopoPainter extends CustomPainter {
  final List<AnchorNode> anchors;
  final List<SurveyPoint> points;
  final MultilaterationResult? liveRover;
  final Map<String, double> liveDistances;

  _TopoPainter({
    required this.anchors,
    required this.points,
    required this.liveRover,
    required this.liveDistances,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Determine bounding box of all anchors and points to auto-scale
    double minX = -2.0, maxX = 20.0;
    double minY = -2.0, maxY = 20.0;

    for (final a in anchors) {
      minX = min(minX, a.x - 3.0);
      maxX = max(maxX, a.x + 3.0);
      minY = min(minY, a.y - 3.0);
      maxY = max(maxY, a.y + 3.0);
    }

    for (final p in points) {
      minX = min(minX, p.x - 2.0);
      maxX = max(maxX, p.x + 2.0);
      minY = min(minY, p.y - 2.0);
      maxY = max(maxY, p.y + 2.0);
    }

    if (liveRover != null) {
      minX = min(minX, liveRover!.x - 2.0);
      maxX = max(maxX, liveRover!.x + 2.0);
      minY = min(minY, liveRover!.y - 2.0);
      maxY = max(maxY, liveRover!.y + 2.0);
    }

    final spanX = (maxX - minX).clamp(10.0, 500.0);
    final spanY = (maxY - minY).clamp(10.0, 500.0);

    const padding = 35.0;
    final drawW = size.width - (padding * 2);
    final drawH = size.height - (padding * 2);

    final scale = min(drawW / spanX, drawH / spanY);

    Offset worldToScreen(double wx, double wy) {
      final sx = padding + (wx - minX) * scale;
      // Invert Y so Northing goes upwards
      final sy = size.height - padding - (wy - minY) * scale;
      return Offset(sx, sy);
    }

    // 2. Draw Background Grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1.0;

    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.5;

    // Draw grid lines every 5 meters
    const gridStep = 5.0;
    final startGridX = (minX / gridStep).floor() * gridStep;
    final endGridX = (maxX / gridStep).ceil() * gridStep;
    final startGridY = (minY / gridStep).floor() * gridStep;
    final endGridY = (maxY / gridStep).ceil() * gridStep;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (double gx = startGridX; gx <= endGridX; gx += gridStep) {
      final p1 = worldToScreen(gx, minY);
      final p2 = worldToScreen(gx, maxY);
      canvas.drawLine(p1, p2, gx == 0.0 ? axisPaint : gridPaint);

      textPainter.text = TextSpan(
        text: '${gx.toInt()}m',
        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(p1.dx - 10, size.height - 18));
    }

    for (double gy = startGridY; gy <= endGridY; gy += gridStep) {
      final p1 = worldToScreen(minX, gy);
      final p2 = worldToScreen(maxX, gy);
      canvas.drawLine(p1, p2, gy == 0.0 ? axisPaint : gridPaint);

      textPainter.text = TextSpan(
        text: '${gy.toInt()}m',
        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(6, p1.dy - 6));
    }

    // 3. Draw Anchor Baseline Triangle
    if (anchors.length >= 3) {
      final baseLinePaint = Paint()
        ..color = Colors.amber.withOpacity(0.25)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final path = Path();
      final pA = worldToScreen(anchors[0].x, anchors[0].y);
      path.moveTo(pA.dx, pA.dy);
      for (int i = 1; i < anchors.length; i++) {
        final pt = worldToScreen(anchors[i].x, anchors[i].y);
        path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, baseLinePaint);
    }

    // 4. Draw Survey Points (Colored by Elevation Z)
    if (points.isNotEmpty) {
      double minZ = points.map((p) => p.z).reduce(min);
      double maxZ = points.map((p) => p.z).reduce(max);
      if (maxZ == minZ) maxZ += 1.0;

      for (final p in points) {
        final screenPos = worldToScreen(p.x, p.y);
        final normalizedZ = ((p.z - minZ) / (maxZ - minZ)).clamp(0.0, 1.0);

        // Color ramp: Blue (low) -> Green -> Yellow -> Orange -> Red (high)
        final pointColor = Color.lerp(
          Colors.cyanAccent,
          Colors.deepOrangeAccent,
          normalizedZ,
        )!;

        final fillPaint = Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill;

        final strokePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        canvas.drawCircle(screenPos, 5.0, fillPaint);
        canvas.drawCircle(screenPos, 5.0, strokePaint);

        // Label with Point # and Z
        textPainter.text = TextSpan(
          text: 'P${p.pointNumber}: ${p.z.toStringAsFixed(2)}m',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 3),
            ],
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(screenPos.dx + 7, screenPos.dy - 7));
      }
    }

    // 5. Draw Live Rover Position & Trilateration Range Circles
    if (liveRover != null) {
      final roverPos = worldToScreen(liveRover!.x, liveRover!.y);

      // Distance lines to anchors
      for (final anchor in anchors) {
        final anchorPos = worldToScreen(anchor.x, anchor.y);
        final dist = liveDistances[anchor.id];

        final rayPaint = Paint()
          ..color = Colors.tealAccent.withOpacity(0.4)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

        canvas.drawLine(roverPos, anchorPos, rayPaint);

        // Draw range circle around anchor
        if (dist != null && dist > 0) {
          final rangeCirclePaint = Paint()
            ..color = Colors.tealAccent.withOpacity(0.12)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(anchorPos, dist * scale, rangeCirclePaint);
        }
      }

      // Rover crosshair
      final crossPaint = Paint()
        ..color = Colors.tealAccent
        ..strokeWidth = 2.0;

      canvas.drawLine(
        Offset(roverPos.dx - 12, roverPos.dy),
        Offset(roverPos.dx + 12, roverPos.dy),
        crossPaint,
      );
      canvas.drawLine(
        Offset(roverPos.dx, roverPos.dy - 12),
        Offset(roverPos.dx, roverPos.dy + 12),
        crossPaint,
      );

      final roverCorePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(roverPos, 4.0, roverCorePaint);

      textPainter.text = TextSpan(
        text: 'ROVER (Z: ${liveRover!.z.toStringAsFixed(2)}m)',
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(roverPos.dx + 14, roverPos.dy - 14));
    }

    // 6. Draw Anchors (Base Stations)
    final anchorColors = [
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
    ];

    for (int i = 0; i < anchors.length; i++) {
      final a = anchors[i];
      final pos = worldToScreen(a.x, a.y);
      final color = anchorColors[i % anchorColors.length];

      // Draw Anchor Marker (Triangle)
      final trianglePath = Path();
      const r = 9.0;
      trianglePath.moveTo(pos.dx, pos.dy - r);
      trianglePath.lineTo(pos.dx - r * 0.866, pos.dy + r * 0.5);
      trianglePath.lineTo(pos.dx + r * 0.866, pos.dy + r * 0.5);
      trianglePath.close();

      final triPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final triBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawPath(trianglePath, triPaint);
      canvas.drawPath(trianglePath, triBorder);

      textPainter.text = TextSpan(
        text: '${a.id}\nZ=${a.z.toStringAsFixed(2)}m',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pos.dx - 18, pos.dy + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _TopoPainter oldDelegate) => true;
}
