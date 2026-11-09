import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/anchor_node.dart';
import '../models/survey_point.dart';
import '../services/multilateration_engine.dart';
import '../services/ble_ranging_service.dart';
import '../services/barometer_elevation_service.dart';
import '../services/mesh_network_service.dart';
import '../services/gps_location_service.dart';

enum DeviceRole { rover, anchor }

class SurveyState extends ChangeNotifier {
  // Services
  final BleRangingService _bleService = BleRangingService();
  final BarometerElevationService _baroService = BarometerElevationService();
  final MeshNetworkService _meshService = MeshNetworkService();
  final GpsLocationService _gpsService = GpsLocationService();

  // Role & Configuration
  DeviceRole _currentRole = DeviceRole.rover;
  String _selectedAnchorId = 'ANCHOR_A'; // If device is in Anchor mode
  String _projectName = 'Survey Topografi Lahan 01';
  String _surveyorName = 'Tim Surveyor';

  // Kuadran survei untuk mode 2 Base (3 HP): Sisi Depan (+Y) atau Belakang (-Y) terhadap baseline A-B
  bool _surveySidePositive = true;

  // Anchors State (Default 3 anchors, but works with 2 anchors for 3-HP setup)
  final List<AnchorNode> _anchors = [
    AnchorNode(
      id: 'ANCHOR_A',
      name: 'Base Station A (Origin 0,0)',
      x: 0.0,
      y: 0.0,
      z: 100.0,
      pressureHpa: 1013.25,
      macAddress: null,
    ),
    AnchorNode(
      id: 'ANCHOR_B',
      name: 'Base Station B (Sumbu X)',
      x: 15.0,
      y: 0.0,
      z: 100.2,
      pressureHpa: 1013.23,
      macAddress: null,
    ),
    AnchorNode(
      id: 'ANCHOR_C',
      name: 'Base Station C (Sumbu Y)',
      x: 7.5,
      y: 18.0,
      z: 99.8,
      pressureHpa: 1013.28,
      macAddress: null,
    ),
  ];

  // Survey points collected
  final List<SurveyPoint> _surveyPoints = [];
  int _nextPointNumber = 1;

  // Live Rover State
  Map<String, double> _liveDistances = {};
  Map<String, double> _liveRssi = {};
  double? _liveRoverPressure;
  MultilaterationResult? _currentPositionResult;
  bool _isScanning = false;
  bool _isMeshActive = false;
  bool _isSimulating = false;
  Timer? _simulationTimer;

  // Stream Subscriptions
  StreamSubscription? _bleSub;
  StreamSubscription? _baroSub;
  StreamSubscription? _meshAnchorSub;
  StreamSubscription? _meshPointSub;
  StreamSubscription? _gpsSub;

  // Getters
  DeviceRole get currentRole => _currentRole;
  String get selectedAnchorId => _selectedAnchorId;
  String get projectName => _projectName;
  String get surveyorName => _surveyorName;
  bool get surveySidePositive => _surveySidePositive;
  List<AnchorNode> get anchors => List.unmodifiable(_anchors);
  List<SurveyPoint> get surveyPoints => List.unmodifiable(_surveyPoints);
  Map<String, double> get liveDistances => _liveDistances;
  Map<String, double> get liveRssi => _liveRssi;
  double? get liveRoverPressure => _liveRoverPressure;
  MultilaterationResult? get currentPositionResult => _currentPositionResult;
  bool get isScanning => _isScanning;
  bool get isMeshActive => _isMeshActive;
  bool get isSimulating => _isSimulating;
  double get txPowerAt1m => _bleService.txPowerAt1m;
  double get pathLossExponent => _bleService.pathLossExponent;
  bool get isBarometerAvailable => _baroService.isSensorAvailable;

  // GPS Service & Filter Getters
  GpsLocationService get gpsService => _gpsService;
  double get gpsAccuracyThreshold => _gpsService.accuracyThreshold;
  double get gpsMinDisplacement => _gpsService.minDisplacement;
  double get gpsMaxSpeed => _gpsService.maxSpeedThreshold;
  GpsFilterStats get gpsStats => _gpsService.stats;

  // BLE Service & Filter Getters
  BleRangingService get bleService => _bleService;
  double get bleMinRssiThreshold => _bleService.minRssiThreshold;
  bool get bleEnforceMacWhitelist => _bleService.enforceMacWhitelist;
  bool get bleStrictPayloadValidation => _bleService.strictPayloadValidation;
  BleScanFilterStats get bleFilterStats => _bleService.filterStats;

  SurveyState() {
    _initServices();
  }

  void _initServices() {
    // Listen to BLE distances
    _bleSub = _bleService.distanceStream.listen((distances) {
      _liveDistances = Map.from(distances);
      _liveRssi = Map.from(_bleService.currentFilteredRssi);
      _computeLiveRoverPosition();
      notifyListeners();
    });

    // Listen to Barometer
    _baroService.startListening();
    _baroSub = _baroService.pressureStream.listen((pressure) {
      _liveRoverPressure = pressure;
      _computeLiveRoverPosition();
      notifyListeners();
    });

    // Listen to Mesh Network
    _meshAnchorSub = _meshService.anchorStream.listen((syncedAnchor) {
      _updateOrAddAnchor(syncedAnchor);
    });

    _meshPointSub = _meshService.pointStream.listen((syncedPoint) {
      if (!_surveyPoints.any((p) => p.id == syncedPoint.id)) {
        _surveyPoints.add(syncedPoint);
        if (syncedPoint.pointNumber >= _nextPointNumber) {
          _nextPointNumber = syncedPoint.pointNumber + 1;
        }
        notifyListeners();
      }
    });

    // Initial sync of anchor MAC whitelisting
    for (final a in _anchors) {
      if (a.macAddress != null && a.macAddress!.isNotEmpty) {
        _bleService.setMacWhitelist(a.id, a.macAddress!);
      }
    }
  }

  void setRole(DeviceRole role) {
    _currentRole = role;
    if (_currentRole == DeviceRole.anchor) {
      _meshService.startMesh().then((_) {
        final anchor = _anchors.firstWhere(
          (a) => a.id == _selectedAnchorId,
          orElse: () => _anchors.first,
        );
        _meshService.startAnchorBroadcast(anchor);
      });
    } else {
      _meshService.stopBroadcast();
    }
    notifyListeners();
  }

  void setSelectedAnchorId(String id) {
    _selectedAnchorId = id;
    if (_currentRole == DeviceRole.anchor) {
      final anchor = _anchors.firstWhere((a) => a.id == id);
      _meshService.startAnchorBroadcast(anchor);
    }
    notifyListeners();
  }

  void setSurveySidePositive(bool positive) {
    _surveySidePositive = positive;
    _computeLiveRoverPosition();
    notifyListeners();
  }

  void toggleSurveySide() {
    _surveySidePositive = !_surveySidePositive;
    _computeLiveRoverPosition();
    notifyListeners();
  }

  void setProjectDetails({required String name, required String surveyor}) {
    _projectName = name;
    _surveyorName = surveyor;
    notifyListeners();
  }

  void setCalibration({required double txPower, required double exponent}) {
    _bleService.txPowerAt1m = txPower;
    _bleService.pathLossExponent = exponent;
    notifyListeners();
  }

  /// Konfigurasi filter GPS (Accuracy Threshold, Smallest Displacement, Outlier Speed)
  void setGpsFilterSettings({
    double? accuracyThreshold,
    double? minDisplacement,
    double? maxSpeedThreshold,
  }) {
    if (accuracyThreshold != null) {
      _gpsService.accuracyThreshold = accuracyThreshold;
    }
    if (minDisplacement != null) {
      _gpsService.minDisplacement = minDisplacement;
    }
    if (maxSpeedThreshold != null) {
      _gpsService.maxSpeedThreshold = maxSpeedThreshold;
    }
    notifyListeners();
  }

  /// Konfigurasi filter BLE (RSSI cutoff, Whitelisting, Payload Parser)
  void setBleFilterSettings({
    double? minRssiThreshold,
    bool? enforceMacWhitelist,
    bool? strictPayloadValidation,
  }) {
    if (minRssiThreshold != null) {
      _bleService.minRssiThreshold = minRssiThreshold;
    }
    if (enforceMacWhitelist != null) {
      _bleService.enforceMacWhitelist = enforceMacWhitelist;
    }
    if (strictPayloadValidation != null) {
      _bleService.strictPayloadValidation = strictPayloadValidation;
    }
    notifyListeners();
  }

  void updateAnchorMacAddress(String anchorId, String? macAddress) {
    final index = _anchors.indexWhere((a) => a.id == anchorId);
    if (index >= 0) {
      final cleanMac = macAddress?.trim().toUpperCase();
      _anchors[index] = _anchors[index].copyWith(
        macAddress: cleanMac != null && cleanMac.isNotEmpty ? cleanMac : null,
      );
      if (cleanMac != null && cleanMac.isNotEmpty) {
        _bleService.setMacWhitelist(anchorId, cleanMac);
      } else {
        _bleService.removeMacWhitelist(anchorId);
      }
      notifyListeners();
    }
  }

  Future<void> startSurvey() async {
    await _bleService.startScanning();
    await _meshService.startMesh();
    _isScanning = true;
    _isMeshActive = true;
    notifyListeners();
  }

  Future<void> stopSurvey() async {
    await _bleService.stopScanning();
    _meshService.stopMesh();
    _isScanning = false;
    _isMeshActive = false;
    notifyListeners();
  }

  void updateAnchorCoordinates(
    String id, {
    required double x,
    required double y,
    required double z,
    String? name,
    String? macAddress,
  }) {
    final index = _anchors.indexWhere((a) => a.id == id);
    if (index >= 0) {
      final cleanMac = macAddress?.trim().toUpperCase();
      _anchors[index] = _anchors[index].copyWith(
        x: x,
        y: y,
        z: z,
        name: name,
        macAddress: cleanMac != null && cleanMac.isNotEmpty
            ? cleanMac
            : _anchors[index].macAddress,
        lastSeen: DateTime.now(),
      );

      if (cleanMac != null && cleanMac.isNotEmpty) {
        _bleService.setMacWhitelist(id, cleanMac);
      }

      _computeLiveRoverPosition();
      notifyListeners();
    }
  }

  void _updateOrAddAnchor(AnchorNode synced) {
    final index = _anchors.indexWhere((a) => a.id == synced.id);
    if (index >= 0) {
      _anchors[index] = _anchors[index].copyWith(
        name: synced.name,
        x: synced.x,
        y: synced.y,
        z: synced.z,
        latitude: synced.latitude,
        longitude: synced.longitude,
        pressureHpa: synced.pressureHpa,
        macAddress: synced.macAddress ?? _anchors[index].macAddress,
        lastSeen: DateTime.now(),
      );
    } else {
      _anchors.add(synced);
    }

    if (synced.macAddress != null && synced.macAddress!.isNotEmpty) {
      _bleService.setMacWhitelist(synced.id, synced.macAddress!);
    }

    _computeLiveRoverPosition();
    notifyListeners();
  }

  /// Calculates differential elevation between Rover and Anchor A
  double? _computeDifferentialElevation() {
    final anchorA = _anchors.firstWhere(
      (a) => a.id == 'ANCHOR_A',
      orElse: () => _anchors.first,
    );

    final basePressure = anchorA.pressureHpa ?? 1013.25;
    final roverPressure = _liveRoverPressure;

    if (roverPressure == null || basePressure <= 0) {
      return anchorA.z;
    }

    return BarometerElevationService.calculateRelativeElevation(
      roverPressureHpa: roverPressure,
      baseAnchorPressureHpa: basePressure,
      anchorElevationMeters: anchorA.z,
    );
  }

  void _computeLiveRoverPosition() {
    final diffZ = _computeDifferentialElevation();
    // Mendukung 2 Anchor (Mode 3 HP) maupun 3+ Anchor (Mode 4 HP)
    _currentPositionResult = MultilaterationEngine.solve(
      anchors: _anchors,
      measuredDistances: _liveDistances,
      differentialElevationZ: diffZ,
      surveySidePositive: _surveySidePositive,
    );
  }

  /// Record a survey point at the current rover coordinates
  SurveyPoint? recordCurrentPoint({
    String code = 'TANAH',
    String note = '',
  }) {
    final pos = _currentPositionResult;
    if (pos == null) return null;

    final anchorA = _anchors.firstWhere((a) => a.id == 'ANCHOR_A');
    final relativeElev = pos.z - anchorA.z;

    double? ptLat;
    double? ptLon;
    if (anchorA.latitude != null && anchorA.longitude != null) {
      const double metersPerLatDegree = 111319.49;
      final double latRad = anchorA.latitude! * (pi / 180.0);
      final double metersPerLonDegree = metersPerLatDegree * cos(latRad);

      ptLat = anchorA.latitude! + (pos.y / metersPerLatDegree);
      ptLon = anchorA.longitude! + (pos.x / metersPerLonDegree);
    }

    final point = SurveyPoint(
      id: 'PT_${DateTime.now().millisecondsSinceEpoch}',
      pointNumber: _nextPointNumber++,
      x: pos.x,
      y: pos.y,
      z: pos.z,
      relativeElevation: relativeElev,
      latitude: ptLat,
      longitude: ptLon,
      pressureHpa: _liveRoverPressure,
      code: code,
      note: note,
      estimatedAccuracy: pos.residualError,
      timestamp: DateTime.now(),
      anchorDistances: Map.from(_liveDistances),
      calculationMethod: pos.methodUsed,
    );

    _surveyPoints.add(point);
    _meshService.broadcastSurveyPoint(point);
    notifyListeners();
    return point;
  }

  void deletePoint(String id) {
    _surveyPoints.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void clearPoints() {
    _surveyPoints.clear();
    _nextPointNumber = 1;
    notifyListeners();
  }

  /// Ingest imported survey points (from CSV or GeoJSON)
  void importPoints(List<SurveyPoint> importedPoints, {bool replaceExisting = false}) {
    if (replaceExisting) {
      _surveyPoints.clear();
      _nextPointNumber = 1;
    }
    for (final p in importedPoints) {
      _surveyPoints.add(p);
      if (p.pointNumber >= _nextPointNumber) {
        _nextPointNumber = p.pointNumber + 1;
      }
    }
    notifyListeners();
  }

  /// Ingest imported anchors (from CSV or GeoJSON)
  void importAnchors(List<AnchorNode> importedAnchors) {
    for (final a in importedAnchors) {
      _updateOrAddAnchor(a);
    }
    notifyListeners();
  }

  /// Auto-assign GPS coordinates to an anchor from current phone location,
  /// with strict filtering (Accuracy <= 5m, Outlier rejection, Displacement filter)
  Future<bool> calibrateAnchorFromGps(String anchorId) async {
    try {
      final accuratePos = await _gpsService.getAccuratePosition(
        timeout: const Duration(seconds: 10),
      );

      if (accuratePos == null) {
        // GPS fix ditolak karena akurasi buruk (> 5.0m) atau timeout
        return false;
      }

      final index = _anchors.indexWhere((a) => a.id == anchorId);
      if (index >= 0) {
        _anchors[index] = _anchors[index].copyWith(
          latitude: accuratePos.latitude,
          longitude: accuratePos.longitude,
          z: accuratePos.altitude != 0.0 ? accuratePos.altitude : _anchors[index].z,
        );
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Field simulation mode: simulates walking a topographic terrain grid
  /// Also works seamlessly in 3-HP mode (Base A and Base B only) or full 3-base setup
  void toggleSimulation({bool simulate3HpMode = false}) {
    _isSimulating = !_isSimulating;
    if (_isSimulating) {
      double angle = 0.0;
      _simulationTimer =
          Timer.periodic(const Duration(milliseconds: 700), (_) {
        angle += 0.15;
        // Rover path moving in an ellipse around the site
        final simX = 7.5 + 5.0 * cos(angle);
        final simY = 7.0 + 4.5 * sin(angle);
        // Realistic terrain elevation profile: slight hill with a ditch
        final simZ = 100.0 + (1.8 * sin(simX / 3.0) * cos(simY / 3.0));

        // Theoretical pressure for this elevation (approx -0.12 hPa per meter)
        _liveRoverPressure = 1013.25 - ((simZ - 100.0) * 0.12);

        // Compute simulated distances to anchors
        final targetAnchors = simulate3HpMode
            ? _anchors.where((a) => a.id == 'ANCHOR_A' || a.id == 'ANCHOR_B').toList()
            : _anchors;

        for (final anchor in targetAnchors) {
          final dist = anchor.distanceTo(simX, simY, simZ);
          _bleService.injectSimulatedSample(anchor.id, dist);
        }
      });
    } else {
      _simulationTimer?.cancel();
      _simulationTimer = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _baroSub?.cancel();
    _meshAnchorSub?.cancel();
    _meshPointSub?.cancel();
    _gpsSub?.cancel();
    _simulationTimer?.cancel();
    _bleService.dispose();
    _baroService.dispose();
    _meshService.dispose();
    _gpsService.dispose();
    super.dispose();
  }
}
