// ============================================================
//  AuditService — Business-action audit trail (Firestore)
//
//  Collection: audit_logs
//  Purpose:    Track every business action by owners / admins.
//              Separate from security_events (threat monitoring).
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum AuditAction {
  // Auth
  login,
  logout,
  // Employee lifecycle
  employeeCreated,
  employeeRemoved,
  employeeRoleChanged,
  // Orders
  orderCancellation,
  refundApproved,
  refundRejected,
  // Pricing / Inventory
  priceUpdate,
  stockAdjustment,
  inventoryUpdate,
  // Security
  deviceApproved,
  deviceRevoked,
  sessionRevoked,
  // Customer finance
  walletAdjusted,
  codLimitChanged,
  couponCreated,
  couponDeactivated,
  // Admin / legacy
  roleChange,
  adminAction,
  securityAlert,
}

class AuditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  /// Write a single audit record. Fire-and-forget; errors never block
  /// the business action that triggered the log.
  Future<void> logAction({
    required String userId,
    required String userName,
    required AuditAction action,
    required String description,
    Map<String, dynamic>? metadata,
    String? targetId,     // orderId, employeeId, productId, etc.
    String? branchId,
  }) async {
    try {
      await _db.collection('audit_logs').add({
        'userId':      userId,
        'userName':    userName,
        'action':      action.name,
        'description': description,
        'targetId':    targetId,
        'branchId':    branchId,
        'metadata':    metadata,
        'timestamp':   FieldValue.serverTimestamp(),
      });
      debugPrint('[Audit] ${action.name} by $userName');
    } catch (e) {
      debugPrint('[Audit] ERROR: $e');
    }
  }

  // ── Convenience helpers ────────────────────────────────────

  Future<void> logLogin(String userId, String userName) => logAction(
        userId: userId, userName: userName,
        action: AuditAction.login,
        description: '$userName logged in',
      );

  Future<void> logLogout(String userId, String userName) => logAction(
        userId: userId, userName: userName,
        action: AuditAction.logout,
        description: '$userName logged out',
      );

  Future<void> logEmployeeCreated({
    required String byUserId,
    required String byUserName,
    required String employeeEmail,
    required String role,
  }) =>
      logAction(
        userId: byUserId, userName: byUserName,
        action: AuditAction.employeeCreated,
        description: 'Employee $employeeEmail added with role $role',
        metadata: {'employeeEmail': employeeEmail, 'role': role},
      );

  Future<void> logEmployeeRemoved({
    required String byUserId,
    required String byUserName,
    required String employeeEmail,
  }) =>
      logAction(
        userId: byUserId, userName: byUserName,
        action: AuditAction.employeeRemoved,
        description: 'Employee $employeeEmail removed',
        metadata: {'employeeEmail': employeeEmail},
      );

  Future<void> logRefund({
    required String byUserId,
    required String byUserName,
    required String orderId,
    required double amount,
    required bool approved,
  }) =>
      logAction(
        userId: byUserId, userName: byUserName,
        action: approved ? AuditAction.refundApproved : AuditAction.refundRejected,
        description:
            '${approved ? "Approved" : "Rejected"} refund ₹$amount for order $orderId',
        targetId: orderId,
        metadata: {'amount': amount, 'approved': approved},
      );

  Future<void> logDeviceApproved({
    required String byUserId,
    required String byUserName,
    required String deviceId,
    required String deviceName,
  }) =>
      logAction(
        userId: byUserId, userName: byUserName,
        action: AuditAction.deviceApproved,
        description: 'Device "$deviceName" approved',
        metadata: {'deviceId': deviceId, 'deviceName': deviceName},
      );

  Future<void> logDeviceRevoked({
    required String byUserId,
    required String byUserName,
    required String deviceId,
    required String deviceName,
  }) =>
      logAction(
        userId: byUserId, userName: byUserName,
        action: AuditAction.deviceRevoked,
        description: 'Device "$deviceName" revoked',
        metadata: {'deviceId': deviceId, 'deviceName': deviceName},
      );

  Future<void> logOrderCancelled({
    required String byUserId,
    required String byUserName,
    required String orderId,
    required String reason,
  }) =>
      logAction(
        userId: byUserId, userName: byUserName,
        action: AuditAction.orderCancellation,
        description: 'Order $orderId cancelled: $reason',
        targetId: orderId,
        metadata: {'reason': reason},
      );

  Future<void> logPriceChange({
    required String byUserId,
    required String byUserName,
    required String productId,
    required double oldPrice,
    required double newPrice,
  }) =>
      logAction(
        userId: byUserId, userName: byUserName,
        action: AuditAction.priceUpdate,
        description: 'Price changed for product $productId: ₹$oldPrice → ₹$newPrice',
        targetId: productId,
        metadata: {'oldPrice': oldPrice, 'newPrice': newPrice},
      );

  // ── Firestore read stream ──────────────────────────────────

  Stream<List<Map<String, dynamic>>> getLogsStream({
    int limit = 100,
    String? filterAction,
    String? filterUserId,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (filterAction != null) {
      query = query.where('action', isEqualTo: filterAction);
    }
    if (filterUserId != null) {
      query = query.where('userId', isEqualTo: filterUserId);
    }

    return query.snapshots().map(
        (s) => s.docs.map((d) => d.data()).toList());
  }
}
