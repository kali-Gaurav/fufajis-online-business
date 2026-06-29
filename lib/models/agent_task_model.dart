import 'package:cloud_firestore/cloud_firestore.dart';
import 'agent_model.dart';

enum AgentTaskStatus {
  proposed,
  queued,
  awaitingApproval,
  approved,
  executing,
  done,
  rejected,
  failed,
  undone,
}

AgentTaskStatus agentTaskStatusFromString(String? value) {
  switch (value) {
    case 'queued':
      return AgentTaskStatus.queued;
    case 'awaiting_approval':
      return AgentTaskStatus.awaitingApproval;
    case 'approved':
      return AgentTaskStatus.approved;
    case 'executing':
      return AgentTaskStatus.executing;
    case 'done':
      return AgentTaskStatus.done;
    case 'rejected':
      return AgentTaskStatus.rejected;
    case 'failed':
      return AgentTaskStatus.failed;
    case 'undone':
      return AgentTaskStatus.undone;
    case 'proposed':
    default:
      return AgentTaskStatus.proposed;
  }
}

class AgentEvidenceItem {
  final String label;
  final String value;
  final String? ref;

  const AgentEvidenceItem({required this.label, required this.value, this.ref});

  factory AgentEvidenceItem.fromMap(Map<String, dynamic> map) {
    return AgentEvidenceItem(
      label: map['label']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      ref: map['ref'] as String?,
    );
  }
}

/// A single proposed/queued/completed unit of work from an agent,
/// backed by a doc in the `agent_tasks` collection.
class AgentTaskModel {
  final String id;
  final String agentId;
  final String title;
  final String description;
  final String type;
  final AgentAutonomyTier autonomy;
  final AgentTaskStatus status;
  final int priority;
  final double confidence;
  final String? impactEstimate;
  final String reasoning;
  final List<AgentEvidenceItem> evidence;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? result;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AgentTaskModel({
    required this.id,
    required this.agentId,
    required this.title,
    required this.description,
    required this.type,
    required this.autonomy,
    required this.status,
    required this.priority,
    required this.confidence,
    this.impactEstimate,
    required this.reasoning,
    required this.evidence,
    required this.payload,
    this.result,
    this.createdAt,
    this.updatedAt,
  });

  factory AgentTaskModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawEvidence = data['evidence'] as List<dynamic>? ?? const [];

    return AgentTaskModel(
      id: doc.id,
      agentId: data['agentId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      autonomy: agentAutonomyTierFromString(data['autonomy'] as String?),
      status: agentTaskStatusFromString(data['status'] as String?),
      priority: (data['priority'] as num?)?.toInt() ?? 50,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
      impactEstimate: data['impactEstimate'] as String?,
      reasoning: data['reasoning'] as String? ?? '',
      evidence: rawEvidence
          .whereType<Map<String, dynamic>>()
          .map(AgentEvidenceItem.fromMap)
          .toList(),
      payload: data['payload'] as Map<String, dynamic>? ?? const {},
      result: data['result'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isAwaitingApproval => status == AgentTaskStatus.awaitingApproval;
}
