import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/automation_rule_model.dart';
import 'audit_service.dart';

/// CRUD + querying for owner-configured automation/workflow rules.
/// The actual rule evaluation/execution happens server-side in
/// functions/automation_rules_engine.js — this service only manages the
/// rule documents in `automation_rules`.
class AutomationRuleService {
  static final AutomationRuleService _instance = AutomationRuleService._internal();
  factory AutomationRuleService() => _instance;
  AutomationRuleService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AutomationRuleModel>> watchRules() {
    return _db
        .collection('automation_rules')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => AutomationRuleModel.fromMap(doc.data(), doc.id)).toList(),
        );
  }

  Future<AutomationRuleModel?> getRule(String id) async {
    final doc = await _db.collection('automation_rules').doc(id).get();
    if (!doc.exists) return null;
    return AutomationRuleModel.fromMap(doc.data()!, doc.id);
  }

  Future<String> createRule(AutomationRuleModel rule, String adminId, String adminName) async {
    final docRef = await _db.collection('automation_rules').add(rule.toMap());

    await AuditService().logAction(
      userId: adminId,
      userName: adminName,
      action: AuditAction.adminAction,
      description: 'Created automation rule: ${rule.name}',
      targetId: docRef.id,
      metadata: {'trigger': rule.triggerType.wireValue},
    );

    return docRef.id;
  }

  Future<void> updateRule(AutomationRuleModel rule, String adminId, String adminName) async {
    await _db.collection('automation_rules').doc(rule.id).update(rule.toMap());

    await AuditService().logAction(
      userId: adminId,
      userName: adminName,
      action: AuditAction.adminAction,
      description: 'Updated automation rule: ${rule.name}',
      targetId: rule.id,
    );
  }

  Future<void> setEnabled(String id, bool enabled, String adminId, String adminName) async {
    await _db.collection('automation_rules').doc(id).update({'enabled': enabled});

    await AuditService().logAction(
      userId: adminId,
      userName: adminName,
      action: AuditAction.adminAction,
      description: '${enabled ? 'Enabled' : 'Disabled'} automation rule',
      targetId: id,
    );
  }

  Future<void> deleteRule(String id, String adminId, String adminName) async {
    await _db.collection('automation_rules').doc(id).delete();

    await AuditService().logAction(
      userId: adminId,
      userName: adminName,
      action: AuditAction.adminAction,
      description: 'Deleted automation rule',
      targetId: id,
    );
  }

  /// Recent execution log entries for a rule (most recent first).
  Stream<List<Map<String, dynamic>>> watchRuleLogs(String ruleId, {int limit = 20}) {
    return _db
        .collection('automation_rule_logs')
        .where('ruleId', isEqualTo: ruleId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((e) {
          debugPrint('[AutomationRuleService] watchRuleLogs error: $e');
          return <Map<String, dynamic>>[];
        });
  }
}
