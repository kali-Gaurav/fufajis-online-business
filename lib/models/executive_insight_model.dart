import 'package:cloud_firestore/cloud_firestore.dart';

class ExecutiveInsightModel {
  final String id;
  final String insightType; // e.g. "Revenue Analysis", "Stock Warning", "Customer Trend"
  final String summary;
  final List<String> primaryCauses;
  final DateTime timestamp;

  ExecutiveInsightModel({
    required this.id,
    required this.insightType,
    required this.summary,
    required this.primaryCauses,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'insightType': insightType,
      'summary': summary,
      'primaryCauses': primaryCauses,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ExecutiveInsightModel.fromMap(Map<String, dynamic> map, String docId) {
    return ExecutiveInsightModel(
      id: docId,
      insightType: map['insightType'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      primaryCauses: List<String>.from(map['primaryCauses'] as Iterable? ?? []),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
