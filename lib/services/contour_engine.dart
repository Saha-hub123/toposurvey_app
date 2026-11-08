import 'dart:math';
import 'package:flutter/material.dart';

class ContourPoint {
  final double x;
  final double y;
  final double z;

  ContourPoint(this.x, this.y, this.z);
}

class ContourSegment {
  final Offset p1;
  final Offset p2;
  final double elevation;
  final bool isMajor;

  ContourSegment({
    required this.p1,
    required this.p2,
    required this.elevation,
    required this.isMajor,
  });
}

class ContourResult {
  final List<ContourSegment> segments;
  final Map<double, List<Offset>> labelPositions;
  final double minZ;
  final double maxZ;
  final double interval;

  ContourResult({
    required this.segments,
    required this.labelPositions,
    required this.minZ,
    required this.maxZ,
    required this.interval,
  });
}

class ContourEngine {
  /// Generates contour line segments from scattered 3D points using
  /// Inverse Distance Weighting (IDW) surface grid + Marching Squares with linear interpolation.
  static ContourResult generateContourLines({
    required List<ContourPoint> points,
    double interval = 0.5,
    int gridResolution = 45,
  }) {
    if (points.length < 3) {
      return ContourResult(
        segments: [],
        labelPositions: {},
        minZ: 0.0,
        maxZ: 0.0,
        interval: interval,
      );
    }

    double minX = points.first.x, maxX = points.first.x;
    double minY = points.first.y, maxY = points.first.y;
    double minZ = points.first.z, maxZ = points.first.z;

    for (final p in points) {
      minX = min(minX, p.x);
      maxX = max(maxX, p.x);
      minY = min(minY, p.y);
      maxY = max(maxY, p.y);
      minZ = min(minZ, p.z);
      maxZ = max(maxZ, p.z);
    }

    if ((maxZ - minZ).abs() < 1e-4) {
      maxZ = minZ + 1.0;
    }

    // Add 15% margin around the bounding box
    final marginX = max((maxX - minX) * 0.15, 2.0);
    final marginY = max((maxY - minY) * 0.15, 2.0);
    final startX = minX - marginX;
    final endX = maxX + marginX;
    final startY = minY - marginY;
    final endY = maxY + marginY;

    final nx = gridResolution;
    final ny = gridResolution;
    final dx = (endX - startX) / (nx - 1);
    final dy = (endY - startY) / (ny - 1);

    // 1. Compute IDW Grid (Z values at regular grid nodes)
    final grid = List.generate(
      nx,
      (_) => List<double>.filled(ny, 0.0),
    );

    for (int i = 0; i < nx; i++) {
      final gx = startX + i * dx;
      for (int j = 0; j < ny; j++) {
        final gy = startY + j * dy;

        double sumWeights = 0.0;
        double sumWeightedZ = 0.0;
        bool exactMatch = false;

        for (final p in points) {
          final distSq = (gx - p.x) * (gx - p.x) + (gy - p.y) * (gy - p.y);
          if (distSq < 1e-6) {
            grid[i][j] = p.z;
            exactMatch = true;
            break;
          }
          final w = 1.0 / distSq; // IDW power = 2
          sumWeights += w;
          sumWeightedZ += w * p.z;
        }

        if (!exactMatch && sumWeights > 0) {
          grid[i][j] = sumWeightedZ / sumWeights;
        }
      }
    }

    // 2. Determine Contour Levels
    final contourLevels = <double>[];
    final startLevel = (minZ / interval).ceil() * interval;
    for (double level = startLevel; level <= maxZ; level += interval) {
      final roundedLevel = (level * 100).round() / 100.0;
      contourLevels.add(roundedLevel);
    }

    // Major interval is 4x the minor interval (or rounded to 1m/2m)
    final majorInterval = (interval * 4 * 100).round() / 100.0;

    final segments = <ContourSegment>[];
    final labelPositions = <double, List<Offset>>{};

    Offset interpEdge(double x1, double y1, double z1, double x2, double y2, double z2, double targetZ) {
      final t = (z2 == z1) ? 0.5 : ((targetZ - z1) / (z2 - z1)).clamp(0.0, 1.0);
      return Offset(x1 + t * (x2 - x1), y1 + t * (y2 - y1));
    }

    // 3. Marching Squares for each Contour Level
    for (final level in contourLevels) {
      final isMajor = (level / majorInterval - (level / majorInterval).round()).abs() < 1e-4;
      final levelSegments = <ContourSegment>[];

      for (int i = 0; i < nx - 1; i++) {
        final x0 = startX + i * dx;
        final x1 = x0 + dx;

        for (int j = 0; j < ny - 1; j++) {
          final y0 = startY + j * dy;
          final y1 = y0 + dy;

          final zBL = grid[i][j];         // Bottom-Left (0)
          final zBR = grid[i + 1][j];     // Bottom-Right (1)
          final zTR = grid[i + 1][j + 1]; // Top-Right (2)
          final zTL = grid[i][j + 1];     // Top-Left (3)

          int squareIndex = 0;
          if (zBL >= level) squareIndex |= 1;
          if (zBR >= level) squareIndex |= 2;
          if (zTR >= level) squareIndex |= 4;
          if (zTL >= level) squareIndex |= 8;

          if (squareIndex == 0 || squareIndex == 15) continue;

          // Edge points
          // Bottom edge: between BL and BR
          Offset bottom() => interpEdge(x0, y0, zBL, x1, y0, zBR, level);
          // Right edge: between BR and TR
          Offset right() => interpEdge(x1, y0, zBR, x1, y1, zTR, level);
          // Top edge: between TL and TR
          Offset top() => interpEdge(x0, y1, zTL, x1, y1, zTR, level);
          // Left edge: between BL and TL
          Offset left() => interpEdge(x0, y0, zBL, x0, y1, zTL, level);

          void addSeg(Offset pA, Offset pB) {
            levelSegments.add(ContourSegment(
              p1: pA,
              p2: pB,
              elevation: level,
              isMajor: isMajor,
            ));
          }

          switch (squareIndex) {
            case 1:
            case 14:
              addSeg(bottom(), left());
              break;
            case 2:
            case 13:
              addSeg(bottom(), right());
              break;
            case 3:
            case 12:
              addSeg(left(), right());
              break;
            case 4:
            case 11:
              addSeg(top(), right());
              break;
            case 5:
              addSeg(left(), top());
              addSeg(bottom(), right());
              break;
            case 6:
            case 9:
              addSeg(top(), bottom());
              break;
            case 7:
            case 8:
              addSeg(left(), top());
              break;
            case 10:
              addSeg(left(), bottom());
              addSeg(top(), right());
              break;
          }
        }
      }

      segments.addAll(levelSegments);

      // Pick a representative position on the contour line to place elevation text
      if (levelSegments.isNotEmpty) {
        // Pick the midpoint of the middle segment for clean label placement
        final midIndex = levelSegments.length ~/ 2;
        final midSeg = levelSegments[midIndex];
        final labelPos = Offset(
          (midSeg.p1.dx + midSeg.p2.dx) / 2.0,
          (midSeg.p1.dy + midSeg.p2.dy) / 2.0,
        );
        labelPositions.putIfAbsent(level, () => []).add(labelPos);
      }
    }

    return ContourResult(
      segments: segments,
      labelPositions: labelPositions,
      minZ: minZ,
      maxZ: maxZ,
      interval: interval,
    );
  }
}
