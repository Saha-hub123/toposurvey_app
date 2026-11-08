import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/survey_state.dart';
import 'rover_survey_screen.dart';
import 'anchor_screen.dart';
import 'map_contour_screen.dart';
import 'project_list_screen.dart';
import 'calibration_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SurveyState>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.terrain, color: Colors.tealAccent),
            SizedBox(width: 10),
            Text(
              'TopoSurvey 3D',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kalibrasi BLE & Lingkungan',
            icon: const Icon(Icons.tune, color: Colors.tealAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalibrationScreen()),
              );
            },
          ),
          IconButton(
            tooltip: state.isSimulating ? 'Matikan Simulasi' : 'Jalankan Simulasi Lapangan',
            icon: Icon(
              state.isSimulating ? Icons.stop_circle : Icons.play_circle_fill,
              color: state.isSimulating ? Colors.redAccent : Colors.tealAccent,
            ),
            onPressed: () {
              state.toggleSimulation();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.isSimulating
                        ? 'Simulasi Topografi Aktif: Mengemulasi pergerakan Rover di kontur tanah'
                        : 'Simulasi Dihentikan',
                  ),
                  duration: const Duration(seconds: 2),
                ),
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
            // Project Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B2433), Color(0xFF131A26)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          state.projectName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: state.isSimulating
                              ? Colors.purple.withOpacity(0.3)
                              : Colors.tealAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          state.isSimulating ? 'SIMULASI AKTIF' : 'METODE 3+ HP',
                          style: TextStyle(
                            color: state.isSimulating
                                ? Colors.purpleAccent
                                : Colors.tealAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Surveyor: ${state.surveyorName} • Barometer: ${state.isBarometerAvailable ? "Tersedia (Akurasi Sub-Meter)" : "Fallback GPS"}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mode Selector
            const Text(
              'PILIH PERAN HANDPHONE INI:',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _RoleCard(
                    title: 'ROVER (Alat Ukur)',
                    subtitle: 'HP bergerak dibawa surveyor untuk menembak titik kontur permukaan',
                    icon: Icons.person_pin_circle,
                    isSelected: state.currentRole == DeviceRole.rover,
                    onTap: () => state.setRole(DeviceRole.rover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleCard(
                    title: 'ANCHOR (Patok Tetap)',
                    subtitle: 'HP ditaruh di tripod sebagai Base A, B, atau C pemancar trilaterasi',
                    icon: Icons.cell_tower,
                    isSelected: state.currentRole == DeviceRole.anchor,
                    onTap: () => state.setRole(DeviceRole.anchor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Action Buttons depending on role
            if (state.currentRole == DeviceRole.rover) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow, size: 26),
                label: const Text(
                  'MULAI SURVEY TOPOGRAFI (ROVER)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RoverSurveyScreen()),
                  );
                },
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.podcasts, size: 26),
                label: const Text(
                  'ATUR BASE STATION (ANCHOR A/B/C)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnchorScreen()),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),

            // Secondary Quick Actions (Map & Table)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF2E384D)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.map, color: Colors.tealAccent),
                    label: const Text('Peta 3D & Kontur'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MapContourScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF2E384D)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.sync_alt,
                        color: Colors.tealAccent),
                    label: Text('Data Titik (${state.surveyPoints.length})'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProjectListScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Base Anchors Status Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF171B26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2E384D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.hub, color: Colors.tealAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Konfigurasi 3 Base Station (Anchors)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...state.anchors.map((a) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              a.name,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '(${a.x.toStringAsFixed(1)}, ${a.y.toStringAsFixed(1)}, Z=${a.z.toStringAsFixed(1)}m)',
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A3338) : const Color(0xFF161B26),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.tealAccent : const Color(0xFF2C3345),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.tealAccent : Colors.white60,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.tealAccent : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
