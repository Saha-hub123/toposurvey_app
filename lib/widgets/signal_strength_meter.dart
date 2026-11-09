import 'package:flutter/material.dart';
import '../models/anchor_node.dart';

class SignalStrengthMeter extends StatelessWidget {
  final List<AnchorNode> anchors;
  final Map<String, double> liveDistances;
  final Map<String, double> liveRssi;

  const SignalStrengthMeter({
    super.key,
    required this.anchors,
    required this.liveDistances,
    required this.liveRssi,
  });

  @override
  Widget build(BuildContext context) {
    final activeCount = liveDistances.length;
    final isReadyForSurvey = activeCount >= 2;

    String statusText;
    if (activeCount >= 3) {
      statusText = '$activeCount/${anchors.length} Base (Optimal)';
    } else if (activeCount == 2) {
      statusText = '2 Base (Mode 3 HP Aktif)';
    } else {
      statusText = '$activeCount/${anchors.length} Terhubung';
    }

    return Card(
      color: const Color(0xFF1E222D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bluetooth_audio,
                        color: Colors.tealAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Sinyal Patok Base BLE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isReadyForSurvey
                        ? Colors.green.withOpacity(0.18)
                        : Colors.orange.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isReadyForSurvey
                          ? Colors.greenAccent.withOpacity(0.4)
                          : Colors.orangeAccent.withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: isReadyForSurvey
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...anchors.map((anchor) {
              final dist = liveDistances[anchor.id];
              final rssi = liveRssi[anchor.id];
              final isConnected = dist != null;

              Color statusColor = Colors.grey;
              if (isConnected) {
                if (dist < 10.0) {
                  statusColor = Colors.greenAccent;
                } else if (dist < 25.0) {
                  statusColor = Colors.amberAccent;
                } else {
                  statusColor = Colors.orangeAccent;
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: isConnected
                            ? [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        anchor.id.replaceAll('ANCHOR_', 'BASE '),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        isConnected
                            ? '${rssi?.toStringAsFixed(0) ?? "--"} dBm'
                            : 'Mencari sinyal...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        isConnected ? '${dist.toStringAsFixed(2)} m' : '-- m',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
