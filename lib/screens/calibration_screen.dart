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
  late double _gpsAccuracyThreshold;
  late double _gpsMinDisplacement;
  late double _gpsMaxSpeed;
  late double _bleMinRssiThreshold;
  late bool _bleEnforceMacWhitelist;
  late bool _bleStrictPayload;

  @override
  void initState() {
    super.initState();
    final state = context.read<SurveyState>();
    _txPower = state.txPowerAt1m;
    _pathLossExp = state.pathLossExponent;
    _gpsAccuracyThreshold = state.gpsAccuracyThreshold;
    _gpsMinDisplacement = state.gpsMinDisplacement;
    _gpsMaxSpeed = state.gpsMaxSpeed;
    _bleMinRssiThreshold = state.bleMinRssiThreshold;
    _bleEnforceMacWhitelist = state.bleEnforceMacWhitelist;
    _bleStrictPayload = state.bleStrictPayloadValidation;
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
    final gpsStats = state.gpsStats;
    final bleStats = state.bleFilterStats;

    return Scaffold(
      backgroundColor: const Color(0xFF0F131D),
      appBar: AppBar(
        title: const Text('Kalibrasi & Filter Sinyal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================================
            // SEKSI 1: FILTER MODUL LOKASI / GPS (ANTI-SCATTERING & DRIFT)
            // ==========================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gps_fixed, color: Colors.tealAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '1. FILTER LOKASI / GPS (ANTI-SCATTERING)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Penyaringan sensor GPS terhadap drift alami, penumpukan titik saat diam, dan outlier lonjakan koordinat.',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const Divider(color: Color(0xFF2E384D), height: 20),

                  // Accuracy Threshold Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Batas Akurasi (Accuracy Threshold):',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '≤ ${_gpsAccuracyThreshold.toStringAsFixed(1)} m',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _gpsAccuracyThreshold,
                    min: 2.0,
                    max: 15.0,
                    divisions: 26,
                    activeColor: Colors.tealAccent,
                    onChanged: (val) {
                      setState(() => _gpsAccuracyThreshold = val);
                      state.setGpsFilterSettings(accuracyThreshold: val);
                    },
                  ),
                  const Text(
                    'Abaikan pembaruan posisi jika akurasi GPS lebih buruk dari batas ini (rekomendasi: 5.0m).',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 12),

                  // Smallest Displacement Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Minimum Displacement (Perpindahan):',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '${_gpsMinDisplacement.toStringAsFixed(1)} m',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _gpsMinDisplacement,
                    min: 0.5,
                    max: 5.0,
                    divisions: 18,
                    activeColor: Colors.tealAccent,
                    onChanged: (val) {
                      setState(() => _gpsMinDisplacement = val);
                      state.setGpsFilterSettings(minDisplacement: val);
                    },
                  ),
                  const Text(
                    'setSmallestDisplacement(1.0f): Cegah penumpukan titik saat surveyor sedang diam di satu tempat.',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 12),

                  // Outlier Speed Threshold Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Batas Kecepatan Wajar (Outlier Rejection):',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '${_gpsMaxSpeed.toStringAsFixed(1)} m/s (${(_gpsMaxSpeed * 3.6).toStringAsFixed(1)} km/j)',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _gpsMaxSpeed,
                    min: 2.0,
                    max: 8.0,
                    divisions: 12,
                    activeColor: Colors.tealAccent,
                    onChanged: (val) {
                      setState(() => _gpsMaxSpeed = val);
                      state.setGpsFilterSettings(maxSpeedThreshold: val);
                    },
                  ),
                  const Text(
                    'Hitung delta jarak/waktu dari titik sebelumnya. Tolak koordinat yang melompat puluhan meter seketika.',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 14),

                  // Live GPS Diagnostics Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10141E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF283246)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistik Live Filter GPS:',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Titik Diterima Presisi: ${gpsStats.acceptedCount}',
                                style: const TextStyle(
                                    color: Colors.greenAccent, fontSize: 10)),
                            Text('Ditolak Akurasi Buruk (>5m): ${gpsStats.rejectedLowAccuracyCount}',
                                style: const TextStyle(
                                    color: Colors.orangeAccent, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ditolak Posisi Diam (<1m): ${gpsStats.rejectedStationaryCount}',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 10)),
                            Text('Ditolak Lonjakan Outlier: ${gpsStats.rejectedOutlierCount}',
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================================
            // SEKSI 2: FILTER TRILATERASI BLE (ANTI-DETEKSI PERANGKAT ASING)
            // ==========================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bluetooth_searching,
                          color: Colors.orangeAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '2. FILTER TRILATERASI & ANTI-HP ASING',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mencegah scanner menangkap sinyal broadcasting dari smartphone modern atau beacon lain di sekitar.',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const Divider(color: Color(0xFF2E384D), height: 20),

                  // RSSI Cutoff Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Batas Kekuatan Sinyal (Cutoff RSSI):',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '≥ ${_bleMinRssiThreshold.toStringAsFixed(0)} dBm',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _bleMinRssiThreshold,
                    min: -95.0,
                    max: -60.0,
                    divisions: 35,
                    activeColor: Colors.orangeAccent,
                    onChanged: (val) {
                      setState(() => _bleMinRssiThreshold = val);
                      state.setBleFilterSettings(minRssiThreshold: val);
                    },
                  ),
                  const Text(
                    'Buang hasil scan yang nilai RSSI-nya terlalu lemah (misal < -80 dBm) di luar jarak efektif trilaterasi.',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 12),

                  // MAC Whitelist Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enforce MAC Address Whitelist',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Hanya proses sinyal dari MAC Address Anchor yang terdaftar di sistem.',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                    value: _bleEnforceMacWhitelist,
                    activeColor: Colors.orangeAccent,
                    onChanged: (val) {
                      setState(() => _bleEnforceMacWhitelist = val);
                      state.setBleFilterSettings(enforceMacWhitelist: val);
                    },
                  ),

                  // Strict Payload Parser Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Validasi Format Byte Payload Telemetri',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Drop segera data broadcasting jika byte array bukan format resmi alat TopoSurvey.',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                    value: _bleStrictPayload,
                    activeColor: Colors.orangeAccent,
                    onChanged: (val) {
                      setState(() => _bleStrictPayload = val);
                      state.setBleFilterSettings(strictPayloadValidation: val);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Live BLE Diagnostics Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10141E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF283246)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistik Filter Sinyal BLE:',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Paket Valid Alat: ${bleStats.validPacketsCount}',
                                style: const TextStyle(
                                    color: Colors.greenAccent, fontSize: 10)),
                            Text('Dibuang Sinyal Lemah (<-80): ${bleStats.droppedWeakRssiCount}',
                                style: const TextStyle(
                                    color: Colors.orangeAccent, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Dibuang Bukan Whitelist: ${bleStats.droppedNonWhitelistedCount}',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 10)),
                            Text('Dibuang HP Liar / Format Asing: ${bleStats.droppedInvalidPayloadCount}',
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================================
            // SEKSI 3: KALIBRASI RADIUS BLE & KOEFISIEN LINGKUNGAN (A & n)
            // ==========================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2E384D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, color: Colors.tealAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '3. KALIBRASI REDAMAN PROPAGASI RADIO (A & n)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Jarak = 10 ^ ((A - RSSI) / (10 * n))\n'
                    '• Nilai A: RSSI tepat pada 1 meter.\n'
                    '• Nilai n: Koefisien redaman tanah/lingkungan (2.0 - 2.8).',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Step 1: 1 Meter Calibration
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2230),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kalibrasi Jarak 1 Meter (Nilai A)',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pegang HP Rover tepat 1m dari Base A:',
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'RSSI Base A: ${state.liveRssi["ANCHOR_A"]?.toStringAsFixed(1) ?? "--"} dBm',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              onPressed: () => _calibrateAt1m(state),
                              child: const Text('Simpan Nilai A',
                                  style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Step 2: 3 Meters Environmental Path Loss
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2230),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kalibrasi Redaman Kontur (Nilai n)',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Mundur tepat 3m dari Base A, lalu kalkulasi:',
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(38),
                          ),
                          onPressed: () =>
                              _calibrateAtKnownDistance(state, 3.0),
                          child: const Text('Hitung n pada Jarak 3.0m',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Manual Sliders
                  Text(
                    'Parameter A (TxPower @ 1m): ${_txPower.toStringAsFixed(1)} dBm',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Slider(
                    value: _txPower,
                    min: -80.0,
                    max: -40.0,
                    divisions: 80,
                    activeColor: Colors.tealAccent,
                    onChanged: (val) {
                      setState(() => _txPower = val);
                      state.setCalibration(
                          txPower: _txPower, exponent: _pathLossExp);
                    },
                  ),

                  Text(
                    'Path Loss Exponent (n): ${_pathLossExp.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Slider(
                    value: _pathLossExp,
                    min: 1.5,
                    max: 3.5,
                    divisions: 40,
                    activeColor: Colors.orangeAccent,
                    onChanged: (val) {
                      setState(() => _pathLossExp = val);
                      state.setCalibration(
                          txPower: _txPower, exponent: _pathLossExp);
                    },
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF2E384D)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _txPower = -59.0;
                        _pathLossExp = 2.2;
                      });
                      state.setCalibration(txPower: -59.0, exponent: 2.2);
                    },
                    child: const Text('Reset Parameter Radio ke Default (A=-59, n=2.2)',
                        style: TextStyle(fontSize: 11)),
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
