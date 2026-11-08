import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/survey_state.dart';
import '../widgets/topo_canvas.dart';
import '../services/import_service.dart';

class MapContourScreen extends StatefulWidget {
  const MapContourScreen({super.key});

  @override
  State<MapContourScreen> createState() => _MapContourScreenState();
}

class _MapContourScreenState extends State<MapContourScreen> {
  double _contourInterval = 0.5; // Default 0.5m
  bool _showContourLines = true;
  bool _showPoints = true;
  bool _showPointLabels = true;

  final List<double> _availableIntervals = [0.2, 0.5, 1.0, 2.0];

  void _import(BuildContext context, SurveyState state) async {
    try {
      final result = await ImportService.pickAndImportFile();
      if (result == null || !context.mounted) return;

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
                  'Impor: ${result.fileName}',
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
              const SizedBox(height: 10),
              const Text(
                'Pilih metode memasukkan data ke peta kontur:',
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
                    content: Text('${result.points.length} titik dimuat ke peta kontur.'),
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
                    content: Text('${result.points.length} titik ditambahkan ke peta kontur.'),
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

    double minZ = 0.0, maxZ = 0.0;
    final allZ = <double>[];
    for (final a in state.anchors) {
      allZ.add(a.z);
    }
    for (final p in points) {
      allZ.add(p.z);
    }
    if (allZ.isNotEmpty) {
      minZ = allZ.reduce(min);
      maxZ = allZ.reduce(max);
    }
    final deltaZ = (maxZ - minZ).abs();

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      appBar: AppBar(
        title: const Text('Peta Topografi & Garis Kontur'),
        actions: [
          IconButton(
            tooltip: 'Impor Data (CSV / GeoJSON)',
            icon: const Icon(Icons.file_upload, color: Colors.tealAccent),
            onPressed: () => _import(context, state),
          ),
          IconButton(
            tooltip: 'Hapus Semua Titik',
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: points.isEmpty
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1B2230),
                        title: const Text('Hapus Seluruh Titik Survey?'),
                        content: const Text(
                          'Tindakan ini akan mengosongkan seluruh titik topografi yang telah direkam.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent),
                            onPressed: () {
                              state.clearPoints();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Hapus Semua'),
                          ),
                        ],
                      ),
                    );
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF161B26),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'TOTAL TITIK',
                  value: '${points.length}',
                  color: Colors.white,
                ),
                _StatItem(
                  label: 'ELEVASI MIN (Z)',
                  value: allZ.isNotEmpty
                      ? '${minZ.toStringAsFixed(2)}m'
                      : '--',
                  color: Colors.cyanAccent,
                ),
                _StatItem(
                  label: 'ELEVASI MAX (Z)',
                  value: allZ.isNotEmpty
                      ? '${maxZ.toStringAsFixed(2)}m'
                      : '--',
                  color: Colors.deepOrangeAccent,
                ),
                _StatItem(
                  label: 'BEDA TINGGI (ΔZ)',
                  value: allZ.isNotEmpty
                      ? '${deltaZ.toStringAsFixed(2)}m'
                      : '--',
                  color: Colors.amberAccent,
                ),
              ],
            ),
          ),

          // Contour Control & Filter Bar (Horizontally scrollable & compact to prevent overflow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF131722),
              border: Border(
                bottom: BorderSide(color: Color(0xFF222B3D)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  const Text(
                    'Interval:',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    children: _availableIntervals.map((interval) {
                      final isSelected = _contourInterval == interval;
                      return Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _contourInterval = interval);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.tealAccent : const Color(0xFF1C2433),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? Colors.tealAccent : const Color(0xFF2D3A50),
                              ),
                            ),
                            child: Text(
                              '${interval}m',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 18,
                    color: const Color(0xFF2E384D),
                  ),
                  const SizedBox(width: 4),

                  // Toggle Contour Lines
                  _ToolbarIconButton(
                    icon: Icons.waves,
                    isActive: _showContourLines,
                    tooltip: _showContourLines ? 'Garis Kontur: Aktif' : 'Garis Kontur: Mati',
                    onPressed: () {
                      setState(() => _showContourLines = !_showContourLines);
                    },
                  ),

                  // Toggle Points
                  _ToolbarIconButton(
                    icon: Icons.scatter_plot,
                    isActive: _showPoints,
                    tooltip: _showPoints ? 'Titik Ukur: Aktif' : 'Titik Ukur: Mati',
                    onPressed: () {
                      setState(() => _showPoints = !_showPoints);
                    },
                  ),

                  // Toggle Point Labels
                  _ToolbarIconButton(
                    icon: Icons.label,
                    isActive: _showPointLabels,
                    tooltip: _showPointLabels ? 'Label Titik: Aktif' : 'Label Titik: Mati',
                    onPressed: () {
                      setState(() => _showPointLabels = !_showPointLabels);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Interactive InteractiveViewer for Canvas (Pinch zoom & pan)
          Expanded(
            child: Container(
              color: const Color(0xFF0C0E17),
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(80),
                minScale: 0.5,
                maxScale: 5.0,
                child: TopoCanvas(
                  anchors: state.anchors,
                  points: state.surveyPoints,
                  liveRover: state.currentPositionResult,
                  liveDistances: state.liveDistances,
                  showContourLines: _showContourLines,
                  showPoints: _showPoints,
                  showPointLabels: _showPointLabels,
                  contourInterval: _contourInterval,
                ),
              ),
            ),
          ),

          // Elevation Gradient Legend & Anchors indicator
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF141824),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Kontur Elevasi:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${minZ.toStringAsFixed(1)}m',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.cyanAccent,
                              Colors.greenAccent,
                              Colors.yellowAccent,
                              Colors.orangeAccent,
                              Colors.deepOrangeAccent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${maxZ.toStringAsFixed(1)}m',
                      style: const TextStyle(
                        color: Colors.deepOrangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Major contour line indicator
                      Container(
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Mayor',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      const SizedBox(width: 10),
                      // Minor contour line indicator
                      Container(
                        width: 12,
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: Colors.white54,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Minor',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 1,
                        height: 12,
                        color: Colors.white24,
                      ),
                      const SizedBox(width: 10),
                      const _LegendBadge(color: Colors.blueAccent, label: 'Base A'),
                      const SizedBox(width: 8),
                      const _LegendBadge(color: Colors.orangeAccent, label: 'Base B'),
                      const SizedBox(width: 8),
                      const _LegendBadge(color: Colors.purpleAccent, label: 'Base C'),
                      const SizedBox(width: 8),
                      const _LegendBadge(color: Colors.tealAccent, label: 'Rover'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _LegendBadge extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
        ),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.isActive,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? Colors.tealAccent.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? Colors.tealAccent.withOpacity(0.5) : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? Colors.tealAccent : Colors.white38,
          ),
        ),
      ),
    );
  }
}
