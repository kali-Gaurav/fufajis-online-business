import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/shop_model.dart';
import 'order_status_engine.dart'; // To reuse UnauthorizedWorkflowException

class InvalidVendorApprovalTransitionException implements Exception {
  final String from;
  final String to;
  final String message;

  InvalidVendorApprovalTransitionException({
    required this.from,
    required this.to,
    String? customMessage,
  }) : message = customMessage ?? 'Invalid transition from $from to $to';

  @override
  String toString() => message;
}

class VendorApprovalEngine {
  static final VendorApprovalEngine _instance = VendorApprovalEngine._internal();
  factory VendorApprovalEngine() => _instance;
  VendorApprovalEngine._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ──────────────────────────────────────────────────────────────
  // STATE TRANSITION RULES
  // ──────────────────────────────────────────────────────────────
  static final Map<ShopApprovalStatus, Set<ShopApprovalStatus>> _validTransitions = {
    ShopApprovalStatus.draft: {ShopApprovalStatus.under_review},
    ShopApprovalStatus.under_review: {ShopApprovalStatus.approved, ShopApprovalStatus.rejected},
    ShopApprovalStatus.approved: {ShopApprovalStatus.rejected}, // Can be revoked
    ShopApprovalStatus.rejected: {ShopApprovalStatus.under_review}, // Can appeal/re-apply
  };

  // ──────────────────────────────────────────────────────────────
  // ROLE-BASED ACCESS CONTROL (RBAC) RULES
  // ──────────────────────────────────────────────────────────────
  static final Map<ShopApprovalStatus, List<String>> _allowedRolesForState = {
    ShopApprovalStatus.draft: ['shop_owner', 'admin', 'manager'], 
    ShopApprovalStatus.under_review: ['shop_owner', 'admin', 'manager'], // Owner submits for review
    ShopApprovalStatus.approved: ['admin', 'super_admin'], // Only Admin can approve
    ShopApprovalStatus.rejected: ['admin', 'super_admin'], // Only Admin can reject
  };

  /// Validates a status transition and role permissions
  void validateTransition(ShopApprovalStatus from, ShopApprovalStatus to, String actorRole) {
    if (from == to) return;

    final validNext = _validTransitions[from];
    if (validNext == null || !validNext.contains(to)) {
      throw InvalidVendorApprovalTransitionException(from: from.name, to: to.name);
    }

    final allowedRoles = _allowedRolesForState[to] ?? [];
    if (!allowedRoles.contains(actorRole.toLowerCase()) && 
        actorRole.toLowerCase() != 'admin' && 
        actorRole.toLowerCase() != 'super_admin') {
      throw UnauthorizedWorkflowException(
        role: actorRole,
        transition: '${from.name} → ${to.name}',
        customMessage: 'Role $actorRole is not authorized to transition vendor approval to ${to.name}.',
      );
    }
  }

  /// Transitions a shop approval status
  Future<void> transitionApprovalStatus({
    required String shopId,
    required ShopApprovalStatus newStatus,
    required String actorId,
    required String actorRole,
    String? reason,
  }) async {
    try {
      final docRef = _db.collection('shops').doc(shopId);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Shop $shopId not found');
        }

        final data = snapshot.data()!;
        final currentStatusStr = data['approvalStatus'] as String? ?? 'approved';
        final currentStatus = ShopApprovalStatus.values.firstWhere(
          (e) => e.name == currentStatusStr,
          orElse: () => ShopApprovalStatus.approved,
        );

        validateTransition(currentStatus, newStatus, actorRole);

        final updateData = <String, dynamic>{
          'approvalStatus': newStatus.name,
          'active': newStatus == ShopApprovalStatus.approved,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (newStatus == ShopApprovalStatus.approved || newStatus == ShopApprovalStatus.rejected) {
          updateData['reviewedBy'] = actorId;
          updateData['reviewReason'] = reason;
          updateData['reviewedAt'] = FieldValue.serverTimestamp();
        }

        transaction.update(docRef, updateData);

        // Also write to an audit log for vendor transitions
        final auditRef = _db.collection('vendor_approval_logs').doc();
        transaction.set(auditRef, {
          'shopId': shopId,
          'fromStatus': currentStatus.name,
          'toStatus': newStatus.name,
          'actorId': actorId,
          'actorRole': actorRole,
          'reason': reason ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('[VendorApprovalEngine] Shop $shopId transitioned to ${newStatus.name} by $actorRole');
    } catch (e) {
      debugPrint('[VendorApprovalEngine] Transition failed: $e');
      rethrow;
    }
  }
}
