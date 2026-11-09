import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/anchor_node.dart';
import '../models/survey_point.dart';

class MeshNetworkService {
  static const int meshPort = 8888;
  static const String protocolSignature = 'TOPOSURVEY_3D_V1';

  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  bool _isRunning = false;

  final _anchorStreamController = StreamController<AnchorNode>.broadcast();
  final _pointStreamController = StreamController<SurveyPoint>.broadcast();

  Stream<AnchorNode> get anchorStream => _anchorStreamController.stream;
  Stream<SurveyPoint> get pointStream => _pointStreamController.stream;
  bool get isRunning => _isRunning;

  /// Start UDP Broadcast listener & sender on the local Wi-Fi / Hotspot subnet
  Future<bool> startMesh() async {
    if (_isRunning) return true;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        meshPort,
        reuseAddress: true,
        reusePort: true,
      );

      _socket!.broadcastEnabled = true;
      _socket!.listen(_handleIncomingDatagram);
      _isRunning = true;
      return true;
    } catch (e) {
      _isRunning = false;
      return false;
    }
  }

  /// Handle incoming packet from peer Android phones with payload validation
  void _handleIncomingDatagram(RawSocketEvent event) {
    if (event == RawSocketEvent.read && _socket != null) {
      final datagram = _socket!.receive();
      if (datagram == null) return;

      try {
        final message = utf8.decode(datagram.data);
        final json = jsonDecode(message) as Map<String, dynamic>;

        // Validasi signature protokol untuk membuang paket asing dari HP lain / traffic Wi-Fi liar
        final protocol = json['proto'] as String?;
        if (protocol != null && protocol != protocolSignature) {
          return; // Paket Wi-Fi asing
        }
        final type = json['type'] as String?;

        // Validasi tipe dan struktur paket TopoSurvey
        if (type == 'ANCHOR_HEARTBEAT') {
          // Validasi kelengkapan data jangkar
          if (json['id'] == null || json['x'] == null || json['y'] == null) {
            return;
          }

          final anchor = AnchorNode(
            id: json['id'] as String,
            name: json['name'] as String? ?? json['id'] as String,
            x: (json['x'] as num).toDouble(),
            y: (json['y'] as num).toDouble(),
            z: (json['z'] as num).toDouble(),
            latitude: (json['lat'] as num?)?.toDouble(),
            longitude: (json['lon'] as num?)?.toDouble(),
            pressureHpa: (json['pressureHpa'] as num?)?.toDouble(),
            macAddress: json['mac'] as String?,
            lastSeen: DateTime.now(),
          );
          _anchorStreamController.add(anchor);
        } else if (type == 'SURVEY_POINT_SYNC') {
          if (json['point'] is Map<String, dynamic>) {
            final point = SurveyPoint.fromJson(json['point'] as Map<String, dynamic>);
            _pointStreamController.add(point);
          }
        }
      } catch (_) {
        // Drop malformed / foreign packets
      }
    }
  }

  /// Broadcast Anchor status (ID, Coordinates, Barometer reading, MAC) every 600ms
  void startAnchorBroadcast(AnchorNode anchor) {
    stopBroadcast();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      broadcastAnchorStatus(anchor);
    });
  }

  /// Broadcast one Anchor telemetry frame
  void broadcastAnchorStatus(AnchorNode anchor) {
    if (_socket == null || !_isRunning) return;

    final payload = jsonEncode({
      'proto': protocolSignature,
      'type': 'ANCHOR_HEARTBEAT',
      'id': anchor.id,
      'name': anchor.name,
      'x': anchor.x,
      'y': anchor.y,
      'z': anchor.z,
      'lat': anchor.latitude,
      'lon': anchor.longitude,
      'pressureHpa': anchor.pressureHpa,
      'mac': anchor.macAddress,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final data = utf8.encode(payload);
    try {
      _socket!.send(
        data,
        InternetAddress('255.255.255.255'),
        meshPort,
      );
    } catch (_) {}
  }

  /// Broadcast a newly captured survey point to all connected phones
  void broadcastSurveyPoint(SurveyPoint point) {
    if (_socket == null || !_isRunning) return;

    final payload = jsonEncode({
      'proto': protocolSignature,
      'type': 'SURVEY_POINT_SYNC',
      'point': point.toJson(),
    });

    final data = utf8.encode(payload);
    try {
      _socket!.send(
        data,
        InternetAddress('255.255.255.255'),
        meshPort,
      );
    } catch (_) {}
  }

  void stopBroadcast() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void stopMesh() {
    stopBroadcast();
    _socket?.close();
    _socket = null;
    _isRunning = false;
  }

  void dispose() {
    stopMesh();
    _anchorStreamController.close();
    _pointStreamController.close();
  }
}
