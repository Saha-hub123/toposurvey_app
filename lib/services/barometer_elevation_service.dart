import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class BarometerElevationService {
  StreamSubscription<BarometerEvent>? _barometerSubscription;
  double? _currentPressureHpa;
  bool _isAvailable = false;
  final _pressureController = StreamController<double>.broadcast();

  Stream<double> get pressureStream => _pressureController.stream;
  double? get currentPressureHpa => _currentPressureHpa;
  bool get isSensorAvailable => _isAvailable;

  void startListening() {
    try {
      _barometerSubscription = barometerEventStream().listen(
        (event) {
          _isAvailable = true;
          // Apply light low-pass filtering on raw sensor reading
          if (_currentPressureHpa == null) {
            _currentPressureHpa = event.pressure;
          } else {
            _currentPressureHpa =
                (_currentPressureHpa! * 0.8) + (event.pressure * 0.2);
          }
          _pressureController.add(_currentPressureHpa!);
        },
        onError: (err) {
          _isAvailable = false;
        },
      );
    } catch (e) {
      _isAvailable = false;
    }
  }

  void stopListening() {
    _barometerSubscription?.cancel();
    _barometerSubscription = null;
  }

  /// Calculates differential elevation between Rover and a Base Anchor (in meters).
  /// Formula: \Delta h = 44330.0 * (1.0 - (P_rover / P_base)^0.190295)
  ///
  /// Since both phones measure the same ambient atmosphere at the same moment,
  /// diurnal atmospheric pressure shifts (weather changes) are completely cancelled out!
  static double calculateRelativeElevation({
    required double roverPressureHpa,
    required double baseAnchorPressureHpa,
    double anchorElevationMeters = 0.0,
  }) {
    if (roverPressureHpa <= 0 || baseAnchorPressureHpa <= 0) {
      return anchorElevationMeters;
    }

    // Hypsometric ISA barometric formula
    final pressureRatio = roverPressureHpa / baseAnchorPressureHpa;
    final deltaH = 44330.0 * (1.0 - pow(pressureRatio, 0.190294957));

    return anchorElevationMeters + deltaH;
  }

  /// Converts single pressure reading to absolute standard atmospheric altitude
  static double pressureToStandardAltitude(double pressureHpa) {
    if (pressureHpa <= 0) return 0.0;
    return 44330.0 * (1.0 - pow(pressureHpa / 1013.25, 0.190294957));
  }

  void dispose() {
    stopListening();
    _pressureController.close();
  }
}
