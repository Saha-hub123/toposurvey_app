import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/survey_state.dart';
import '../services/export_service.dart';

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
          PopupMenuButton<String>(
            tooltip: 'Ekspor Data Survey',
            icon: const Icon(Icons.share, color: Colors.tealAccent),
            color: const Color(0xFF1B2230),
            onSelected: (format) => _export(context, state, format),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Ekspor CSV (AutoCAD / Excel)',
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
                    Text('Ekspor GeoJSON (QGIS / GIS)',
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
                    'Gunakan menu ROVER atau aktifkan Simulasi untuk mengumpulkan titik.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
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
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.table_view, size: 20),
                label: const Text(
                  'BAGIKAN CSV (EXCEL)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _export(context, state, 'csv'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.orangeAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.draw, color: Colors.orangeAccent, size: 20),
                label: const Text('BAGIKAN DXF'),
                onPressed: () => _export(context, state, 'dxf'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
