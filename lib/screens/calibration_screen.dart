import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/survey_state.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late double _txPower;
  late double _pathLossExp;

  @override
  void initState() {
    super.initState();
    final state = context.read<SurveyState>();
    _txPower = state.txPowerAt1m;
    _pathLossExp = state.pathLossExponent;
  }

  void _calibrateAt1m(SurveyState state) {
    // Read the current RSSI of Anchor A
    final currentRssi = state.liveRssi['ANCHOR_A'];
    if (currentRssi != null) {
      setState(() {
        _txPower = currentRssi;
      });
      state.setCalibration(txPower: _txPower, exponent: _pathLossExp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A (TxPower pada 1m) berhasil diset ke ${_txPower.toStringAsFixed(1)} dBm'),
          backgroundColor: Colors.teal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada sinyal dari Anchor A! Dekatkan HP ke Anchor A.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  void _calibrateAtKnownDistance(SurveyState state, double knownDistanceMeters) {
    final currentRssi = state.liveRssi['ANCHOR_A'];
    if (currentRssi != null && knownDistanceMeters > 1.0) {
      // n = (A - RSSI) / (10 * log10(d))
      final delta = _txPower - currentRssi;
      final logDist = log(knownDistanceMeters) / ln10;
      final calculatedN = (delta / (10.0 * logDist)).clamp(1.5, 4.0);

      setState(() {
        _pathLossExp = calculatedN;
      });
      state.setCalibration(txPower: _txPower, exponent: _pathLossExp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Eksponen Redaman Lingkungan (n) dihitung: ${_pathLossExp.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SurveyState>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      appBar: AppBar(
        title: const Text('Kalibrasi BLE & Lingkungan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Theory explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2E384D)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science, color: Colors.tealAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Model Propagasi Log-Distance Lapangan:',
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
                    'Jarak = 10 ^ ((A - RSSI) / (10 * n))\n\n'
                    '• Parameter A: Kekuatan sinyal (dBm) tepat pada jarak 1 meter dari HP pemancar.\n'
                    '• Parameter n: Tingkat redaman gelombang radio oleh tanah, rumput, & atmosfer (biasanya 2.0 - 2.8).',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 1: 1 Meter Calibration
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2230),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LANGKAH 1: Kalibrasi Jarak 1 Meter (Nilai A)',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pegang HP Rover tepat 1 meter dari HP Base Anchor A, lalu tekan tombol di bawah:',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sinyal Saat Ini: ${state.liveRssi["ANCHOR_A"]?.toStringAsFixed(1) ?? "--"} dBm',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => _calibrateAt1m(state),
                        child: const Text('Simpan Nilai A'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 2: Environmental Path Loss (n) at 3 Meters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2230),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LANGKAH 2: Kalibrasi Koefisien Lingkungan (Nilai n)',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mundurlah tepat 3 meter dari Anchor A, lalu tekan tombol di bawah untuk menghitung redaman kontur tanah:',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed: () => _calibrateAtKnownDistance(state, 3.0),
                    child: const Text('Hitung n pada Jarak 3.0 Meter'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Manual Slider Adjustments
            const Text(
              'PENYESUAIAN MANUAL PARAMETER:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // TxPower Slider
            Text(
              'Parameter A (TxPower @ 1m): ${_txPower.toStringAsFixed(1)} dBm',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            Slider(
              value: _txPower,
              min: -80.0,
              max: -40.0,
              divisions: 80,
              activeColor: Colors.tealAccent,
              onChanged: (val) {
                setState(() => _txPower = val);
                state.setCalibration(txPower: _txPower, exponent: _pathLossExp);
              },
            ),

            // Path Loss Slider
            Text(
              'Path Loss Exponent (n): ${_pathLossExp.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            Slider(
              value: _pathLossExp,
              min: 1.5,
              max: 3.5,
              divisions: 40,
              activeColor: Colors.orangeAccent,
              onChanged: (val) {
                setState(() => _pathLossExp = val);
                state.setCalibration(txPower: _txPower, exponent: _pathLossExp);
              },
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF26334D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                setState(() {
                  _txPower = -59.0;
                  _pathLossExp = 2.2;
                });
                state.setCalibration(txPower: -59.0, exponent: 2.2);
              },
              child: const Text('Reset ke Pengaturan Default Terbuka (A=-59, n=2.2)'),
            ),
          ],
        ),
      ),
    );
  }
}
