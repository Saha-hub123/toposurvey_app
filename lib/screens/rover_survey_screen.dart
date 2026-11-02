import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/survey_state.dart';
import '../widgets/signal_strength_meter.dart';
import '../widgets/topo_canvas.dart';
import 'map_contour_screen.dart';

class RoverSurveyScreen extends StatefulWidget {
  const RoverSurveyScreen({super.key});

  @override
  State<RoverSurveyScreen> createState() => _RoverSurveyScreenState();
}

class _RoverSurveyScreenState extends State<RoverSurveyScreen> {
  String _selectedCode = 'KONTUR';
  final TextEditingController _noteController = TextEditingController();

  final List<String> _codes = [
    'KONTUR',
    'TANAH',
    'PARIT',
    'PUNCAK',
    'LEMBAH',
    'JALAN',
    'BATAS',
    'POHON',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<SurveyState>();
      if (!state.isScanning && !state.isSimulating) {
        state.startSurvey();
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _recordPoint(SurveyState state) {
    if (state.currentPositionResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum mendapatkan fix trilaterasi! Pastikan minimal 3 Anchor terhubung.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final point = state.recordCurrentPoint(
      code: _selectedCode,
      note: _noteController.text.trim(),
    );

    if (point != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Titik #${point.pointNumber} [$_selectedCode] Z=${point.z.toStringAsFixed(2)}m tersimpan!',
          ),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 1),
        ),
      );
      _noteController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SurveyState>();
    final pos = state.currentPositionResult;
    final anchorA = state.anchors.firstWhere((a) => a.id == 'ANCHOR_A');

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      appBar: AppBar(
        title: const Text('Survey Rover (Alat Ukur)'),
        actions: [
          IconButton(
            tooltip: 'Buka Peta Topografi Penuh',
            icon: const Icon(Icons.fullscreen, color: Colors.tealAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapContourScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Elevation & Coordinates Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF161C28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: pos != null && pos.isAccurate
                      ? Colors.tealAccent
                      : Colors.orangeAccent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.landscape,
                            color: pos != null
                                ? Colors.tealAccent
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'KETINGGIAN PERMUKAAN (Z):',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: pos != null && pos.isAccurate
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pos != null
                              ? 'Akurasi: ±${pos.residualError.toStringAsFixed(2)}m'
                              : 'Menunggu 3 Anchor...',
                          style: TextStyle(
                            color: pos != null && pos.isAccurate
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pos != null ? '${pos.z.toStringAsFixed(2)} m' : '--.-- m',
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    pos != null
                        ? 'Delta Relatif Base A: ${(pos.z - anchorA.z >= 0 ? "+" : "")}${(pos.z - anchorA.z).toStringAsFixed(2)} m'
                        : 'Delta Relatif: -- m',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                  const Divider(color: Color(0xFF2E384D), height: 24),

                  // Horizontal Coordinates X and Y
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'EASTING (X)',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pos != null
                                ? '${pos.x.toStringAsFixed(2)} m'
                                : '-- m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: const Color(0xFF2E384D),
                      ),
                      Column(
                        children: [
                          const Text(
                            'NORTHING (Y)',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pos != null
                                ? '${pos.y.toStringAsFixed(2)} m'
                                : '-- m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Feature Code Picker
            const Text(
              'KODE FITUR TOPOGRAFI:',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _codes.map((code) {
                final isSelected = _selectedCode == code;
                return ChoiceChip(
                  label: Text(code),
                  selected: isSelected,
                  selectedColor: Colors.tealAccent,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  backgroundColor: const Color(0xFF1B2230),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCode = code);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Note Input
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Catatan titik (misal: parit kanan, elevasi teras)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: const Color(0xFF161C28),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2E384D)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Big Record Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.add_location_alt, size: 28),
              label: Text(
                'TEMBAK TITIK KONTUR (#${state.surveyPoints.length + 1})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _recordPoint(state),
            ),
            const SizedBox(height: 18),

            // Signal Strength of 3+ Anchors
            SignalStrengthMeter(
              anchors: state.anchors,
              liveDistances: state.liveDistances,
              liveRssi: state.liveRssi,
            ),
            const SizedBox(height: 16),

            // Mini Topo Canvas Live Preview
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF131722),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2E384D)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: TopoCanvas(
                  anchors: state.anchors,
                  points: state.surveyPoints,
                  liveRover: state.currentPositionResult,
                  liveDistances: state.liveDistances,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
