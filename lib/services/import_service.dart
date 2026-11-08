import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../models/survey_point.dart';
import '../models/anchor_node.dart';

class ImportResult {
  final List<SurveyPoint> points;
  final List<AnchorNode> anchors;
  final String fileName;
  final String? errorMessage;
  final bool isSuccess;

  ImportResult({
    required this.points,
    required this.anchors,
    required this.fileName,
    this.errorMessage,
    required this.isSuccess,
  });

  factory ImportResult.failure(String fileName, String message) {
    return ImportResult(
      points: [],
      anchors: [],
      fileName: fileName,
      errorMessage: message,
      isSuccess: false,
    );
  }
}

class ImportService {
  /// Opens device file picker to select .csv, .geojson, .json, or .txt survey files
  static Future<ImportResult?> pickAndImportFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'geojson', 'json', 'txt'],
      );

      if (files.isEmpty) {
        return null; // User cancelled picker
      }

      final file = files.first;
      final fileName = file.name;
      final content = await file.xFile.readAsString();

      final extension = file.extension?.toLowerCase() ?? '';
      if (extension == 'geojson' || extension == 'json' || content.trim().startsWith('{')) {
        return parseGeoJson(content, fileName);
      } else {
        return parseCsv(content, fileName);
      }
    } catch (e) {
      return ImportResult.failure('File', 'Gagal membuka file: $e');
    }
  }

  /// Parses GeoJSON string containing Point features
  static ImportResult parseGeoJson(String jsonString, String fileName) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;

      if (features == null || features.isEmpty) {
        return ImportResult.failure(fileName, 'Format GeoJSON tidak memiliki data "features".');
      }

      final points = <SurveyPoint>[];
      final anchors = <AnchorNode>[];
      int pointCounter = 1;

      for (final feat in features) {
        final featMap = feat as Map<String, dynamic>;
        final geom = featMap['geometry'] as Map<String, dynamic>?;
        final props = featMap['properties'] as Map<String, dynamic>? ?? {};

        if (geom != null && geom['type'] == 'Point') {
          final coords = geom['coordinates'] as List<dynamic>?;
          if (coords != null && coords.length >= 2) {
            final x = (coords[0] as num).toDouble();
            final y = (coords[1] as num).toDouble();
            final z = coords.length >= 3 ? (coords[2] as num).toDouble() : (props['elevation'] as num?)?.toDouble() ?? 100.0;

            final type = props['type'] as String?;
            if (type == 'ANCHOR_BASE') {
              final id = props['id'] as String? ?? 'ANCHOR_${anchors.length + 1}';
              final name = props['name'] as String? ?? id;
              anchors.add(AnchorNode(
                id: id,
                name: name,
                x: x,
                y: y,
                z: z,
                latitude: coords[1] as double?,
                longitude: coords[0] as double?,
                lastSeen: DateTime.now(),
              ));
            } else {
              final id = props['id'] as String? ?? 'PT_${DateTime.now().millisecondsSinceEpoch}_$pointCounter';
              final ptNum = (props['pointNumber'] as num?)?.toInt() ?? pointCounter;
              final code = props['code'] as String? ?? props['FeatureCode'] as String? ?? 'KONTUR';
              final note = props['note'] as String? ?? props['Note'] as String? ?? '';
              final relElev = (props['relativeElevation'] as num?)?.toDouble() ?? 0.0;
              final accuracy = (props['accuracy'] as num?)?.toDouble() ?? 0.05;

              points.add(SurveyPoint(
                id: id,
                pointNumber: ptNum,
                x: x,
                y: y,
                z: z,
                relativeElevation: relElev,
                code: code,
                note: note,
                estimatedAccuracy: accuracy,
                timestamp: DateTime.now(),
                calculationMethod: 'IMPORTED_GEOJSON',
              ));
              pointCounter++;
            }
          }
        }
      }

      if (points.isEmpty && anchors.isEmpty) {
        return ImportResult.failure(fileName, 'Tidak ditemukan titik ukur dalam GeoJSON.');
      }

      return ImportResult(
        points: points,
        anchors: anchors,
        fileName: fileName,
        isSuccess: true,
      );
    } catch (e) {
      return ImportResult.failure(fileName, 'Format GeoJSON tidak valid: $e');
    }
  }

  /// Parses CSV or delimited TXT files with auto column detection
  static ImportResult parseCsv(String csvString, String fileName) {
    try {
      final lines = LineSplitter.split(csvString)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();

      if (lines.isEmpty) {
        return ImportResult.failure(fileName, 'Berkas CSV kosong.');
      }

      // Detect delimiter (comma or semicolon)
      final firstLine = lines.first;
      final delimiter = firstLine.contains(';') ? ';' : ',';

      final points = <SurveyPoint>[];
      final anchors = <AnchorNode>[];

      // Check header
      final headerTokens = _splitCsvLine(firstLine, delimiter).map((t) => t.toLowerCase().trim()).toList();
      bool hasHeader = false;

      int idxPointNum = -1;
      int idxX = -1;
      int idxY = -1;
      int idxZ = -1;
      int idxCode = -1;
      int idxNote = -1;
      int idxMethod = -1;

      for (int i = 0; i < headerTokens.length; i++) {
        final col = headerTokens[i].replaceAll(RegExp(r'[\s_\-\(\)]'), '');
        if (col.contains('easting') || col == 'x' || col == 'east') {
          idxX = i;
          hasHeader = true;
        } else if (col.contains('northing') || col == 'y' || col == 'north') {
          idxY = i;
          hasHeader = true;
        } else if (col.contains('elev') || col == 'z' || col == 'tinggi') {
          idxZ = i;
          hasHeader = true;
        } else if (col.contains('pointnum') || col == 'point' || col == 'pt' || col == 'no') {
          idxPointNum = i;
          hasHeader = true;
        } else if (col.contains('code') || col.contains('kode') || col.contains('desc')) {
          idxCode = i;
          hasHeader = true;
        } else if (col.contains('note') || col.contains('catatan')) {
          idxNote = i;
          hasHeader = true;
        } else if (col.contains('method') || col.contains('metode')) {
          idxMethod = i;
          hasHeader = true;
        }
      }

      int startLine = 0;
      if (hasHeader) {
        startLine = 1;
      } else {
        // Fallback default standard PNEZD / XYZ:
        // Col 0: Point Number, Col 1: X, Col 2: Y, Col 3: Z, Col 4: Code
        idxPointNum = 0;
        idxX = 1;
        idxY = 2;
        idxZ = 3;
        idxCode = 4;
      }

      // If X and Y not found from header, guess column indices
      if (idxX == -1 || idxY == -1 || idxZ == -1) {
        // Typical PNEZD: [PT, X, Y, Z, CODE]
        idxPointNum = 0;
        idxX = 1;
        idxY = 2;
        idxZ = 3;
        idxCode = 4;
      }

      int autoCounter = 1;

      for (int lineIdx = startLine; lineIdx < lines.length; lineIdx++) {
        final rawTokens = _splitCsvLine(lines[lineIdx], delimiter);
        if (rawTokens.length < 3) continue;

        double? x = idxX < rawTokens.length ? double.tryParse(rawTokens[idxX].trim()) : null;
        double? y = idxY < rawTokens.length ? double.tryParse(rawTokens[idxY].trim()) : null;
        double? z = idxZ < rawTokens.length ? double.tryParse(rawTokens[idxZ].trim()) : null;

        // If header parsing mapped wrongly to non-numeric cell, try direct column indexes
        if (x == null || y == null || z == null) {
          final numericTokens = <double>[];
          for (final t in rawTokens) {
            final val = double.tryParse(t.trim());
            if (val != null) numericTokens.add(val);
          }
          if (numericTokens.length >= 3) {
            x = numericTokens[0];
            y = numericTokens[1];
            z = numericTokens[2];
          }
        }

        if (x != null && y != null && z != null) {
          int ptNum = autoCounter;
          if (idxPointNum >= 0 && idxPointNum < rawTokens.length) {
            ptNum = int.tryParse(rawTokens[idxPointNum].trim()) ?? autoCounter;
          }

          final code = (idxCode >= 0 && idxCode < rawTokens.length && rawTokens[idxCode].trim().isNotEmpty)
              ? rawTokens[idxCode].trim()
              : 'KONTUR';

          final note = (idxNote >= 0 && idxNote < rawTokens.length) ? rawTokens[idxNote].trim() : '';
          final method = (idxMethod >= 0 && idxMethod < rawTokens.length) ? rawTokens[idxMethod].trim() : 'IMPORTED_CSV';

          // If row represents a base anchor
          if (code.toUpperCase().contains('ANCHOR') || code.toUpperCase().contains('BASE') || method.toUpperCase() == 'BENCHMARK') {
            final anchorId = 'ANCHOR_${anchors.length + 1}';
            anchors.add(AnchorNode(
              id: anchorId,
              name: note.isNotEmpty ? note : 'Base $anchorId',
              x: x,
              y: y,
              z: z,
              lastSeen: DateTime.now(),
            ));
          } else {
            points.add(SurveyPoint(
              id: 'PT_${DateTime.now().millisecondsSinceEpoch}_$autoCounter',
              pointNumber: ptNum,
              x: x,
              y: y,
              z: z,
              relativeElevation: 0.0,
              code: code,
              note: note,
              estimatedAccuracy: 0.05,
              timestamp: DateTime.now(),
              calculationMethod: method,
            ));
            autoCounter++;
          }
        }
      }

      if (points.isEmpty && anchors.isEmpty) {
        return ImportResult.failure(fileName, 'Tidak ada baris koordinat (X, Y, Z) yang valid.');
      }

      return ImportResult(
        points: points,
        anchors: anchors,
        fileName: fileName,
        isSuccess: true,
      );
    } catch (e) {
      return ImportResult.failure(fileName, 'Format CSV gagal diuraikan: $e');
    }
  }

  static List<String> _splitCsvLine(String line, String delimiter) {
    final tokens = <String>[];
    final sb = StringBuffer();
    bool insideQuote = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        insideQuote = !insideQuote;
      } else if (ch == delimiter && !insideQuote) {
        tokens.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    tokens.add(sb.toString().trim());
    return tokens.map((t) => t.replaceAll('"', '').trim()).toList();
  }
}
