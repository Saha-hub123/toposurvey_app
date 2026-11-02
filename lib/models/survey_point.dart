class SurveyPoint {
  final String id;
  final int pointNumber;
  final double x; // Local X (Easting) in meters
  final double y; // Local Y (Northing) in meters
  final double z; // Elevation (Height) in meters
  final double relativeElevation; // Delta Z relative to Anchor A benchmark
  final double? latitude;
  final double? longitude;
  final double? pressureHpa;
  final String code; // Feature code e.g. "KONTUR", "TANAH", "PARIT", "BATAS"
  final String note;
  final double estimatedAccuracy; // In meters
  final DateTime timestamp;
  final Map<String, double> anchorDistances; // Anchor ID -> Distance (m)
  final String calculationMethod;

  SurveyPoint({
    required this.id,
    required this.pointNumber,
    required this.x,
    required this.y,
    required this.z,
    required this.relativeElevation,
    this.latitude,
    this.longitude,
    this.pressureHpa,
    this.code = 'TANAH',
    this.note = '',
    this.estimatedAccuracy = 0.5,
    DateTime? timestamp,
    this.anchorDistances = const {},
    this.calculationMethod = 'TRILATERASI_BLE_BARO',
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'pointNumber': pointNumber,
        'x': x,
        'y': y,
        'z': z,
        'relativeElevation': relativeElevation,
        'latitude': latitude,
        'longitude': longitude,
        'pressureHpa': pressureHpa,
        'code': code,
        'note': note,
        'estimatedAccuracy': estimatedAccuracy,
        'timestamp': timestamp.toIso8601String(),
        'anchorDistances': anchorDistances,
        'calculationMethod': calculationMethod,
      };

  factory SurveyPoint.fromJson(Map<String, dynamic> json) => SurveyPoint(
        id: json['id'] as String,
        pointNumber: json['pointNumber'] as int? ?? 1,
        x: (json['x'] as num?)?.toDouble() ?? 0.0,
        y: (json['y'] as num?)?.toDouble() ?? 0.0,
        z: (json['z'] as num?)?.toDouble() ?? 0.0,
        relativeElevation:
            (json['relativeElevation'] as num?)?.toDouble() ?? 0.0,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        pressureHpa: (json['pressureHpa'] as num?)?.toDouble(),
        code: json['code'] as String? ?? 'TANAH',
        note: json['note'] as String? ?? '',
        estimatedAccuracy:
            (json['estimatedAccuracy'] as num?)?.toDouble() ?? 0.5,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String)
            : null,
        anchorDistances: (json['anchorDistances'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
        calculationMethod:
            json['calculationMethod'] as String? ?? 'TRILATERASI_BLE_BARO',
      );
}
