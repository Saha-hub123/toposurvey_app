import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class KalmanFilter1D {
  final double _q; // Process noise covariance
  final double _r; // Measurement noise covariance
  double _x = 0; // Value estimate
  double _p = 1.0; // Estimation error covariance
  double _k = 0; // Kalman gain
  bool _initialized = false;

  KalmanFilter1D({double processNoise = 0.008, double measurementNoise = 1.8})
      : _q = processNoise,
        _r = measurementNoise;

  double filter(double measurement) {
    if (!_initialized) {
      _x = measurement;
      _initialized = true;
      return _x;
    }

    // Prediction step
    _p = _p + _q;

    // Update step
    _k = _p / (_p + _r);
    _x = _x + _k * (measurement - _x);
    _p = (1 - _k) * _p;

    return _x;
  }

  void reset() {
    _initialized = false;
    _p = 1.0;
  }
}

class BleRangingService {
  final Map<String, KalmanFilter1D> _kalmanFilters = {};
  final Map<String, double> _filteredRssi = {};
  final Map<String, double> _estimatedDistances = {};
  final _rangingStreamController =
      StreamController<Map<String, double>>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;

  // Survey Ranging Constants
  double txPowerAt1m; // A: RSSI at 1m (e.g. -59 dBm)
  double pathLossExponent; // n: Path Loss Exponent (2.0 - 3.0)

  BleRangingService({
    this.txPowerAt1m = -59.0,
    this.pathLossExponent = 2.2,
  });

  Stream<Map<String, double>> get distanceStream =>
      _rangingStreamController.stream;
  Map<String, double> get currentDistances =>
      Map.unmodifiable(_estimatedDistances);
  Map<String, double> get currentFilteredRssi =>
      Map.unmodifiable(_filteredRssi);
  bool get isScanning => _isScanning;

  /// Calculate distance from filtered RSSI using Log-Distance Path Loss Model:
  /// Distance = 10 ^ ((A - RSSI) / (10 * n))
  double rssiToDistance(double rssi) {
    if (rssi >= 0) return 0.1;
    final exponent = (txPowerAt1m - rssi) / (10.0 * pathLossExponent);
    final dist = pow(10.0, exponent).toDouble();
    return dist.clamp(0.1, 300.0);
  }

  /// Convert distance back to expected theoretical RSSI
  double distanceToExpectedRssi(double distance) {
    if (distance <= 0.1) return txPowerAt1m;
    return txPowerAt1m - (10.0 * pathLossExponent * (log(distance) / ln10));
  }

  /// Process an RSSI sample from an anchor device
  void processAnchorRssi(String anchorId, double rawRssi) {
    _kalmanFilters.putIfAbsent(anchorId, () => KalmanFilter1D());
    final filtered = _kalmanFilters[anchorId]!.filter(rawRssi);
    _filteredRssi[anchorId] = filtered;

    final dist = rssiToDistance(filtered);
    _estimatedDistances[anchorId] = dist;

    _rangingStreamController.add(_estimatedDistances);
  }

  /// Start BLE scanning for TopoSurvey anchors
  Future<void> startScanning() async {
    if (_isScanning) return;

    try {
      if (await FlutterBluePlus.isSupported == false) {
        return;
      }

      await FlutterBluePlus.startScan(
        timeout: const Duration(hours: 4),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      _isScanning = true;

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final devName = r.device.platformName.toUpperCase();
          final advName = r.advertisementData.advName.toUpperCase();

          // Identify TopoSurvey anchors: TOPO_A, TOPO_B, TOPO_C, etc.
          String? matchedAnchorId;
          if (devName.contains('TOPO_A') || advName.contains('TOPO_A')) {
            matchedAnchorId = 'ANCHOR_A';
          } else if (devName.contains('TOPO_B') || advName.contains('TOPO_B')) {
            matchedAnchorId = 'ANCHOR_B';
          } else if (devName.contains('TOPO_C') || advName.contains('TOPO_C')) {
            matchedAnchorId = 'ANCHOR_C';
          } else if (devName.contains('TOPO_D') || advName.contains('TOPO_D')) {
            matchedAnchorId = 'ANCHOR_D';
          }

          if (matchedAnchorId != null) {
            processAnchorRssi(matchedAnchorId, r.rssi.toDouble());
          }
        }
      });
    } catch (e) {
      // Bluetooth scan error handled gracefully
    }
  }

  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
  }

  void injectSimulatedSample(String anchorId, double simulatedDistance) {
    final expectedRssi = distanceToExpectedRssi(simulatedDistance);
    // Add small random noise to simulate radio jitter (+/- 1.5 dB)
    final noise = (Random().nextDouble() - 0.5) * 3.0;
    processAnchorRssi(anchorId, expectedRssi + noise);
  }

  void dispose() {
    stopScanning();
    _rangingStreamController.close();
  }
}
