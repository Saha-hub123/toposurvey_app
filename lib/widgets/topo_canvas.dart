import 'dart:math';
import 'package:flutter/material.dart';
import '../models/anchor_node.dart';
import '../models/survey_point.dart';
import '../services/multilateration_engine.dart';
import '../services/contour_engine.dart';

class TopoCanvas extends StatelessWidget {
  final List<AnchorNode> anchors;
  final List<SurveyPoint> points;
  final MultilaterationResult? liveRover;
  final Map<String, double> liveDistances;
  final bool showContourLines;
  final bool showPoints;
  final bool showPointLabels;
  final double contourInterval;

  const TopoCanvas({
    super.key,
    required this.anchors,
    required this.points,
    this.liveRover,
    this.liveDistances = const {},
    this.showContourLines = true,
    this.showPoints = true,
    this.showPointLabels = true,
    this.contourInterval = 0.5,
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
              showContourLines: showContourLines,
              showPoints: showPoints,
              showPointLabels: showPointLabels,
              contourInterval: contourInterval,
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
  final bool showContourLines;
  final bool showPoints;
  final bool showPointLabels;
  final double contourInterval;

  _TopoPainter({
    required this.anchors,
    required this.points,
    required this.liveRover,
    required this.liveDistances,
    required this.showContourLines,
    required this.showPoints,
    required this.showPointLabels,
    required this.contourInterval,
  });

  Color _getElevationColor(double normalizedZ) {
    // 5-stop topographic color gradient:
    // Cyan (Low / Lembah) -> Green -> Yellow -> Orange -> Deep Orange (High / Puncak)
    final clamped = normalizedZ.clamp(0.0, 1.0);
    if (clamped < 0.25) {
      return Color.lerp(Colors.cyanAccent, Colors.greenAccent, clamped / 0.25)!;
    } else if (clamped < 0.50) {
      return Color.lerp(Colors.greenAccent, Colors.yellowAccent, (clamped - 0.25) / 0.25)!;
    } else if (clamped < 0.75) {
      return Color.lerp(Colors.yellowAccent, Colors.orangeAccent, (clamped - 0.50) / 0.25)!;
    } else {
      return Color.lerp(Colors.orangeAccent, Colors.deepOrangeAccent, (clamped - 0.75) / 0.25)!;
    }
  }

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

    const padding = 38.0;
    final drawW = size.width - (padding * 2);
    final drawH = size.height - (padding * 2);

    final scale = min(drawW / spanX, drawH / spanY);

    Offset worldToScreen(double wx, double wy) {
      final sx = padding + (wx - minX) * scale;
      // Invert Y so Northing goes upwards
      final sy = size.height - padding - (wy - minY) * scale;
      return Offset(sx, sy);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

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
        ..color = Colors.amber.withOpacity(0.22)
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

    // 4. Generate & Draw Contour Lines (Isolines)
    final all3dPoints = <ContourPoint>[];
    for (final a in anchors) {
      all3dPoints.add(ContourPoint(a.x, a.y, a.z));
    }
    for (final p in points) {
      all3dPoints.add(ContourPoint(p.x, p.y, p.z));
    }

    double globalMinZ = 0.0, globalMaxZ = 1.0;
    if (all3dPoints.isNotEmpty) {
      globalMinZ = all3dPoints.map((p) => p.z).reduce(min);
      globalMaxZ = all3dPoints.map((p) => p.z).reduce(max);
      if (globalMaxZ == globalMinZ) globalMaxZ += 1.0;
    }

    if (showContourLines && all3dPoints.length >= 3) {
      final contourResult = ContourEngine.generateContourLines(
        points: all3dPoints,
        interval: contourInterval,
      );

      final contourPaint = Paint()..style = PaintingStyle.stroke;

      // Draw contour line segments
      for (final seg in contourResult.segments) {
        final screenP1 = worldToScreen(seg.p1.dx, seg.p1.dy);
        final screenP2 = worldToScreen(seg.p2.dx, seg.p2.dy);

        final normZ = (seg.elevation - globalMinZ) / (globalMaxZ - globalMinZ);
        final baseColor = _getElevationColor(normZ);

        if (seg.isMajor) {
          contourPaint
            ..color = baseColor.withOpacity(0.95)
            ..strokeWidth = 2.2;
        } else {
          contourPaint
            ..color = baseColor.withOpacity(0.48)
            ..strokeWidth = 1.1;
        }

        canvas.drawLine(screenP1, screenP2, contourPaint);
      }

      // Draw elevation labels along Major Contour Lines
      final labelBgPaint = Paint()
        ..color = const Color(0xFF0F1420).withOpacity(0.85)
        ..style = PaintingStyle.fill;

      final labelBorderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      contourResult.labelPositions.forEach((elevation, positions) {
        final normZ = (elevation - globalMinZ) / (globalMaxZ - globalMinZ);
        final labelColor = _getElevationColor(normZ);

        for (final pos in positions) {
          final screenPos = worldToScreen(pos.dx, pos.dy);

          textPainter.text = TextSpan(
            text: '${elevation.toStringAsFixed(1)}m',
            style: TextStyle(
              color: labelColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          );
          textPainter.layout();

          final rect = Rect.fromCenter(
            center: screenPos,
            width: textPainter.width + 6,
            height: textPainter.height + 4,
          );

          // Draw pill background so text is crystal clear over grid/lines
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            labelBgPaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            labelBorderPaint,
          );

          textPainter.paint(
            canvas,
            Offset(screenPos.dx - textPainter.width / 2, screenPos.dy - textPainter.height / 2),
          );
        }
      });
    }

    // 5. Draw Survey Points (Colored by Elevation Z)
    if (showPoints && points.isNotEmpty) {
      for (final p in points) {
        final screenPos = worldToScreen(p.x, p.y);
        final normalizedZ = ((p.z - globalMinZ) / (globalMaxZ - globalMinZ)).clamp(0.0, 1.0);
        final pointColor = _getElevationColor(normalizedZ);

        final fillPaint = Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill;

        final strokePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        canvas.drawCircle(screenPos, 4.5, fillPaint);
        canvas.drawCircle(screenPos, 4.5, strokePaint);

        if (showPointLabels) {
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
    }

    // 6. Draw Live Rover Position & Trilateration Range Circles
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

    // 7. Draw Anchors (Base Stations)
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
