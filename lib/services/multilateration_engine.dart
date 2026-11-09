import 'dart:math';
import '../models/anchor_node.dart';

class MultilaterationResult {
  final double x;
  final double y;
  final double z;
  final double residualError;
  final bool isAccurate;
  final String methodUsed;
  final int activeAnchorCount;

  MultilaterationResult({
    required this.x,
    required this.y,
    required this.z,
    required this.residualError,
    required this.isAccurate,
    required this.methodUsed,
    this.activeAnchorCount = 3,
  });

  @override
  String toString() =>
      'MultilaterationResult(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)}, error: ${residualError.toStringAsFixed(3)}m, method: $methodUsed, anchors: $activeAnchorCount)';
}

class MultilaterationEngine {
  /// Solves for (x, y, z) using 2 or more anchor nodes with measured distances.
  /// Supports:
  /// - 2 Anchors (Mode 3 HP: 2 Base Patok + 1 HP Rover) using bilateral circle intersection + Barometer Z
  /// - 3 Anchors (Mode 4 HP: 3 Base Patok + 1 HP Rover) using exact 3-point trilateration
  /// - 4+ Anchors using Linear Least Squares + Levenberg-Marquardt Gradient Refinement
  static MultilaterationResult? solve({
    required List<AnchorNode> anchors,
    required Map<String, double> measuredDistances,
    double? differentialElevationZ,
    bool surveySidePositive = true,
  }) {
    // Filter anchors that have a valid measured distance
    final activeAnchors = <AnchorNode>[];
    final activeDistances = <double>[];

    for (final anchor in anchors) {
      final dist = measuredDistances[anchor.id];
      if (dist != null && dist > 0.05 && dist < 500.0) {
        activeAnchors.add(anchor);
        activeDistances.add(dist);
      }
    }

    if (activeAnchors.length < 2) {
      // Minimal butuh 2 anchor (Mode 3 HP) atau 3 anchor (Mode 4 HP)
      return null;
    }

    if (activeAnchors.length == 2) {
      // Dukungan Mode 3 HP: 2 Base Station (A & B) + 1 Rover
      return _solveBilateral2Anchors(
        activeAnchors[0],
        activeDistances[0],
        activeAnchors[1],
        activeDistances[1],
        differentialElevationZ,
        surveySidePositive: surveySidePositive,
      );
    } else if (activeAnchors.length == 3) {
      return _solveExactTrilateration(
        activeAnchors[0],
        activeDistances[0],
        activeAnchors[1],
        activeDistances[1],
        activeAnchors[2],
        activeDistances[2],
        differentialElevationZ,
      );
    } else {
      // Overdetermined system (N >= 4 anchors): Linear Least Squares + Refinement
      return _solveLinearLeastSquares(
        activeAnchors,
        activeDistances,
        differentialElevationZ,
      );
    }
  }

  /// Bilateral 2-Anchor Trilateration for 3-Phone Field Deployment:
  /// (HP 1 = Base A, HP 2 = Base B, HP 3 = Rover)
  /// Fuses baseline intersection with differential barometric altimetry.
  static MultilaterationResult? _solveBilateral2Anchors(
    AnchorNode a1,
    double r1,
    AnchorNode a2,
    double r2,
    double? baroZ, {
    bool surveySidePositive = true,
  }) {
    final x1 = a1.x, y1 = a1.y;
    final x2 = a2.x, y2 = a2.y;

    final dx = x2 - x1;
    final dy = y2 - y1;
    final d = sqrt(dx * dx + dy * dy);

    if (d < 1e-4) {
      // Dua patok berada di titik yang sama
      return null;
    }

    // Vektor satuan sepanjang garis baseline A1 -> A2
    final ux = dx / d;
    final uy = dy / d;

    // Vektor normal tegak lurus garis baseline (90 derajat CCW)
    final vx = -uy;
    final vy = ux;

    // Jarak proyeksi sepanjang baseline dari A1
    // Menggunakan hukum cosinus / perpotongan dua lingkaran:
    // r1^2 - p^2 = r2^2 - (d - p)^2  =>  p = (r1^2 - r2^2 + d^2) / (2*d)
    var p = ((r1 * r1) - (r2 * r2) + (d * d)) / (2.0 * d);

    // Ketinggian tegak lurus dari garis baseline: h^2 = r1^2 - p^2
    final hSq = (r1 * r1) - (p * p);
    double h = 0.0;
    if (hSq > 0) {
      h = sqrt(hSq);
    } else {
      // Lingkaran tidak berpotongan sempurna karena distorsi redaman sinyal RF di lapangan
      // Proyeksikan ke titik terdekat pada garis baseline
      p = p.clamp(0.0, d);
      h = 0.0;
    }

    final sideMultiplier = surveySidePositive ? 1.0 : -1.0;

    final solX = x1 + (p * ux) + (sideMultiplier * h * vx);
    final solY = y1 + (p * uy) + (sideMultiplier * h * vy);
    final solZ = baroZ ?? a1.z;

    // Hitung residual error pada 2 patok
    final distA1 = sqrt(pow(solX - x1, 2) + pow(solY - y1, 2));
    final distA2 = sqrt(pow(solX - x2, 2) + pow(solY - y2, 2));
    final err1 = (distA1 - r1).abs();
    final err2 = (distA2 - r2).abs();
    final residual = sqrt((err1 * err1 + err2 * err2) / 2.0);

    return MultilaterationResult(
      x: solX,
      y: solY,
      z: solZ,
      residualError: residual,
      isAccurate: residual < 3.5,
      methodUsed: 'Trilaterasi 2-Base (Mode 3 HP) + Baro Altimetri',
      activeAnchorCount: 2,
    );
  }

  /// Exact 2D/2.5D Trilateration for 3 Anchors
  static MultilaterationResult? _solveExactTrilateration(
    AnchorNode a1,
    double r1,
    AnchorNode a2,
    double r2,
    AnchorNode a3,
    double r3,
    double? baroZ,
  ) {
    final x1 = a1.x, y1 = a1.y;
    final x2 = a2.x, y2 = a2.y;
    final x3 = a3.x, y3 = a3.y;

    // Linearization relative to Anchor 1:
    // 2*(x2 - x1)*x + 2*(y2 - y1)*y = r1^2 - r2^2 - (x1^2 - x2^2) - (y1^2 - y2^2)
    // 2*(x3 - x1)*x + 2*(y3 - y1)*y = r1^2 - r3^2 - (x1^2 - x3^2) - (y1^2 - y3^2)
    final a = 2 * (x2 - x1);
    final b = 2 * (y2 - y1);
    final c = (r1 * r1) - (r2 * r2) - (x1 * x1 - x2 * x2) - (y1 * y1 - y2 * y2);

    final d = 2 * (x3 - x1);
    final e = 2 * (y3 - y1);
    final f = (r1 * r1) - (r3 * r3) - (x1 * x1 - x3 * x3) - (y1 * y1 - y3 * y3);

    final determinant = (a * e) - (b * d);
    if (determinant.abs() < 1e-6) {
      // Anchors are collinear (in a straight line) - geometric singularity
      return null;
    }

    final solX = (c * e - b * f) / determinant;
    final solY = (a * f - c * d) / determinant;

    // Determine Z:
    // If differential barometer Z is provided, use it as baseline ground surface elevation
    double solZ = baroZ ?? a1.z;

    // Compute residual error (RMSE across the 3 anchors)
    final residual = _calculateRmse(
      solX,
      solY,
      solZ,
      [a1, a2, a3],
      [r1, r2, r3],
    );

    return MultilaterationResult(
      x: solX,
      y: solY,
      z: solZ,
      residualError: residual,
      isAccurate: residual < 3.0,
      methodUsed: 'Trilaterasi 3-Titik Linier + Baro Altimetri',
      activeAnchorCount: 3,
    );
  }

  /// Linear Least Squares Multilateration for N >= 4 Anchors
  /// Solves (M^T * M)^-1 * M^T * B
  static MultilaterationResult? _solveLinearLeastSquares(
    List<AnchorNode> anchors,
    List<double> distances,
    double? baroZ,
  ) {
    final n = anchors.length;
    final a0 = anchors[0];
    final r0 = distances[0];

    // Equations: for i = 1 to n-1:
    // 2*(x_i - x_0)*x + 2*(y_i - y_0)*y = r_0^2 - r_i^2 - x_0^2 + x_i^2 - y_0^2 + y_i^2
    double m00 = 0, m01 = 0, m10 = 0, m11 = 0;
    double rhs0 = 0, rhs1 = 0;

    for (int i = 1; i < n; i++) {
      final ai = anchors[i];
      final ri = distances[i];

      final rowA = 2 * (ai.x - a0.x);
      final rowB = 2 * (ai.y - a0.y);
      final bi = (r0 * r0) -
          (ri * ri) -
          (a0.x * a0.x - ai.x * ai.x) -
          (a0.y * a0.y - ai.y * ai.y);

      // Accumulate into Normal Equations: M^T * M and M^T * B
      m00 += rowA * rowA;
      m01 += rowA * rowB;
      m10 += rowB * rowA;
      m11 += rowB * rowB;

      rhs0 += rowA * bi;
      rhs1 += rowB * bi;
    }

    final det = (m00 * m11) - (m01 * m10);
    if (det.abs() < 1e-6) {
      return null;
    }

    final inv00 = m11 / det;
    final inv01 = -m01 / det;
    final inv10 = -m10 / det;
    final inv11 = m00 / det;

    var solX = inv00 * rhs0 + inv01 * rhs1;
    var solY = inv10 * rhs0 + inv11 * rhs1;
    var solZ = baroZ ?? a0.z;

    // Apply 3 iterations of Levenberg-Marquardt / Gradient refinement for sub-meter convergence
    final refined = _refinePosition(solX, solY, solZ, anchors, distances);
    solX = refined[0];
    solY = refined[1];
    solZ = baroZ ?? refined[2];

    final residual = _calculateRmse(solX, solY, solZ, anchors, distances);

    return MultilaterationResult(
      x: solX,
      y: solY,
      z: solZ,
      residualError: residual,
      isAccurate: residual < 2.5,
      methodUsed: 'Multilaterasi Kuadrat Terkecil (N=$n) + Fusi Baro',
      activeAnchorCount: n,
    );
  }

  /// Gradient descent refinement to minimize sum of squared distance errors
  static List<double> _refinePosition(
    double initX,
    double initY,
    double initZ,
    List<AnchorNode> anchors,
    List<double> distances,
  ) {
    double curX = initX;
    double curY = initY;
    double curZ = initZ;
    double stepSize = 0.1;

    for (int iter = 0; iter < 25; iter++) {
      double gradX = 0.0;
      double gradY = 0.0;

      for (int i = 0; i < anchors.length; i++) {
        final a = anchors[i];
        final measured = distances[i];
        final dx = curX - a.x;
        final dy = curY - a.y;
        final currentDist = sqrt(dx * dx + dy * dy);

        if (currentDist > 1e-3) {
          final err = currentDist - measured;
          gradX += 2 * err * (dx / currentDist);
          gradY += 2 * err * (dy / currentDist);
        }
      }

      curX -= stepSize * gradX / anchors.length;
      curY -= stepSize * gradY / anchors.length;
      stepSize *= 0.92; // Decay
    }

    return [curX, curY, curZ];
  }

  /// Calculates the Root Mean Squared Error (RMSE) of the estimated position
  static double _calculateRmse(
    double x,
    double y,
    double z,
    List<AnchorNode> anchors,
    List<double> distances,
  ) {
    double sumSq = 0.0;
    for (int i = 0; i < anchors.length; i++) {
      final a = anchors[i];
      final r = distances[i];
      final dx = x - a.x;
      final dy = y - a.y;
      final dz = z - a.z;
      final computed = sqrt(dx * dx + dy * dy + dz * dz);
      final diff = computed - r;
      sumSq += diff * diff;
    }
    return sqrt(sumSq / anchors.length);
  }
}
