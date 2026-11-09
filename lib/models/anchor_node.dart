import 'dart:math';

enum AnchorRole { anchorA, anchorB, anchorC, anchorD }

class AnchorNode {
  final String id; // e.g. "ANCHOR_A"
  final String name; // e.g. "Base Station A (Patok 1)"
  double x; // Local X coordinate in meters
  double y; // Local Y coordinate in meters
  double z; // Local Elevation/Height in meters
  double? latitude; // Optional GNSS Latitude
  double? longitude; // Optional GNSS Longitude
  double? pressureHpa; // Barometric pressure reference
  DateTime lastSeen;
  double? currentRssi; // Live RSSI observed by rover
  double? filteredDistance; // Kalman filtered distance in meters
  final String? macAddress; // Optional Whitelisted MAC address / BLE hardware ID

  AnchorNode({
    required this.id,
    required this.name,
    this.x = 0.0,
    this.y = 0.0,
    this.z = 0.0,
    this.latitude,
    this.longitude,
    this.pressureHpa,
    DateTime? lastSeen,
    this.currentRssi,
    this.filteredDistance,
    this.macAddress,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'z': z,
        'latitude': latitude,
        'longitude': longitude,
        'pressureHpa': pressureHpa,
        'lastSeen': lastSeen.toIso8601String(),
        'macAddress': macAddress,
      };

  factory AnchorNode.fromJson(Map<String, dynamic> json) => AnchorNode(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        x: (json['x'] as num?)?.toDouble() ?? 0.0,
        y: (json['y'] as num?)?.toDouble() ?? 0.0,
        z: (json['z'] as num?)?.toDouble() ?? 0.0,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        pressureHpa: (json['pressureHpa'] as num?)?.toDouble(),
        lastSeen: json['lastSeen'] != null
            ? DateTime.tryParse(json['lastSeen'] as String)
            : null,
        macAddress: json['macAddress'] as String?,
      );

  AnchorNode copyWith({
    String? id,
    String? name,
    double? x,
    double? y,
    double? z,
    double? latitude,
    double? longitude,
    double? pressureHpa,
    DateTime? lastSeen,
    double? currentRssi,
    double? filteredDistance,
    String? macAddress,
  }) {
    return AnchorNode(
      id: id ?? this.id,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pressureHpa: pressureHpa ?? this.pressureHpa,
      lastSeen: lastSeen ?? this.lastSeen,
      currentRssi: currentRssi ?? this.currentRssi,
      filteredDistance: filteredDistance ?? this.filteredDistance,
      macAddress: macAddress ?? this.macAddress,
    );
  }

  double distanceTo(double targetX, double targetY, [double targetZ = 0.0]) {
    final dx = x - targetX;
    final dy = y - targetY;
    final dz = z - targetZ;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }
}
