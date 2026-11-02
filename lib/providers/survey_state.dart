import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/anchor_node.dart';
import '../models/survey_point.dart';
import '../services/multilateration_engine.dart';
import '../services/ble_ranging_service.dart';
import '../services/barometer_elevation_service.dart';
import '../services/mesh_network_service.dart';

enum DeviceRole { rover, anchor }

class SurveyState extends ChangeNotifier {
  // Services
  final BleRangingService _bleService = BleRangingService();
  final BarometerElevationService _baroService = BarometerElevationService();
  final MeshNetworkService _meshService = MeshNetworkService();

  // Role & Configuration
  DeviceRole _currentRole = DeviceRole.rover;
  String _selectedAnchorId = 'ANCHOR_A'; // If device is in Anchor mode
  String _projectName = 'Survey Topografi Lahan 01';
  String _surveyorName = 'Tim Surveyor';

  // Anchors State (At least 3 anchors required)
  final List<AnchorNode> _anchors = [
    AnchorNode(
      id: 'ANCHOR_A',
      name: 'Base Station A (Origin 0,0)',
      x: 0.0,
      y: 0.0,
      z: 100.0,
      pressureHpa: 1013.25,
    ),
    AnchorNode(
      id: 'ANCHOR_B',
      name: 'Base Station B (Sumbu X)',
      x: 15.0,
      y: 0.0,
      z: 100.2,
      pressureHpa: 1013.23,
    ),
    AnchorNode(
      id: 'ANCHOR_C',
      name: 'Base Station C (Sumbu Y)',
      x: 7.5,
      y: 18.0,
      z: 99.8,
      pressureHpa: 1013.28,
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

  // Getters
  DeviceRole get currentRole => _currentRole;
  String get selectedAnchorId => _selectedAnchorId;
  String get projectName => _projectName;
  String get surveyorName => _surveyorName;
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
  }) {
    final index = _anchors.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _anchors[index] = _anchors[index].copyWith(
        x: x,
        y: y,
        z: z,
        name: name,
        lastSeen: DateTime.now(),
      );
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
        lastSeen: DateTime.now(),
      );
    } else {
      _anchors.add(synced);
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
    _currentPositionResult = MultilaterationEngine.solve(
      anchors: _anchors,
      measuredDistances: _liveDistances,
      differentialElevationZ: diffZ,
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

    final point = SurveyPoint(
      id: 'PT_${DateTime.now().millisecondsSinceEpoch}',
      pointNumber: _nextPointNumber++,
      x: pos.x,
      y: pos.y,
      z: pos.z,
      relativeElevation: relativeElev,
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

  /// Auto-assign GPS coordinates to an anchor from current phone location
  Future<bool> calibrateAnchorFromGps(String anchorId) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          return false;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );

      final index = _anchors.indexWhere((a) => a.id == anchorId);
      if (index >= 0) {
        _anchors[index] = _anchors[index].copyWith(
          latitude: pos.latitude,
          longitude: pos.longitude,
          z: pos.altitude != 0.0 ? pos.altitude : _anchors[index].z,
        );
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Field simulation mode: simulates walking a topographic terrain grid
  void toggleSimulation() {
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

        // Compute simulated distances to anchors A, B, C
        for (final anchor in _anchors) {
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
    _simulationTimer?.cancel();
    _bleService.dispose();
    _baroService.dispose();
    _meshService.dispose();
    super.dispose();
  }
}
