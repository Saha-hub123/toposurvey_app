import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/survey_state.dart';

class AnchorScreen extends StatefulWidget {
  const AnchorScreen({super.key});

  @override
  State<AnchorScreen> createState() => _AnchorScreenState();
}

class _AnchorScreenState extends State<AnchorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _xController;
  late TextEditingController _yController;
  late TextEditingController _zController;

  @override
  void initState() {
    super.initState();
    final state = context.read<SurveyState>();
    final anchor = state.anchors.firstWhere(
      (a) => a.id == state.selectedAnchorId,
      orElse: () => state.anchors.first,
    );

    _nameController = TextEditingController(text: anchor.name);
    _xController = TextEditingController(text: anchor.x.toStringAsFixed(2));
    _yController = TextEditingController(text: anchor.y.toStringAsFixed(2));
    _zController = TextEditingController(text: anchor.z.toStringAsFixed(2));
  }

  void _loadAnchorData(String anchorId) {
    final state = context.read<SurveyState>();
    final anchor = state.anchors.firstWhere(
      (a) => a.id == anchorId,
      orElse: () => state.anchors.first,
    );

    _nameController.text = anchor.name;
    _xController.text = anchor.x.toStringAsFixed(2);
    _yController.text = anchor.y.toStringAsFixed(2);
    _zController.text = anchor.z.toStringAsFixed(2);
  }

  void _saveCoordinates(SurveyState state) {
    final x = double.tryParse(_xController.text) ?? 0.0;
    final y = double.tryParse(_yController.text) ?? 0.0;
    final z = double.tryParse(_zController.text) ?? 100.0;
    final name = _nameController.text.trim();

    state.updateAnchorCoordinates(
      state.selectedAnchorId,
      x: x,
      y: y,
      z: z,
      name: name.isNotEmpty ? name : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Koordinat ${state.selectedAnchorId} diperbarui: ($x, $y, $z)',
        ),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _zController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SurveyState>();
    final currentAnchor = state.anchors.firstWhere(
      (a) => a.id == state.selectedAnchorId,
      orElse: () => state.anchors.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      appBar: AppBar(
        title: const Text('Pengaturan Base Station (Anchor)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2433),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.cell_tower,
                    color: Colors.orangeAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'BASE STATION AKTIF: ${currentAnchor.id}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Handphone ini memancarkan sinyal BLE Beacon dan UDP Mesh ke Rover',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.radio_button_checked,
                            color: Colors.greenAccent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Tekanan Barometer: ${state.liveRoverPressure?.toStringAsFixed(2) ?? "1013.25"} hPa',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Select Which Anchor This Phone Represents
            const Text(
              'PILIH POSISI PATOK UNTUK HP INI:',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: state.anchors.map((a) {
                final isSelected = state.selectedAnchorId == a.id;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Colors.orangeAccent.withOpacity(0.2)
                            : const Color(0xFF161B26),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.orangeAccent
                              : const Color(0xFF2E384D),
                          width: isSelected ? 2 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        state.setSelectedAnchorId(a.id);
                        _loadAnchorData(a.id);
                      },
                      child: Text(
                        a.id.replaceAll('ANCHOR_', 'BASE '),
                        style: TextStyle(
                          color: isSelected ? Colors.orangeAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Coordinate Inputs
            const Text(
              'KOORDINAT PATOK ACUAN (GRID LOKAL / BENCHMARK):',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Nama Patok / Identitas Base',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF161B26),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _xController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'X (Easting) m',
                      labelStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Color(0xFF161B26),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _yController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Y (Northing) m',
                      labelStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Color(0xFF161B26),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _zController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Z (Elevasi) m',
                      labelStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Color(0xFF161B26),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Auto GPS Button & Save
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.tealAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.my_location,
                        color: Colors.tealAccent),
                    label: const Text('Ambil GPS Patok Ini'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await state
                          .calibrateAnchorFromGps(state.selectedAnchorId);
                      if (!mounted) return;
                      if (ok) {
                        _loadAnchorData(state.selectedAnchorId);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Koordinat GPS & Ketinggian berhasil dicatat ke Patok!'),
                            backgroundColor: Colors.teal,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text(
                      'SIMPAN',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _saveCoordinates(state),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Field Instruction Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141822),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E384D)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.tealAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Petunjuk Penggelaran 3 HP di Lapangan:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Letakkan HP 1 sebagai Base A (Origin 0,0, Z acuan).\n'
                    '2. Letakkan HP 2 sebagai Base B (misal 15m ke timur).\n'
                    '3. Letakkan HP 3 sebagai Base C (misal 15m ke utara membentuk segitiga).\n'
                    '4. Hidupkan Portable Hotspot pada salah satu HP agar ketiga HP saling terhubung secara offline.\n'
                    '5. Bawa HP ke-4 (atau Rover) untuk menembak titik-titik kontur permukaan.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
