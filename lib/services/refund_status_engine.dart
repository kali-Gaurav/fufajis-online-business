import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/refund_request_model.dart';
import 'order_status_engine.dart'; // To reuse UnauthorizedWorkflowException if needed

class InvalidRefundTransitionException implements Exception {
  final String from;
  final String to;
  final String message;

  InvalidRefundTransitionException({
    required this.from,
    required this.to,
    String? customMessage,
  }) : message = customMessage ?? 'Invalid transition from $from to $to';

  @override
  String toString() => message;
}

class RefundStatusEngine {
  static final RefundStatusEngine _instance = RefundStatusEngine._internal();
  factory RefundStatusEngine() => _instance;
  RefundStatusEngine._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ──────────────────────────────────────────────────────────────
  // STATE TRANSITION RULES
  // ──────────────────────────────────────────────────────────────
  static final Map<RefundStatus, Set<RefundStatus>> _validTransitions = {
    RefundStatus.pending: {RefundStatus.approved, RefundStatus.failed},
    RefundStatus.approved: {RefundStatus.processing, RefundStatus.failed},
    RefundStatus.processing: {RefundStatus.completed, RefundStatus.failed},
    RefundStatus.completed: {}, // Terminal
    RefundStatus.failed: {RefundStatus.pending}, // Can retry
  };

  // ──────────────────────────────────────────────────────────────
  // ROLE-BASED ACCESS CONTROL (RBAC) RULES
  // ──────────────────────────────────────────────────────────────
  static final Map<RefundStatus, List<String>> _allowedRolesForState = {
    RefundStatus.pending: ['customer', 'admin', 'manager', 'support'], // Anyone can create a pending refund
    RefundStatus.approved: ['admin', 'manager'], // Only manager/admin can approve
    RefundStatus.processing: ['admin', 'manager', 'finance', 'system'], // Finance or system picks it up
    RefundStatus.completed: ['admin', 'finance', 'system'], // System/Finance finalizes
    RefundStatus.failed: ['admin', 'system', 'finance'],
  };

  /// Validates a status transition and role permissions
  void validateTransition(RefundStatus from, RefundStatus to, String actorRole) {
    if (from == to) return;

    final validNext = _validTransitions[from];
    if (validNext == null || !validNext.contains(to)) {
      throw InvalidRefundTransitionException(from: from.name, to: to.name);
    }

    final allowedRoles = _allowedRolesForState[to] ?? [];
    if (!allowedRoles.contains(actorRole.toLowerCase()) && 
        actorRole.toLowerCase() != 'admin' && 
        actorRole.toLowerCase() != 'super_admin') {
      throw UnauthorizedWorkflowException(
        role: actorRole,
        transition: '${from.name} → ${to.name}',
        customMessage: 'Role $actorRole is not authorized to transition refund to ${to.name}.',
      );
    }
  }

  /// Transitions a refund request to a new status
  Future<void> transitionRefundStatus({
    required String refundId,
    required RefundStatus newStatus,
    required String actorId,
    required String actorRole,
    String? reason,
  }) async {
    try {
      final docRef = _db.collection('refund_requests').doc(refundId);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Refund request $refundId not found');
        }

        final data = snapshot.data()!;
        final currentStatusStr = data['status'] as String? ?? 'pending';
        final currentStatus = RefundStatus.values.firstWhere(
          (e) => e.name == currentStatusStr,
          orElse: () => RefundStatus.pending,
        );

        validateTransition(currentStatus, newStatus, actorRole);

        final updateData = <String, dynamic>{
          'status': newStatus.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': actorId,
        };

        if (newStatus == RefundStatus.approved) {
          updateData['approvedBy'] = actorId;
        }

        if (newStatus == RefundStatus.completed || newStatus == RefundStatus.failed) {
          updateData['processedAt'] = FieldValue.serverTimestamp();
        }

        transaction.update(docRef, updateData);

        // Also write to an audit log for refund transitions
        final auditRef = _db.collection('refund_audit_logs').doc();
        transaction.set(auditRef, {
          'refundId': refundId,
          'fromStatus': currentStatus.name,
          'toStatus': newStatus.name,
          'actorId': actorId,
          'actorRole': actorRole,
          'reason': reason ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('[RefundStatusEngine] Refund $refundId transitioned to ${newStatus.name} by $actorRole');
    } catch (e) {
      debugPrint('[RefundStatusEngine] Transition failed: $e');
      rethrow;
    }
  }
}
