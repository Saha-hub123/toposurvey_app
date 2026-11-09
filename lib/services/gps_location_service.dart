import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationFilterStatus {
  accepted,
  rejectedLowAccuracy,
  rejectedStationary,
  rejectedOutlierSpeed,
}

class GpsFilterStats {
  final int acceptedCount;
  final int rejectedLowAccuracyCount;
  final int rejectedStationaryCount;
  final int rejectedOutlierCount;
  final double currentAccuracy;
  final DateTime? lastAcceptedTime;

  GpsFilterStats({
    required this.acceptedCount,
    required this.rejectedLowAccuracyCount,
    required this.rejectedStationaryCount,
    required this.rejectedOutlierCount,
    required this.currentAccuracy,
    this.lastAcceptedTime,
  });
}

/// Service to filter raw GPS/GNSS sensor readings against drift,
/// scattering when stationary, and multipath jumps/outliers.
class GpsLocationService {
  // Configurable thresholds for survey-grade precision
  double accuracyThreshold; // Threshold in meters: ignore updates if accuracy > threshold (e.g. 5.0m)
  double minDisplacement; // Minimum movement in meters before logging (e.g. 1.0m)
  double maxSpeedThreshold; // Maximum human walking/moving speed in m/s (e.g. 4.5 m/s = 16.2 km/h)

  Position? _lastAcceptedPosition;
  int _acceptedCount = 0;
  int _rejectedLowAccuracyCount = 0;
  int _rejectedStationaryCount = 0;
  int _rejectedOutlierCount = 0;

  StreamSubscription<Position>? _positionSubscription;
  final _filteredPositionController = StreamController<Position>.broadcast();
  final _filterStatusController =
      StreamController<LocationFilterStatus>.broadcast();

  bool _isListening = false;

  GpsLocationService({
    this.accuracyThreshold = 5.0, // Batas akurasi standar survei aplikasi (5 meter)
    this.minDisplacement = 1.0, // Minimum displacement 1 meter
    this.maxSpeedThreshold = 4.5, // Maksimum kecepatan manusia berjalan di lapangan (m/s)
  });

  Stream<Position> get filteredPositionStream =>
      _filteredPositionController.stream;
  Stream<LocationFilterStatus> get filterStatusStream =>
      _filterStatusController.stream;

  Position? get lastAcceptedPosition => _lastAcceptedPosition;
  bool get isListening => _isListening;

  GpsFilterStats get stats => GpsFilterStats(
        acceptedCount: _acceptedCount,
        rejectedLowAccuracyCount: _rejectedLowAccuracyCount,
        rejectedStationaryCount: _rejectedStationaryCount,
        rejectedOutlierCount: _rejectedOutlierCount,
        currentAccuracy: _lastAcceptedPosition?.accuracy ?? 0.0,
        lastAcceptedTime: _lastAcceptedPosition?.timestamp,
      );

  /// Builds platform-specific LocationSettings.
  /// On Android, distanceFilter sets setSmallestDisplacement(1.0f) in LocationRequest.
  LocationSettings getPlatformLocationSettings() {
    final distanceFilterMeters = minDisplacement.round().clamp(1, 50);

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilterMeters, // setSmallestDisplacement(1.0f)
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilterMeters,
        pauseLocationUpdatesAutomatically: true,
      );
    } else {
      return LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilterMeters,
      );
    }
  }

  /// Evaluates whether a raw GPS position update should be accepted or rejected.
  LocationFilterStatus evaluatePosition(Position pos) {
    // 1. Accuracy Threshold: Abaikan jika akurasi buruk (> 5.0 meter)
    if (pos.accuracy > accuracyThreshold) {
      _rejectedLowAccuracyCount++;
      return LocationFilterStatus.rejectedLowAccuracy;
    }

    // 2. Minimum Displacement & Outlier Rejection relative to previous position
    if (_lastAcceptedPosition != null) {
      final deltaDistance = Geolocator.distanceBetween(
        _lastAcceptedPosition!.latitude,
        _lastAcceptedPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );

      // Setel Minimum Displacement: Abaikan jika surveyor diam (< 1.0 meter)
      if (deltaDistance < minDisplacement) {
        _rejectedStationaryCount++;
        return LocationFilterStatus.rejectedStationary;
      }

      // Outlier Rejection: Hitung delta jarak dan waktu
      final deltaTimeSec = pos.timestamp
              .difference(_lastAcceptedPosition!.timestamp)
              .inMilliseconds /
          1000.0;

      if (deltaTimeSec > 0) {
        final speed = deltaDistance / deltaTimeSec;
        // Jika kecepatan tidak masuk akal untuk manusia berjalan/bergerak (> 4.5 m/s)
        // atau tiba-tiba melompat puluhan meter dalam hitungan detik
        if (speed > maxSpeedThreshold ||
            (deltaDistance > 15.0 && deltaTimeSec < 2.5)) {
          _rejectedOutlierCount++;
          return LocationFilterStatus.rejectedOutlierSpeed;
        }
      }
    }

    // Titik valid dan terfilter
    _lastAcceptedPosition = pos;
    _acceptedCount++;
    return LocationFilterStatus.accepted;
  }

  /// Start continuous filtered GPS position stream
  Future<bool> startListening() async {
    if (_isListening) return true;

    try {
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) return false;

      final settings = getPlatformLocationSettings();
      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: settings)
              .listen((rawPos) {
        final status = evaluatePosition(rawPos);
        _filterStatusController.add(status);
        if (status == LocationFilterStatus.accepted) {
          _filteredPositionController.add(rawPos);
        }
      });

      _isListening = true;
      return true;
    } catch (_) {
      _isListening = false;
      return false;
    }
  }

  /// Stop listening to GPS updates
  void stopListening() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isListening = false;
  }

  /// Fetches an accurate single position (e.g. for calibrating an anchor patok).
  /// Rejects raw readings that have accuracy > accuracyThreshold (5.0m).
  Future<Position?> getAccuratePosition({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) return null;

    final completer = Completer<Position?>();
    final settings = getPlatformLocationSettings();

    StreamSubscription<Position>? tempSub;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        tempSub?.cancel();
        // Return last valid position if available within threshold, or null
        if (_lastAcceptedPosition != null &&
            _lastAcceptedPosition!.accuracy <= accuracyThreshold) {
          completer.complete(_lastAcceptedPosition);
        } else {
          completer.complete(null);
        }
      }
    });

    try {
      // First attempt single immediate fix
      final singlePos = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      if (singlePos.accuracy <= accuracyThreshold) {
        timer.cancel();
        _lastAcceptedPosition = singlePos;
        _acceptedCount++;
        return singlePos;
      }

      // If accuracy was inadequate, listen on stream until an accurate fix arrives
      tempSub = Geolocator.getPositionStream(locationSettings: settings)
          .listen((pos) {
        if (pos.accuracy <= accuracyThreshold) {
          timer.cancel();
          tempSub?.cancel();
          _lastAcceptedPosition = pos;
          _acceptedCount++;
          if (!completer.isCompleted) {
            completer.complete(pos);
          }
        }
      });
    } catch (_) {
      timer.cancel();
      tempSub?.cancel();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return completer.future;
  }

  Future<bool> _checkAndRequestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }
    return permission != LocationPermission.deniedForever;
  }

  void resetFilters() {
    _lastAcceptedPosition = null;
    _acceptedCount = 0;
    _rejectedLowAccuracyCount = 0;
    _rejectedStationaryCount = 0;
    _rejectedOutlierCount = 0;
  }

  void dispose() {
    stopListening();
    _filteredPositionController.close();
    _filterStatusController.close();
  }
}

