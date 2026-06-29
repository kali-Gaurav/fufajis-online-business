import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'inventory_ledger_service.dart';
import 'notification_service.dart';
import 'audit_service.dart';
import 'wallet_service.dart';

/// Complete returns and refund lifecycle management
/// Handles return requests, approvals, rejections, and full refund flow
///
/// Workflow:
/// requested → approved → refund_processed → completed
///   ↓
/// rejected (terminal)
///
/// Side effects:
/// - approved: process refund, restore wallet, restore inventory
/// - rejected: notify customer with reason
/// - completed: mark order eligible for reorder

enum ReturnWorkflowStatus {
  requested,        // Customer initiated return
  approved,         // Shop owner approved
  refund_initiated, // Refund being processed
  refund_completed, // Refund paid
  completed,        // Fully resolved
  rejected,         // Denied
}

class ReturnsWorkflowService {
  static final ReturnsWorkflowService _instance = ReturnsWorkflowService._internal();
  factory ReturnsWorkflowService() => _instance;
  ReturnsWorkflowService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final InventoryLedgerService _ledger = InventoryLedgerService();
  final NotificationService _notifications = NotificationService();
  final AuditService _audit = AuditService();
  final WalletService _wallet = WalletService();

  // Configuration
  static const int returnWindowDays = 7; // Days after delivery to request return
  static const int maxReturnAttempts = 3;

  // State machine definition
  static const Map<String, Set<String>> validTransitions = {
    'requested': {'approved', 'rejected'},
    'approved': {'refund_initiated'},
    'refund_initiated': {'refund_completed', 'rejected'},
    'refund_completed': {'completed'},
    'completed': <String>{}, // Terminal
    'rejected': <String>{}, // Terminal
  };

  static const Set<String> terminalStatuses = {'completed', 'rejected'};

  bool isTerminal(String status) => terminalStatuses.contains(status);

  bool canTransition(String from, String to) {
    if (from == to) return false;
    return validTransitions[from]?.contains(to) ?? false;
  }

  /// Request return for order
  /// Validates eligibility: order delivered, within 7 days, not already returned
  Future<Map<String, dynamic>> requestReturn({
    required String orderId,
    required String customerId,
    required String reason,
    String? description,
    List<String>? photoUrls,
  }) async {
    try {
      // Get order
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      final orderData = orderSnap.data();

      if (orderData == null) {
        throw Exception('Order not found: $orderId');
      }

      final orderStatus = orderData['status'] as String?;
      final shopId = orderData['shopId'] as String?;
      final deliveredAt = orderData['deliveredAt'] as Timestamp?;

      // Validate eligibility
      if (orderStatus != 'delivered') {
        throw Exception('Order must be delivered to request return (current status: $orderStatus)');
      }

      if (deliveredAt == null) {
        throw Exception('Order has no delivery timestamp');
      }

      final daysSinceDelivery = DateTime.now().difference(deliveredAt.toDate()).inDays;
      if (daysSinceDelivery > returnWindowDays) {
        throw Exception('Return window expired. Orders can only be returned within $returnWindowDays days.');
      }

      // Check for existing return
      final existingReturns = await _db
          .collection('returns')
          .where('orderId', isEqualTo: orderId)
          .where('status', whereIn: ['requested', 'approved', 'refund_initiated', 'refund_completed', 'completed'])
          .limit(1)
          .get();

      if (existingReturns.docs.isNotEmpty) {
        throw Exception('Return already requested for this order');
      }

      final now = DateTime.now();
      final returnRef = _db.collection('returns').doc();
      final returnId = returnRef.id;

      final returnData = {
        'id': returnId,
        'orderId': orderId,
        'customerId': customerId,
        'shopId': shopId,
        'status': ReturnWorkflowStatus.requested.name,
        'reason': reason,
        'description': description,
        'photoUrls': photoUrls,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': [
          {
            'status': ReturnWorkflowStatus.requested.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': customerId,
            'reason': 'customer_requested_return',
          }
        ],
        'refundAmount': null,
        'refundProcessedAt': null,
        'rejectionReason': null,
      };

      await returnRef.set(returnData);

      // Update order with return reference
      await _db.collection('orders').doc(orderId).update({
        'returnId': returnId,
        'returnStatus': ReturnWorkflowStatus.requested.name,
      });

      // Notify shop about return request
      await _notifications.notifyShop(
        shopId ?? '',
        'Return request for order ${orderData['orderNumber']}',
        {
          'returnId': returnId,
          'orderId': orderId,
          'reason': reason,
          'action': 'review_return_request',
        },
      );

      await _audit.log('return_requested', {
        'returnId': returnId,
        'orderId': orderId,
        'customerId': customerId,
        'reason': reason,
      });

      debugPrint('[ReturnsWorkflowService] Created return request $returnId for order $orderId');
      return returnData;
    } catch (e) {
      debugPrint('[ReturnsWorkflowService] Failed to request return: $e');
      rethrow;
    }
  }

  /// Approve return (shop owner decision)
  /// Processes refund and restores inventory
  Future<void> approveReturn({
    required String returnId,
    required double refundAmount,
    String? approvedBy,
    String? notes,
  }) async {
    try {
      final returnSnap = await _db.collection('returns').doc(returnId).get();
      final returnData = returnSnap.data();

      if (returnData == null) {
        throw Exception('Return request not found');
      }

      final currentStatus = returnData['status'] as String;
      if (!canTransition(currentStatus, 'approved')) {
        throw Exception('Cannot approve return in status: $currentStatus');
      }

      final orderId = returnData['orderId'] as String;
      final customerId = returnData['customerId'] as String;
      final now = DateTime.now();

      // Get order to access items and payment info
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      final orderData = orderSnap.data();
      final items = (orderData?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Update return status
      await _db.collection('returns').doc(returnId).update({
        'status': ReturnWorkflowStatus.refund_initiated.name,
        'refundAmount': refundAmount,
        'approvedBy': approvedBy,
        'approvedAt': Timestamp.fromDate(now),
        'notes': notes,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': ReturnWorkflowStatus.refund_initiated.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': approvedBy ?? 'shop',
            'reason': 'return_approved_refund_initiated',
          }
        ])
      });

      // Process refund to wallet
      await _wallet.creditBalance(
        customerId,
        refundAmount,
        'return_refund',
        {
          'returnId': returnId,
          'orderId': orderId,
          'refundAmount': refundAmount,
        },
      );

      // Restore inventory for each item
      for (final item in items) {
        final productId = item['productId'] as String?;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;

        if (productId != null && quantity > 0) {
          await _ledger.restore(productId, quantity, orderId);
        }
      }

      // Complete refund transition
      await _db.collection('returns').doc(returnId).update({
        'status': ReturnWorkflowStatus.refund_completed.name,
        'refundProcessedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': ReturnWorkflowStatus.refund_completed.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'system',
            'reason': 'refund_processed',
          }
        ])
      });

      // Update order
      await _db.collection('orders').doc(orderId).update({
        'returnStatus': ReturnWorkflowStatus.refund_completed.name,
        'refunded': true,
        'refundAmount': refundAmount,
        'refundedAt': Timestamp.fromDate(now),
      });

      // Notify customer
      await _notifications.notifyCustomer(
        customerId,
        'Return approved! Refund of ₹$refundAmount processed to your wallet.',
        {
          'returnId': returnId,
          'orderId': orderId,
          'refundAmount': refundAmount,
        },
      );

      await _audit.log('return_approved', {
        'returnId': returnId,
        'orderId': orderId,
        'customerId': customerId,
        'refundAmount': refundAmount,
        'itemCount': items.length,
        'approvedBy': approvedBy,
      });

      debugPrint('[ReturnsWorkflowService] Approved return $returnId with refund of ₹$refundAmount');
    } catch (e) {
      debugPrint('[ReturnsWorkflowService] Failed to approve return: $e');
      rethrow;
    }
  }

  /// Reject return (shop owner decision)
  /// Terminal state, customer cannot retry
  Future<void> rejectReturn({
    required String returnId,
    required String rejectionReason,
    String? rejectedBy,
  }) async {
    try {
      final returnSnap = await _db.collection('returns').doc(returnId).get();
      final returnData = returnSnap.data();

      if (returnData == null) {
        throw Exception('Return request not found');
      }

      final currentStatus = returnData['status'] as String;
      if (!canTransition(currentStatus, 'rejected')) {
        throw Exception('Cannot reject return in status: $currentStatus');
      }

      final customerId = returnData['customerId'] as String;
      final orderId = returnData['orderId'] as String;
      final now = DateTime.now();

      await _db.collection('returns').doc(returnId).update({
        'status': ReturnWorkflowStatus.rejected.name,
        'rejectionReason': rejectionReason,
        'rejectedBy': rejectedBy,
        'rejectedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': ReturnWorkflowStatus.rejected.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': rejectedBy ?? 'shop',
            'reason': rejectionReason,
          }
        ])
      });

      // Update order
      await _db.collection('orders').doc(orderId).update({
        'returnStatus': ReturnWorkflowStatus.rejected.name,
      });

      // Notify customer
      await _notifications.notifyCustomer(
        customerId,
        'Return request rejected: $rejectionReason',
        {
          'returnId': returnId,
          'orderId': orderId,
          'rejectionReason': rejectionReason,
        },
      );

      await _audit.log('return_rejected', {
        'returnId': returnId,
        'orderId': orderId,
        'customerId': customerId,
        'reason': rejectionReason,
        'rejectedBy': rejectedBy,
      });

      debugPrint('[ReturnsWorkflowService] Rejected return $returnId: $rejectionReason');
    } catch (e) {
      debugPrint('[ReturnsWorkflowService] Failed to reject return: $e');
      rethrow;
    }
  }

  /// Mark return as completed (after receiving returned goods)
  Future<void> markCompleted({
    required String returnId,
    String? receivedBy,
    String? notes,
  }) async {
    try {
      final returnSnap = await _db.collection('returns').doc(returnId).get();
      final returnData = returnSnap.data();

      if (returnData == null) {
        throw Exception('Return request not found');
      }

      final currentStatus = returnData['status'] as String;
      if (!canTransition(currentStatus, 'completed')) {
        throw Exception('Cannot complete return in status: $currentStatus');
      }

      final now = DateTime.now();

      await _db.collection('returns').doc(returnId).update({
        'status': ReturnWorkflowStatus.completed.name,
        'completedAt': Timestamp.fromDate(now),
        'receivedBy': receivedBy,
        'completionNotes': notes,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': ReturnWorkflowStatus.completed.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': receivedBy ?? 'shop',
            'reason': 'return_completed',
          }
        ])
      });

      await _audit.log('return_completed', {
        'returnId': returnId,
        'receivedBy': receivedBy,
      });

      debugPrint('[ReturnsWorkflowService] Marked return $returnId as completed');
    } catch (e) {
      debugPrint('[ReturnsWorkflowService] Failed to mark completed: $e');
      rethrow;
    }
  }

  /// Get return request
  Future<Map<String, dynamic>?> getReturn(String returnId) async {
    final snap = await _db.collection('returns').doc(returnId).get();
    return snap.data();
  }

  /// Get returns for customer
  Future<List<Map<String, dynamic>>> getCustomerReturns(
    String customerId, {
    String? statusFilter,
    int limit = 20,
  }) async {
    var query = _db
        .collection('returns')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  /// Get returns for shop
  Future<List<Map<String, dynamic>>> getShopReturns(
    String shopId, {
    String? statusFilter,
    int limit = 50,
  }) async {
    var query = _db
        .collection('returns')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  /// Get return by order ID
  Future<Map<String, dynamic>?> getReturnByOrder(String orderId) async {
    final snap = await _db
        .collection('returns')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    return snap.docs.isEmpty ? null : snap.docs.first.data();
  }

  /// Get return statistics for shop
  Future<Map<String, dynamic>> getReturnStats(String shopId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final snap = await _db
        .collection('returns')
        .where('shopId', isEqualTo: shopId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final returns = snap.docs.map((doc) => doc.data()).toList();

    final stats = {
      'total': returns.length,
      'approved': returns.where((r) => r['status'] == 'completed').length,
      'rejected': returns.where((r) => r['status'] == 'rejected').length,
      'pending': returns.where((r) => r['status'] == 'requested').length,
      'totalRefundAmount': returns
          .where((r) => r['status'] == 'completed')
          .fold(0.0, (sum, r) => sum + ((r['refundAmount'] as num?) ?? 0).toDouble()),
    };

    return stats;
  }

  /// Stream returns for shop dashboard
  Stream<List<Map<String, dynamic>>> watchShopReturns(
    String shopId, {
    String? statusFilter,
  }) {
    var query = _db
        .collection('returns')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => doc.data()).toList(),
    );
  }
}
