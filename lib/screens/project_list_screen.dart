import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/survey_state.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  void _export(
    BuildContext context,
    SurveyState state,
    String format,
  ) async {
    if (state.surveyPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada titik survey yang dapat diekspor!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    try {
      await ExportService.exportAndShare(
        points: state.surveyPoints,
        anchors: state.anchors,
        projectName: state.projectName,
        format: format,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _import(BuildContext context, SurveyState state) async {
    try {
      final result = await ImportService.pickAndImportFile();
      if (result == null || !context.mounted) return; // User cancelled

      if (!result.isSuccess) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1B2230),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('Impor Gagal', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              result.errorMessage ?? 'Gagal membaca format data.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup', style: TextStyle(color: Colors.tealAccent)),
              ),
            ],
          ),
        );
        return;
      }

      // Show confirmation & ingestion options dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1B2230),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.tealAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Impor Data: ${result.fileName}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ditemukan ${result.points.length} titik survei dan ${result.anchors.length} patok anchor.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (result.points.isNotEmpty) ...[
                const Text(
                  'Pratinjau Titik:',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121622),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF263045)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.points.take(3).map((p) {
                      return Text(
                        'P${p.pointNumber} [${p.code}]: X=${p.x.toStringAsFixed(2)} Y=${p.y.toStringAsFixed(2)} Z=${p.z.toStringAsFixed(2)}m',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (result.points.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '...dan ${result.points.length - 3} titik lainnya',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Bagaimana Anda ingin memasukkan data ini?',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.orangeAccent),
              ),
              onPressed: () {
                state.importPoints(result.points, replaceExisting: true);
                if (result.anchors.isNotEmpty) state.importAnchors(result.anchors);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${result.points.length} titik berhasil diimpor (menggantikan data lama).'),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
              child: const Text('Ganti Data Lama'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
              onPressed: () {
                state.importPoints(result.points, replaceExisting: false);
                if (result.anchors.isNotEmpty) state.importAnchors(result.anchors);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${result.points.length} titik berhasil ditambahkan.'),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
              child: const Text('Gabungkan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat impor: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SurveyState>();
    final points = state.surveyPoints;
    final dateFormat = DateFormat('HH:mm:ss');

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      appBar: AppBar(
        title: Text('Daftar Titik (${points.length})'),
        actions: [
          IconButton(
            tooltip: 'Impor Berkas (CSV / GeoJSON)',
            icon: const Icon(Icons.file_open, color: Colors.tealAccent),
            onPressed: () => _import(context, state),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opsi Data Survey',
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1B2230),
            onSelected: (val) {
              if (val == 'import') {
                _import(context, state);
              } else {
                _export(context, state, val);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, color: Colors.tealAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Impor Data (CSV / GeoJSON)',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Ekspor CSV (Excel / AutoCAD)',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'geojson',
                child: Row(
                  children: [
                    Icon(Icons.public, color: Colors.cyanAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Ekspor GeoJSON (QGIS / Web)',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'dxf',
                child: Row(
                  children: [
                    Icon(Icons.draw, color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Ekspor AutoCAD 3D DXF',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: points.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.format_list_bulleted,
                      size: 64,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada titik survey topografi.',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gunakan menu ROVER atau impor data eksternal (CSV / GeoJSON) untuk memulai pemetaan kontur.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.file_upload, size: 20),
                      label: const Text(
                        'IMPOR BERKAS (CSV / GEOJSON)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _import(context, state),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: points.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = points[index];
                return Dismissible(
                  key: Key(p.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    state.deletePoint(p.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF262F44)),
                    ),
                    child: Row(
                      children: [
                        // Point Number Badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.tealAccent),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'P${p.pointNumber}',
                            style: const TextStyle(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Coordinates and Code
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF28344D),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      p.code,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateFormat.format(p.timestamp),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (p.note.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        p.note,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'X: ${p.x.toStringAsFixed(2)}m   Y: ${p.y.toStringAsFixed(2)}m',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Elevation (Z) Value
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${p.z.toStringAsFixed(2)} m',
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              '±${p.estimatedAccuracy.toStringAsFixed(2)}m',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF141824),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.tealAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.file_upload, color: Colors.tealAccent, size: 18),
                label: const Text('IMPOR', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _import(context, state),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.table_view, size: 18),
                label: const Text(
                  'CSV (EXCEL)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () => _export(context, state, 'csv'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.orangeAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.draw, color: Colors.orangeAccent, size: 18),
                label: const Text('DXF 3D', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => _export(context, state, 'dxf'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
