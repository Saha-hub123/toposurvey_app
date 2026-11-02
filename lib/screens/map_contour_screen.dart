import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/survey_state.dart';
import '../widgets/topo_canvas.dart';

class MapContourScreen extends StatelessWidget {
  const MapContourScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SurveyState>();
    final points = state.surveyPoints;

    double minZ = 0.0, maxZ = 0.0;
    if (points.isNotEmpty) {
      minZ = points.map((p) => p.z).reduce(min);
      maxZ = points.map((p) => p.z).reduce(max);
    }
    final deltaZ = (maxZ - minZ).abs();

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      appBar: AppBar(
        title: const Text('Peta Topografi & Kontur 3D'),
        actions: [
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
                  value: points.isNotEmpty
                      ? '${minZ.toStringAsFixed(2)}m'
                      : '--',
                  color: Colors.cyanAccent,
                ),
                _StatItem(
                  label: 'ELEVASI MAX (Z)',
                  value: points.isNotEmpty
                      ? '${maxZ.toStringAsFixed(2)}m'
                      : '--',
                  color: Colors.deepOrangeAccent,
                ),
                _StatItem(
                  label: 'BEDA TINGGI (ΔZ)',
                  value: points.isNotEmpty
                      ? '${deltaZ.toStringAsFixed(2)}m'
                      : '--',
                  color: Colors.amberAccent,
                ),
              ],
            ),
          ),

          // Interactive InteractiveViewer for Canvas (Pinch zoom & pan)
          Expanded(
            child: Container(
              color: const Color(0xFF0C0E17),
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(80),
                minScale: 0.5,
                maxScale: 4.0,
                child: TopoCanvas(
                  anchors: state.anchors,
                  points: state.surveyPoints,
                  liveRover: state.currentPositionResult,
                  liveDistances: state.liveDistances,
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendBadge(color: Colors.blueAccent, label: 'Anchor A'),
                    SizedBox(width: 12),
                    _LegendBadge(color: Colors.orangeAccent, label: 'Anchor B'),
                    SizedBox(width: 12),
                    _LegendBadge(color: Colors.purpleAccent, label: 'Anchor C'),
                    SizedBox(width: 12),
                    _LegendBadge(color: Colors.tealAccent, label: 'Rover Aktif'),
                  ],
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
          width: 8,
          height: 8,
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
