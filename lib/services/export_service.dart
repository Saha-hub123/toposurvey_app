import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/survey_point.dart';
import '../models/anchor_node.dart';

class ExportService {
  static String _formatCsvRow(List<dynamic> row) {
    return row.map((cell) {
      final s = cell.toString();
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }).join(',');
  }

  /// Generate Survey CSV string (Point Number, Easting/X, Northing/Y, Elevation/Z, Code, Note, Accuracy)
  static String generateCsv({
    required List<SurveyPoint> points,
    required List<AnchorNode> anchors,
  }) {
    final rows = <List<dynamic>>[];

    // CSV Header (Standard PNEZD Topo format)
    rows.add([
      'PointID',
      'PointNum',
      'Easting_X(m)',
      'Northing_Y(m)',
      'Elevation_Z(m)',
      'DeltaZ_Rel(m)',
      'FeatureCode',
      'Note',
      'Accuracy(m)',
      'Pressure(hPa)',
      'Latitude',
      'Longitude',
      'Method',
      'Timestamp',
    ]);

    // Base A GPS reference for geodetic projection (if available)
    final baseA = anchors.firstWhere(
      (a) => a.id == 'ANCHOR_A',
      orElse: () => anchors.first,
    );
    final hasGlobalGps = baseA.latitude != null && baseA.longitude != null;
    final double? lat0 = baseA.latitude;
    final double? lon0 = baseA.longitude;

    const double metersPerLatDegree = 111319.49;
    final double metersPerLonDegree = hasGlobalGps
        ? metersPerLatDegree * cos(lat0! * (pi / 180.0))
        : metersPerLatDegree;

    // Add Base Anchors as benchmark reference points
    for (final a in anchors) {
      double? aLat = a.latitude;
      double? aLon = a.longitude;
      if (hasGlobalGps && (aLat == null || aLon == null)) {
        aLat = lat0! + (a.y / metersPerLatDegree);
        aLon = lon0! + (a.x / metersPerLonDegree);
      }

      rows.add([
        a.id,
        0,
        a.x.toStringAsFixed(3),
        a.y.toStringAsFixed(3),
        a.z.toStringAsFixed(3),
        0.000,
        'BASE_ANCHOR',
        a.name,
        0.05,
        a.pressureHpa?.toStringAsFixed(2) ?? '',
        aLat?.toStringAsFixed(7) ?? '',
        aLon?.toStringAsFixed(7) ?? '',
        'BENCHMARK',
        a.lastSeen.toIso8601String(),
      ]);
    }

    // Add Survey Surface Points
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final p in points) {
      double? pLat = p.latitude;
      double? pLon = p.longitude;
      if (hasGlobalGps && (pLat == null || pLon == null)) {
        pLat = lat0! + (p.y / metersPerLatDegree);
        pLon = lon0! + (p.x / metersPerLonDegree);
      }

      rows.add([
        p.id,
        p.pointNumber,
        p.x.toStringAsFixed(3),
        p.y.toStringAsFixed(3),
        p.z.toStringAsFixed(3),
        p.relativeElevation.toStringAsFixed(3),
        p.code,
        p.note,
        p.estimatedAccuracy.toStringAsFixed(3),
        p.pressureHpa?.toStringAsFixed(2) ?? '',
        pLat?.toStringAsFixed(7) ?? '',
        pLon?.toStringAsFixed(7) ?? '',
        p.calculationMethod,
        dateFormat.format(p.timestamp),
      ]);
    }

    return rows.map(_formatCsvRow).join('\r\n');
  }

  /// Generate GeoJSON FeatureCollection with unified coordinate projection
  static String generateGeoJson({
    required List<SurveyPoint> points,
    required List<AnchorNode> anchors,
  }) {
    final features = <String>[];

    final baseA = anchors.firstWhere(
      (a) => a.id == 'ANCHOR_A',
      orElse: () => anchors.first,
    );
    final hasGlobalGps = baseA.latitude != null && baseA.longitude != null;
    final double? lat0 = baseA.latitude;
    final double? lon0 = baseA.longitude;

    const double metersPerLatDegree = 111319.49;
    final double metersPerLonDegree = hasGlobalGps
        ? metersPerLatDegree * cos(lat0! * (pi / 180.0))
        : metersPerLatDegree;

    // Anchors
    for (final a in anchors) {
      double lon = a.longitude ?? a.x;
      double lat = a.latitude ?? a.y;

      if (hasGlobalGps && (a.latitude == null || a.longitude == null)) {
        lat = lat0! + (a.y / metersPerLatDegree);
        lon = lon0! + (a.x / metersPerLonDegree);
      }

      features.add('''{
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [$lon, $lat, ${a.z}]
        },
        "properties": {
          "id": "${a.id}",
          "type": "ANCHOR_BASE",
          "name": "${a.name}",
          "localX": ${a.x},
          "localY": ${a.y},
          "elevation": ${a.z}
        }
      }''');
    }

    // Points
    for (final p in points) {
      double lon = p.longitude ?? p.x;
      double lat = p.latitude ?? p.y;

      if (hasGlobalGps && (p.latitude == null || p.longitude == null)) {
        lat = lat0! + (p.y / metersPerLatDegree);
        lon = lon0! + (p.x / metersPerLonDegree);
      }

      features.add('''{
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [$lon, $lat, ${p.z}]
        },
        "properties": {
          "id": "${p.id}",
          "pointNumber": ${p.pointNumber},
          "code": "${p.code}",
          "localX": ${p.x},
          "localY": ${p.y},
          "elevation": ${p.z},
          "relativeElevation": ${p.relativeElevation},
          "accuracy": ${p.estimatedAccuracy},
          "note": "${p.note}",
          "timestamp": "${p.timestamp.toIso8601String()}"
        }
      }''');
    }

    return '''{
  "type": "FeatureCollection",
  "name": "TopoSurvey_Export",
  "features": [
    ${features.join(',\n')}
  ]
}''';
  }

  /// Generate AutoCAD DXF (Drawing Exchange Format) with 3D Points & Elevation Text
  static String generateDxf({
    required List<SurveyPoint> points,
    required List<AnchorNode> anchors,
  }) {
    final buffer = StringBuffer();

    // DXF Header
    buffer.writeln('0\nSECTION\n2\nHEADER\n0\nENDSEC');
    buffer.writeln('0\nSECTION\n2\nTABLES\n0\nENDSEC');
    buffer.writeln('0\nSECTION\n2\nBLOCKS\n0\nENDSEC');
    buffer.writeln('0\nSECTION\n2\nENTITIES');

    // Add Anchors
    for (final a in anchors) {
      // 3D Point entity
      buffer.writeln('0\nPOINT');
      buffer.writeln('8\nANCHORS'); // Layer name
      buffer.writeln('10\n${a.x}');
      buffer.writeln('20\n${a.y}');
      buffer.writeln('30\n${a.z}');

      // Text label
      buffer.writeln('0\nTEXT');
      buffer.writeln('8\nANCHOR_LABELS');
      buffer.writeln('10\n${a.x + 0.3}');
      buffer.writeln('20\n${a.y + 0.3}');
      buffer.writeln('30\n${a.z}');
      buffer.writeln('40\n0.35'); // Text height
      buffer.writeln('1\n${a.name} Z=${a.z.toStringAsFixed(2)}');
    }

    // Add Survey Points
    for (final p in points) {
      // 3D Point entity
      buffer.writeln('0\nPOINT');
      buffer.writeln('8\nSURVEY_POINTS'); // Layer
      buffer.writeln('10\n${p.x}');
      buffer.writeln('20\n${p.y}');
      buffer.writeln('30\n${p.z}');

      // Elevation Text
      buffer.writeln('0\nTEXT');
      buffer.writeln('8\nELEVATION_TEXT');
      buffer.writeln('10\n${p.x + 0.2}');
      buffer.writeln('20\n${p.y + 0.2}');
      buffer.writeln('30\n${p.z}');
      buffer.writeln('40\n0.25'); // Height
      buffer.writeln('1\n${p.code} Z=${p.z.toStringAsFixed(2)}m');
    }

    buffer.writeln('0\nENDSEC');
    buffer.writeln('0\nEOF');

    return buffer.toString();
  }

  /// Export and trigger Android Share Dialog
  static Future<void> exportAndShare({
    required List<SurveyPoint> points,
    required List<AnchorNode> anchors,
    required String projectName,
    required String format, // "csv", "geojson", "dxf"
  }) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final sanitizedProject = projectName.replaceAll(RegExp(r'\s+'), '_');

    String content = '';
    String fileName = '';

    if (format.toLowerCase() == 'csv') {
      content = generateCsv(points: points, anchors: anchors);
      fileName = '${sanitizedProject}_$timestamp.csv';
    } else if (format.toLowerCase() == 'geojson') {
      content = generateGeoJson(points: points, anchors: anchors);
      fileName = '${sanitizedProject}_$timestamp.geojson';
    } else if (format.toLowerCase() == 'dxf') {
      content = generateDxf(points: points, anchors: anchors);
      fileName = '${sanitizedProject}_$timestamp.dxf';
    }

    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'TopoSurvey Export: $fileName',
        text:
            'Data Survey Topografi (${format.toUpperCase()}) dari TopoSurvey 3D.\nTotal Titik: ${points.length}',
      ),
    );
  }
}
