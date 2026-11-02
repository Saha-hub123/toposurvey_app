import 'anchor_node.dart';
import 'survey_point.dart';

class SurveyProject {
  final String id;
  final String name;
  final String surveyorName;
  final String description;
  final DateTime createdAt;
  final List<AnchorNode> anchors;
  final List<SurveyPoint> points;
  double txPowerAt1m; // BLE TxPower RSSI at 1 meter (dBm)
  double pathLossExponent; // Environmental path loss exponent n (default 2.2)

  SurveyProject({
    required this.id,
    required this.name,
    this.surveyorName = 'Surveyor Team',
    this.description = 'Topographic survey with 3+ Android cooperative anchors',
    DateTime? createdAt,
    List<AnchorNode>? anchors,
    List<SurveyPoint>? points,
    this.txPowerAt1m = -59.0,
    this.pathLossExponent = 2.2,
  })  : createdAt = createdAt ?? DateTime.now(),
        anchors = anchors ?? [],
        points = points ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'surveyorName': surveyorName,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'anchors': anchors.map((a) => a.toJson()).toList(),
        'points': points.map((p) => p.toJson()).toList(),
        'txPowerAt1m': txPowerAt1m,
        'pathLossExponent': pathLossExponent,
      };

  factory SurveyProject.fromJson(Map<String, dynamic> json) => SurveyProject(
        id: json['id'] as String,
        name: json['name'] as String,
        surveyorName: json['surveyorName'] as String? ?? 'Surveyor Team',
        description: json['description'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        anchors: (json['anchors'] as List<dynamic>?)
                ?.map((a) => AnchorNode.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        points: (json['points'] as List<dynamic>?)
                ?.map((p) => SurveyPoint.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        txPowerAt1m: (json['txPowerAt1m'] as num?)?.toDouble() ?? -59.0,
        pathLossExponent: (json['pathLossExponent'] as num?)?.toDouble() ?? 2.2,
      );
}
