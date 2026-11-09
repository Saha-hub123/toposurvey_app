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

/// Parsed telemetry from TopoSurvey custom advertising payload
class TopoBeaconPayload {
  final String anchorId;
  final int protocolVersion;
  final int sequenceNumber;
  final int? batteryPercent;
  final double? txPowerCalibrated;

  TopoBeaconPayload({
    required this.anchorId,
    required this.protocolVersion,
    required this.sequenceNumber,
    this.batteryPercent,
    this.txPowerCalibrated,
  });
}

class BleScanFilterStats {
  final int validPacketsCount;
  final int droppedWeakRssiCount;
  final int droppedNonWhitelistedCount;
  final int droppedInvalidPayloadCount;

  BleScanFilterStats({
    required this.validPacketsCount,
    required this.droppedWeakRssiCount,
    required this.droppedNonWhitelistedCount,
    required this.droppedInvalidPayloadCount,
  });
}

class BleRangingService {
  // TopoSurvey 128-bit Service UUID
  static const String topoSurveyServiceUuid =
      "0000a1b2-0000-1000-8000-00805f9b34fb";
  // TopoSurvey 16-bit Custom Manufacturer ID (0x5450 = 'TP')
  static const int topoManufacturerId = 0x5450;
  // Magic byte header: 'T', 'P'
  static const List<int> topoMagicHeader = [0x54, 0x50];

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

  // Filter & Whitelist Settings
  double minRssiThreshold; // Filter sinyal lemah di luar jarak efektif (default -80.0 dBm)
  bool enforceMacWhitelist; // Hanya terima MAC Address patok terdaftar
  bool strictPayloadValidation; // Validasi byte array advertising payload
  final Map<String, String> _anchorMacWhitelist = {}; // Anchor ID -> MAC Address (uppercase)

  // Diagnostics counters
  int _validPacketsCount = 0;
  int _droppedWeakRssiCount = 0;
  int _droppedNonWhitelistedCount = 0;
  int _droppedInvalidPayloadCount = 0;

  BleRangingService({
    this.txPowerAt1m = -59.0,
    this.pathLossExponent = 2.2,
    this.minRssiThreshold = -80.0, // Batas sinyal efektif trilaterasi (-80 dBm)
    this.enforceMacWhitelist = false,
    this.strictPayloadValidation = false,
  });

  Stream<Map<String, double>> get distanceStream =>
      _rangingStreamController.stream;
  Map<String, double> get currentDistances =>
      Map.unmodifiable(_estimatedDistances);
  Map<String, double> get currentFilteredRssi =>
      Map.unmodifiable(_filteredRssi);
  Map<String, String> get anchorMacWhitelist =>
      Map.unmodifiable(_anchorMacWhitelist);
  bool get isScanning => _isScanning;

  BleScanFilterStats get filterStats => BleScanFilterStats(
        validPacketsCount: _validPacketsCount,
        droppedWeakRssiCount: _droppedWeakRssiCount,
        droppedNonWhitelistedCount: _droppedNonWhitelistedCount,
        droppedInvalidPayloadCount: _droppedInvalidPayloadCount,
      );

  void setMacWhitelist(String anchorId, String macAddress) {
    final cleanMac = macAddress.trim().toUpperCase();
    if (cleanMac.isNotEmpty) {
      _anchorMacWhitelist[anchorId] = cleanMac;
    } else {
      _anchorMacWhitelist.remove(anchorId);
    }
  }

  void removeMacWhitelist(String anchorId) {
    _anchorMacWhitelist.remove(anchorId);
  }

  void clearMacWhitelist() {
    _anchorMacWhitelist.clear();
  }

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

  /// Process an RSSI sample from a verified anchor device
  void processAnchorRssi(String anchorId, double rawRssi) {
    _kalmanFilters.putIfAbsent(anchorId, () => KalmanFilter1D());
    final filtered = _kalmanFilters[anchorId]!.filter(rawRssi);
    _filteredRssi[anchorId] = filtered;

    final dist = rssiToDistance(filtered);
    _estimatedDistances[anchorId] = dist;

    _validPacketsCount++;
    _rangingStreamController.add(_estimatedDistances);
  }

  /// Parser untuk memvalidasi byte array advertising payload / telemetri khusus survei
  /// Format:
  /// Byte 0..1: [0x54, 0x50] (ASCII 'TP')
  /// Byte 2: Anchor Role (1=ANCHOR_A, 2=ANCHOR_B, 3=ANCHOR_C, 4=ANCHOR_D)
  /// Byte 3: Protocol Version (misal 0x01)
  /// Byte 4: Sequence Number
  /// Byte 5: Battery % (opsional)
  static TopoBeaconPayload? parseAdvertisingPayload(List<int> bytes) {
    if (bytes.length < 4) return null;

    // Cek Magic Header
    if (bytes[0] != topoMagicHeader[0] || bytes[1] != topoMagicHeader[1]) {
      return null;
    }

    String anchorId;
    switch (bytes[2]) {
      case 0x01:
        anchorId = 'ANCHOR_A';
        break;
      case 0x02:
        anchorId = 'ANCHOR_B';
        break;
      case 0x03:
        anchorId = 'ANCHOR_C';
        break;
      case 0x04:
        anchorId = 'ANCHOR_D';
        break;
      default:
        return null; // Format anchor byte tidak dikenal
    }

    final version = bytes[3];
    final seq = bytes.length > 4 ? bytes[4] : 0;
    final battery = bytes.length > 5 ? bytes[5] : null;

    return TopoBeaconPayload(
      anchorId: anchorId,
      protocolVersion: version,
      sequenceNumber: seq,
      batteryPercent: battery,
    );
  }

  /// Generate byte array payload untuk Anchor yang memancarkan sinyal survei
  static List<int> buildAnchorPayload(String anchorId, {int seq = 1, int battery = 100}) {
    int roleByte = 0x01;
    if (anchorId.endsWith('B')) roleByte = 0x02;
    if (anchorId.endsWith('C')) roleByte = 0x03;
    if (anchorId.endsWith('D')) roleByte = 0x04;

    return [
      topoMagicHeader[0],
      topoMagicHeader[1],
      roleByte,
      0x01, // Version 1
      seq & 0xFF,
      battery.clamp(0, 100),
    ];
  }

  /// Start BLE scanning for TopoSurvey anchors with strict filters
  Future<void> startScanning() async {
    if (_isScanning) return;

    try {
      if (await FlutterBluePlus.isSupported == false) {
        return;
      }

      // Mulai scan dengan Android low latency mode
      await FlutterBluePlus.startScan(
        timeout: const Duration(hours: 4),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      _isScanning = true;

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          // 1. FILTER BATAS SIGNAL STRENGTH (RSSI):
          // Abaikan sinyal dari perangkat yang nilainya terlalu lemah (< minRssiThreshold, default -80 dBm)
          // Berada di luar jarak efektif trilaterasi
          if (r.rssi < minRssiThreshold) {
            _droppedWeakRssiCount++;
            continue;
          }

          final macAddress = r.device.remoteId.str.toUpperCase();
          final devName = r.device.platformName.toUpperCase().trim();
          final advName = r.advertisementData.advName.toUpperCase().trim();

          // 2. FILTER MAC ADDRESS (WHITELISTING):
          // Jika mode whitelist aktif atau patok memiliki MAC terdaftar:
          String? matchedAnchorId;

          // Cek apakah MAC Address ini terdaftar pada whitelist anchor kita
          for (final entry in _anchorMacWhitelist.entries) {
            if (entry.value == macAddress) {
              matchedAnchorId = entry.key;
              break;
            }
          }

          if (enforceMacWhitelist && matchedAnchorId == null) {
            // Mode whitelist ketat: tolak semua perangkat yang MAC-nya bukan patok survei
            _droppedNonWhitelistedCount++;
            continue;
          }

          // 3. VALIDASI ADVERTISING PAYLOAD & SERVICE UUID:
          // Jika alat mengirimkan paket data khusus, baca byte array-nya.
          TopoBeaconPayload? parsedPayload;

          // Cek manufacturerData byte array
          final mData = r.advertisementData.manufacturerData;
          if (mData.isNotEmpty) {
            for (final entry in mData.entries) {
              final payload = parseAdvertisingPayload(entry.value);
              if (payload != null) {
                parsedPayload = payload;
                break;
              }
            }
          }

          // Cek serviceData byte array
          if (parsedPayload == null &&
              r.advertisementData.serviceData.isNotEmpty) {
            for (final entry in r.advertisementData.serviceData.entries) {
              final payload = parseAdvertisingPayload(entry.value);
              if (payload != null) {
                parsedPayload = payload;
                break;
              }
            }
          }

          // Jika payload telemetri survei valid terdeteksi
          if (parsedPayload != null) {
            matchedAnchorId = parsedPayload.anchorId;
          } else if (strictPayloadValidation) {
            // Jika mode validasi payload ketat aktif dan bukan paket survei kita, langsung buang (drop)
            _droppedInvalidPayloadCount++;
            continue;
          }

          // Jika belum cocok dari payload atau MAC, evaluasi nama beacon terdaftar
          if (matchedAnchorId == null) {
            // Periksa apakah perangkat adalah sinyal broadcasting HP modern asing
            // (misal Apple, Samsung, Xiaomi yang bukan anchor TopoSurvey)
            final isTopoName = _isLegitimateTopoAnchorName(devName) ||
                _isLegitimateTopoAnchorName(advName);

            // Periksa Service UUID terdaftar
            final hasTopoServiceUuid = r.advertisementData.serviceUuids.any(
              (uuid) =>
                  uuid.str.toLowerCase() == topoSurveyServiceUuid.toLowerCase(),
            );

            if (hasTopoServiceUuid || isTopoName) {
              matchedAnchorId = _resolveAnchorIdFromName(devName.isNotEmpty ? devName : advName);
            } else {
              // Bukan perangkat survei kita, abaikan (drop perangkat liar)
              _droppedInvalidPayloadCount++;
              continue;
            }
          }

          if (matchedAnchorId != null) {
            processAnchorRssi(matchedAnchorId, r.rssi.toDouble());
          }
        }
      });
    } catch (_) {
      // Bluetooth scan error handled gracefully
    }
  }

  /// Memverifikasi nama anchor valid: TOPO_A, TOPO_B, TOPO_C, TOPO_D
  /// untuk mencegah false positive dari perangkat dengan substring acak
  bool _isLegitimateTopoAnchorName(String name) {
    if (name.isEmpty) return false;
    final upper = name.toUpperCase();
    return upper == 'TOPO_A' ||
        upper == 'TOPO_B' ||
        upper == 'TOPO_C' ||
        upper == 'TOPO_D' ||
        upper == 'TOPO-A' ||
        upper == 'TOPO-B' ||
        upper == 'TOPO-C' ||
        upper == 'TOPO-D' ||
        upper.startsWith('TOPO_A_') ||
        upper.startsWith('TOPO_B_') ||
        upper.startsWith('TOPO_C_') ||
        upper.startsWith('TOPO_D_');
  }

  String? _resolveAnchorIdFromName(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('TOPO_A') || upper.contains('TOPO-A')) return 'ANCHOR_A';
    if (upper.contains('TOPO_B') || upper.contains('TOPO-B')) return 'ANCHOR_B';
    if (upper.contains('TOPO_C') || upper.contains('TOPO-C')) return 'ANCHOR_C';
    if (upper.contains('TOPO_D') || upper.contains('TOPO-D')) return 'ANCHOR_D';
    return null;
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

  void resetFilterStats() {
    _validPacketsCount = 0;
    _droppedWeakRssiCount = 0;
    _droppedNonWhitelistedCount = 0;
    _droppedInvalidPayloadCount = 0;
  }

  void dispose() {
    stopScanning();
    _rangingStreamController.close();
  }
}
