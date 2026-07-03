import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../utils/monetary_value.dart';
import 'order_workflow_engine.dart';
import 'notification_service.dart';

/// Task #88 — Partial Fulfillment Service
///
/// Allows an order to be partially dispatched when some items are unavailable.
/// Creates a "fulfillment split": the in-stock items move to [out_for_delivery]
/// while out-of-stock items are either cancelled or held for later dispatch.
class PartialFulfillmentService {
  static final PartialFulfillmentService _i = PartialFulfillmentService._();
  factory PartialFulfillmentService() => _i;
  static PartialFulfillmentService get instance => _i;
  PartialFulfillmentService._();

  final _db = FirebaseFirestore.instance;
  final _engine = OrderWorkflowEngine();

  /// Marks specific [unavailableProductIds] as unfulfillable for [orderId].
  /// - Removes those items from the dispatch batch.
  /// - Generates a partial credit/refund for the removed items.
  /// - Transitions order → 'partially_fulfilled'.
  /// - Notifies the customer.
  Future<PartialFulfillmentResult> processPartialFulfillment({
    required String orderId,
    required List<String> unavailableProductIds,
    required String performedBy,
    String? note,
  }) async {
    final orderSnap = await _db.collection('orders').doc(orderId).get();
    if (!orderSnap.exists || orderSnap.data() == null) {
      return PartialFulfillmentResult.failure('Order not found');
    }

    final data = orderSnap.data()!;
    if (!data.containsKey('id')) data['id'] = orderSnap.id;
    final order = OrderModel.fromMap(data);
    final currentStatus = order.status.toString().split('.').last;

    if (!{'confirmed', 'preparing'}.contains(currentStatus)) {
      return PartialFulfillmentResult.failure(
        'Cannot partially fulfil order in status: $currentStatus',
      );
    }

    // Calculate refund amount for unavailable items
    final unavailableItems = order.items
        .where((i) => unavailableProductIds.contains(i.productId))
        .toList();
    final refundAmount = unavailableItems.fold(0.0, (sum, i) => sum + i.totalPrice.toDouble());
    final remainingItems = order.items
        .where((i) => !unavailableProductIds.contains(i.productId))
        .toList();

    if (remainingItems.isEmpty) {
      return PartialFulfillmentResult.failure(
        'All items unavailable — use full cancellation instead',
      );
    }

    final batch = _db.batch();
    final orderRef = _db.collection('orders').doc(orderId);

    // Record unfulfilled items + adjusted total
    batch.update(orderRef, {
      'partialFulfillment': {
        'unfulfilledProductIds': unavailableProductIds,
        'refundAmount': refundAmount,
        'performedBy': performedBy,
        'note': note ?? '',
        'processedAt': FieldValue.serverTimestamp(),
      },
      'adjustedTotal': (order.totalAmount - MonetaryValue(refundAmount)).toFirestore(),
      'status': 'OrderStatus.partially_fulfilled',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Status history entry
    final histRef = orderRef.collection('status_history').doc();
    batch.set(histRef, {
      'fromStatus': currentStatus,
      'toStatus': 'partially_fulfilled',
      'changedBy': performedBy,
      'reason': 'Partial fulfillment: ${unavailableProductIds.length} item(s) unavailable',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Trigger engine transition
    await _engine.transition(
      orderId: orderId,
      fromStatus: currentStatus,
      toStatus: 'partially_fulfilled',
      changedByUserId: performedBy,
      reason: 'Items unavailable: ${unavailableProductIds.join(", ")}',
    );

    // Notify customer
    try {
      await NotificationService().sendOrderStatusNotification(
        userId: order.customerId,
        orderId: orderId,
        orderNumber: order.orderNumber,
        status: 'partially_fulfilled',
        message:
            'Some items in your order #${order.orderNumber} were unavailable. '
            "We'll refund ₹${refundAmount.toStringAsFixed(2)} to your wallet.",
      );
    } catch (e) {
      debugPrint('[PartialFulfillment] Notification failed: $e');
    }

    return PartialFulfillmentResult.success(
      refundAmount: refundAmount,
      unfulfilledCount: unavailableProductIds.length,
      remainingCount: remainingItems.length,
    );
  }

  /// Places an order [on_hold] — pauses processing until manually released.
  Future<bool> placeOnHold(String orderId, String reason, String performedBy) async {
    final snap = await _db.collection('orders').doc(orderId).get();
    if (!snap.exists) return false;
    final currentStatus = (snap.data()!['status'] as String? ?? 'pending').replaceAll(
      'OrderStatus.',
      '',
    );
    final result = await _engine.transition(
      orderId: orderId,
      fromStatus: currentStatus,
      toStatus: 'on_hold',
      changedByUserId: performedBy,
      reason: reason,
    );
    if (result.success) {
      await _db.collection('orders').doc(orderId).update({
        'holdReason': reason,
        'heldBy': performedBy,
        'heldAt': FieldValue.serverTimestamp(),
      });
    }
    return result.success;
  }

  /// Releases a held order back to 'confirmed' for re-processing.
  Future<bool> releaseHold(String orderId, String performedBy) async {
    final snap = await _db.collection('orders').doc(orderId).get();
    if (!snap.exists) return false;
    final result = await _engine.transition(
      orderId: orderId,
      fromStatus: 'on_hold',
      toStatus: 'confirmed',
      changedByUserId: performedBy,
      reason: 'Hold released by $performedBy',
    );
    if (result.success) {
      await _db.collection('orders').doc(orderId).update({
        'holdReason': FieldValue.delete(),
        'heldBy': FieldValue.delete(),
        'heldAt': FieldValue.delete(),
        'holdReleasedBy': performedBy,
        'holdReleasedAt': FieldValue.serverTimestamp(),
      });
    }
    return result.success;
  }
}

class PartialFulfillmentResult {
  final bool success;
  final String? error;
  final double refundAmount;
  final int unfulfilledCount;
  final int remainingCount;

  const PartialFulfillmentResult._({
    required this.success,
    this.error,
    this.refundAmount = 0,
    this.unfulfilledCount = 0,
    this.remainingCount = 0,
  });

  factory PartialFulfillmentResult.success({
    required double refundAmount,
    required int unfulfilledCount,
    required int remainingCount,
  }) => PartialFulfillmentResult._(
    success: true,
    refundAmount: refundAmount,
    unfulfilledCount: unfulfilledCount,
    remainingCount: remainingCount,
  );

  factory PartialFulfillmentResult.failure(String error) =>
      PartialFulfillmentResult._(success: false, error: error);
}
