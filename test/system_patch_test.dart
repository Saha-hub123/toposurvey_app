import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:topo_survey/models/anchor_node.dart';
import 'package:topo_survey/services/gps_location_service.dart';
import 'package:topo_survey/services/ble_ranging_service.dart';
import 'package:topo_survey/services/multilateration_engine.dart';

void main() {
  group('1. Perbaikan Modul Lokasi / GPS (Anti-Scattering & Drift)', () {
    late GpsLocationService gpsService;

    setUp(() {
      gpsService = GpsLocationService(
        accuracyThreshold: 5.0,
        minDisplacement: 1.0,
        maxSpeedThreshold: 4.5,
      );
    });

    tearDown(() {
      gpsService.dispose();
    });

    test('Terapkan Accuracy Threshold: Abaikan jika akurasi > 5.0 meter', () {
      final now = DateTime.now();

      // Kasus 1: Sinyal buruk (akurasi 8.5 meter) -> Harus DITOLAK
      final badAccPos = Position(
        latitude: -6.200000,
        longitude: 106.816666,
        timestamp: now,
        accuracy: 8.5,
        altitude: 100.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      final statusBad = gpsService.evaluatePosition(badAccPos);
      expect(statusBad, equals(LocationFilterStatus.rejectedLowAccuracy));
      expect(gpsService.stats.rejectedLowAccuracyCount, equals(1));
      expect(gpsService.lastAcceptedPosition, isNull);

      // Kasus 2: Sinyal presisi survei (akurasi 3.2 meter <= 5.0m) -> Harus DITERIMA
      final goodAccPos = Position(
        latitude: -6.200000,
        longitude: 106.816666,
        timestamp: now.add(const Duration(seconds: 1)),
        accuracy: 3.2,
        altitude: 100.0,
        altitudeAccuracy: 0.5,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      final statusGood = gpsService.evaluatePosition(goodAccPos);
      expect(statusGood, equals(LocationFilterStatus.accepted));
      expect(gpsService.stats.acceptedCount, equals(1));
      expect(gpsService.lastAcceptedPosition, isNotNull);
    });

    test('Setel Minimum Displacement: Abaikan update jika surveyor diam (< 1.0 meter)', () {
      final now = DateTime.now();

      // Titik awal diterima
      final p1 = Position(
        latitude: -6.200000,
        longitude: 106.816666,
        timestamp: now,
        accuracy: 2.5,
        altitude: 100.0,
        altitudeAccuracy: 0.5,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      expect(gpsService.evaluatePosition(p1), equals(LocationFilterStatus.accepted));

      // Sensor GPS drift tipis (bergeser 0.3 meter saat surveyor berdiri diam)
      // Jarak pergeseran ~0.33 meter
      final p2Stationary = Position(
        latitude: -6.200003,
        longitude: 106.816666,
        timestamp: now.add(const Duration(seconds: 2)),
        accuracy: 2.8,
        altitude: 100.0,
        altitudeAccuracy: 0.5,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      final statusStationary = gpsService.evaluatePosition(p2Stationary);
      expect(statusStationary, equals(LocationFilterStatus.rejectedStationary));
      expect(gpsService.stats.rejectedStationaryCount, equals(1));

      // Surveyor benar-benar melangkah minimal 1 meter (> 1.0m)
      // Jarak pergeseran ~2.2 meter
      final p3Moved = Position(
        latitude: -6.200020,
        longitude: 106.816666,
        timestamp: now.add(const Duration(seconds: 4)),
        accuracy: 2.2,
        altitude: 100.0,
        altitudeAccuracy: 0.5,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 1.1,
        speedAccuracy: 0.1,
      );
      final statusMoved = gpsService.evaluatePosition(p3Moved);
      expect(statusMoved, equals(LocationFilterStatus.accepted));
      expect(gpsService.stats.acceptedCount, equals(2));
    });

    test('Tambahkan Outlier Rejection: Tolak lompatan puluhan meter dalam hitungan detik', () {
      final now = DateTime.now();

      final pOrigin = Position(
        latitude: -6.200000,
        longitude: 106.816666,
        timestamp: now,
        accuracy: 2.0,
        altitude: 100.0,
        altitudeAccuracy: 0.5,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      expect(gpsService.evaluatePosition(pOrigin), equals(LocationFilterStatus.accepted));

      // Tiba-tiba titik melompat ~55 meter hanya dalam 1 detik (kecepatan 55 m/s, tidak masuk akal untuk manusia berjalan)
      final pAnomalyJump = Position(
        latitude: -6.200500,
        longitude: 106.816666,
        timestamp: now.add(const Duration(seconds: 1)),
        accuracy: 3.0,
        altitude: 100.0,
        altitudeAccuracy: 0.5,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      final statusAnomaly = gpsService.evaluatePosition(pAnomalyJump);
      expect(statusAnomaly, equals(LocationFilterStatus.rejectedOutlierSpeed));
      expect(gpsService.stats.rejectedOutlierCount, equals(1));
    });
  });

  group('2. Perbaikan Modul Trilaterasi (Anti-Deteksi Perangkat Asing)', () {
    test('Filter Batas Signal Strength (RSSI): Nilai < -80 dBm dianggap di luar jarak efektif', () {
      final ble = BleRangingService(minRssiThreshold: -80.0);

      // RSSI -85 dBm (lemah / di luar jangkauan efektif)
      expect(-85.0 < ble.minRssiThreshold, isTrue);

      // RSSI -65 dBm (kuat / jangkauan valid)
      expect(-65.0 >= ble.minRssiThreshold, isTrue);
    });

    test('Filter MAC Address (Whitelisting): Hanya proses MAC Address yang terdaftar', () {
      final ble = BleRangingService(enforceMacWhitelist: true);

      ble.setMacWhitelist('ANCHOR_A', 'AA:BB:CC:11:22:33');
      ble.setMacWhitelist('ANCHOR_B', 'AA:BB:CC:44:55:66');

      expect(ble.anchorMacWhitelist['ANCHOR_A'], equals('AA:BB:CC:11:22:33'));
      expect(ble.anchorMacWhitelist.containsValue('AA:BB:CC:11:22:33'), isTrue);

      // MAC HP asing di sekitar
      const foreignMac = '12:34:56:78:9A:BC';
      expect(ble.anchorMacWhitelist.containsValue(foreignMac), isFalse);
    });

    test('Validasi Advertising Payload: Parser byte array TopoSurvey membaca paket telemetri dan drop paket liar', () {
      // 1. Paket valid Anchor A: Magic 'TP' (0x54, 0x50), Role 0x01, Ver 0x01
      final validAnchorABoolBytes = BleRangingService.buildAnchorPayload('ANCHOR_A', seq: 5, battery: 92);
      final parsedA = BleRangingService.parseAdvertisingPayload(validAnchorABoolBytes);

      expect(parsedA, isNotNull);
      expect(parsedA!.anchorId, equals('ANCHOR_A'));
      expect(parsedA.protocolVersion, equals(1));
      expect(parsedA.batteryPercent, equals(92));

      // 2. Paket valid Anchor B
      final validAnchorBBytes = BleRangingService.buildAnchorPayload('ANCHOR_B', seq: 10, battery: 85);
      final parsedB = BleRangingService.parseAdvertisingPayload(validAnchorBBytes);
      expect(parsedB, isNotNull);
      expect(parsedB!.anchorId, equals('ANCHOR_B'));

      // 3. Paket perangkat asing (misal sinyal Apple Continuity / Google Nearby):
      // Byte array tidak memiliki magic header [0x54, 0x50]
      final foreignPacket = [0x00, 0x4C, 0x10, 0x05, 0x01, 0x00];
      final parsedForeign = BleRangingService.parseAdvertisingPayload(foreignPacket);
      expect(parsedForeign, isNull); // Dropped!
    });
  });

  group('3. Dukungan Mode 3 HP (2 Patok Base + 1 Rover)', () {
    test('Trilaterasi 2-Base (Mode 3 HP) menyelesaikan posisi Rover secara presisi', () {
      final anchorA = AnchorNode(
        id: 'ANCHOR_A',
        name: 'Base A (Origin)',
        x: 0.0,
        y: 0.0,
        z: 100.0,
      );
      final anchorB = AnchorNode(
        id: 'ANCHOR_B',
        name: 'Base B (15m)',
        x: 15.0,
        y: 0.0,
        z: 100.0,
      );

      // Rover berada di koordinat lokal (7.5, 10.0)
      // Jarak ke A = sqrt(7.5^2 + 10^2) = 12.5m
      // Jarak ke B = sqrt(7.5^2 + 10^2) = 12.5m
      final distances = {
        'ANCHOR_A': 12.5,
        'ANCHOR_B': 12.5,
      };

      final result = MultilaterationEngine.solve(
        anchors: [anchorA, anchorB],
        measuredDistances: distances,
        differentialElevationZ: 101.5,
        surveySidePositive: true,
      );

      expect(result, isNotNull);
      expect(result!.activeAnchorCount, equals(2));
      expect(result.x, closeTo(7.5, 0.01));
      expect(result.y, closeTo(10.0, 0.01));
      expect(result.z, equals(101.5)); // Fusi Barometrik
      expect(result.isAccurate, isTrue);
      expect(result.methodUsed, contains('Trilaterasi 2-Base (Mode 3 HP)'));
    });

    test('Mode 3 HP: Toggle kuadran survei membalik sumbu normal Y', () {
      final anchorA = AnchorNode(
        id: 'ANCHOR_A',
        name: 'Base A',
        x: 0.0,
        y: 0.0,
        z: 100.0,
      );
      final anchorB = AnchorNode(
        id: 'ANCHOR_B',
        name: 'Base B',
        x: 15.0,
        y: 0.0,
        z: 100.0,
      );

      final distances = {
        'ANCHOR_A': 12.5,
        'ANCHOR_B': 12.5,
      };

      // Kuadran Negatif (-Y)
      final resultNeg = MultilaterationEngine.solve(
        anchors: [anchorA, anchorB],
        measuredDistances: distances,
        differentialElevationZ: 100.0,
        surveySidePositive: false,
      );

      expect(resultNeg, isNotNull);
      expect(resultNeg!.x, closeTo(7.5, 0.01));
      expect(resultNeg.y, closeTo(-10.0, 0.01));
    });

    test('Sistem otomatis beralih ke Mode Kuadrat Terkecil / 3-Titik jika 3+ Anchor terhubung', () {
      final anchorA = AnchorNode(id: 'ANCHOR_A', name: 'A', x: 0.0, y: 0.0, z: 100.0);
      final anchorB = AnchorNode(id: 'ANCHOR_B', name: 'B', x: 15.0, y: 0.0, z: 100.0);
      final anchorC = AnchorNode(id: 'ANCHOR_C', name: 'C', x: 7.5, y: 18.0, z: 100.0);

      // Rover di (7.5, 6.0)
      final distA = anchorA.distanceTo(7.5, 6.0, 100.0);
      final distB = anchorB.distanceTo(7.5, 6.0, 100.0);
      final distC = anchorC.distanceTo(7.5, 6.0, 100.0);

      final distances = {
        'ANCHOR_A': distA,
        'ANCHOR_B': distB,
        'ANCHOR_C': distC,
      };

      final result = MultilaterationEngine.solve(
        anchors: [anchorA, anchorB, anchorC],
        measuredDistances: distances,
      );

      expect(result, isNotNull);
      expect(result!.activeAnchorCount, equals(3));
      expect(result.x, closeTo(7.5, 0.05));
      expect(result.y, closeTo(6.0, 0.05));
    });
  });
}

