import 'package:cloud_firestore/cloud_firestore.dart';

/// Autonomy tier for a given agent/tool combination.
/// - auto: agent executes immediately and logs the action
/// - approval: agent proposes, owner must approve before it executes
/// - advisory: recommendation only, never executes automatically
enum AgentAutonomyTier { auto, approval, advisory }

AgentAutonomyTier agentAutonomyTierFromString(String? value) {
  switch (value) {
    case 'auto':
      return AgentAutonomyTier.auto;
    case 'advisory':
      return AgentAutonomyTier.advisory;
    case 'approval':
    default:
      return AgentAutonomyTier.approval;
  }
}

enum AgentStatus { idle, working, waitingOwner, blocked, disabled }

AgentStatus agentStatusFromString(String? value) {
  switch (value) {
    case 'working':
      return AgentStatus.working;
    case 'waiting_owner':
      return AgentStatus.waitingOwner;
    case 'blocked':
      return AgentStatus.blocked;
    case 'disabled':
      return AgentStatus.disabled;
    case 'idle':
    default:
      return AgentStatus.idle;
  }
}

class AgentKpis {
  final int tasksDone;
  final double approvalRate;
  final double impactScore;

  const AgentKpis({this.tasksDone = 0, this.approvalRate = 0, this.impactScore = 0});

  factory AgentKpis.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AgentKpis();
    return AgentKpis(
      tasksDone: (map['tasksDone'] as num?)?.toInt() ?? 0,
      approvalRate: (map['approvalRate'] as num?)?.toDouble() ?? 0,
      impactScore: (map['impactScore'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Represents a single "employee" in the Mission Control / Karyalay
/// roster, backed by a doc in the `agents` collection.
class AgentModel {
  final String id;
  final String name;
  final String title;
  final String emoji;
  final String role;
  final bool enabled;
  final Map<String, AgentAutonomyTier> autonomyDefaults;
  final AgentStatus status;
  final String? currentTaskId;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final AgentKpis kpis;
  final String model;

  const AgentModel({
    required this.id,
    required this.name,
    required this.title,
    required this.emoji,
    required this.role,
    required this.enabled,
    required this.autonomyDefaults,
    required this.status,
    this.currentTaskId,
    this.lastRunAt,
    this.nextRunAt,
    required this.kpis,
    required this.model,
  });

  factory AgentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final autonomyMap = <String, AgentAutonomyTier>{};
    final rawAutonomy = data['autonomyDefaults'] as Map<String, dynamic>?;
    rawAutonomy?.forEach((key, value) {
      autonomyMap[key] = agentAutonomyTierFromString(value as String?);
    });

    return AgentModel(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      title: data['title'] as String? ?? doc.id,
      emoji: data['emoji'] as String? ?? '🤖',
      role: data['role'] as String? ?? '',
      enabled: data['enabled'] as bool? ?? false,
      autonomyDefaults: autonomyMap,
      status: agentStatusFromString(data['status'] as String?),
      currentTaskId: data['currentTaskId'] as String?,
      lastRunAt: (data['lastRunAt'] as Timestamp?)?.toDate(),
      nextRunAt: (data['nextRunAt'] as Timestamp?)?.toDate(),
      kpis: AgentKpis.fromMap(data['kpis'] as Map<String, dynamic>?),
      model: data['model'] as String? ?? 'gemini-1.5-flash',
    );
  }
}

/// agent_config/global - holds the master kill switch and runtime
/// guardrails (budget, frequency caps, quiet hours).
class AgentGlobalConfig {
  final bool masterEnabled;
  final double dailyBudgetUsd;
  final Map<String, dynamic> freqCaps;
  final Map<String, dynamic> quietHours;

  const AgentGlobalConfig({
    required this.masterEnabled,
    required this.dailyBudgetUsd,
    required this.freqCaps,
    required this.quietHours,
  });

  factory AgentGlobalConfig.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AgentGlobalConfig(
      masterEnabled: data['masterEnabled'] as bool? ?? false,
      dailyBudgetUsd: (data['dailyBudgetUsd'] as num?)?.toDouble() ?? 2,
      freqCaps: data['freqCaps'] as Map<String, dynamic>? ?? const {},
      quietHours: data['quietHours'] as Map<String, dynamic>? ?? const {},
    );
  }

  factory AgentGlobalConfig.empty() => const AgentGlobalConfig(
    masterEnabled: false,
    dailyBudgetUsd: 2,
    freqCaps: {},
    quietHours: {},
  );
}
