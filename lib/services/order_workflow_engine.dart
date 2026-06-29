// ============================================================
//  OrderWorkflowEngine — order status state machine
//
//  Centralizes the valid order_status transitions so that no
//  code path can "skip" a status (e.g. jump straight from
//  pending to delivered). All status changes should go through
//  [transition], which validates the move and then writes both
//  the new status and an order_status_history row via
//  SupabaseDatabaseService.
//
//  Statuses (see migrations/001_core_schema.sql):
//    pending -> confirmed -> preparing -> ready_for_pickup
//      -> out_for_delivery -> delivered
//    pending/confirmed/preparing -> cancelled
//    delivered -> refunded
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'invoice_service.dart';
import 'api_client.dart';

/// Result of an [OrderWorkflowEngine.transition] attempt.
class OrderTransitionResult {
  final bool success;
  final String? error;

  const OrderTransitionResult.ok() : success = true, error = null;
  const OrderTransitionResult.failure(this.error) : success = false;
}

class OrderWorkflowEngine {
  static final OrderWorkflowEngine _instance = OrderWorkflowEngine._internal();
  factory OrderWorkflowEngine() => _instance;
  OrderWorkflowEngine._internal();

  /// Map of order_status -> set of statuses it may transition to.
  /// Any transition not listed here is rejected.
  static const Map<String, Set<String>> validTransitions = {
    'pending':              {'confirmed', 'cancelled', 'on_hold'},
    'confirmed':            {'preparing', 'cancelled', 'on_hold'},
    'preparing':            {'ready_for_pickup', 'cancelled', 'partially_fulfilled', 'on_hold'},
    'ready_for_pickup':     {'out_for_delivery', 'cancelled'},
    'out_for_delivery':     {'delivered', 'delivery_failed', 'cancelled'},
    'delivery_failed':      {'out_for_delivery', 'cancelled', 'return_initiated'},
    'partially_fulfilled':  {'preparing', 'out_for_delivery', 'cancelled'},
    'on_hold':              {'confirmed', 'cancelled'},
    'return_initiated':     {'returned', 'cancelled'},
    'returned':             {'refunded'},
    'delivered':            {'refunded', 'return_initiated'},
    'cancelled':            <String>{},
    'refunded':             <String>{},
  };

  /// All terminal statuses — no further transitions allowed.
  static const Set<String> terminalStatuses = {'cancelled', 'refunded', 'returned'};

  bool isTerminal(String status) => terminalStatuses.contains(status);

  /// Returns true if moving from [from] to [to] is a legal transition.
  bool canTransition(String from, String to) {
    if (from == to) return false;
    return validTransitions[from]?.contains(to) ?? false;
  }

  /// Attempts to move [orderId] from [fromStatus] to [toStatus].
  ///
  /// On success, updates `orders.order_status` via the Lambda API client.
  Future<OrderTransitionResult> transition({
    required String orderId,
    required String fromStatus,
    required String toStatus,
    required String changedByUserId,
    String? reason,
  }) async {
    if (!canTransition(fromStatus, toStatus)) {
      final msg =
          'Invalid order transition: $fromStatus -> $toStatus (order $orderId)';
      debugPrint('[OrderWorkflowEngine] $msg');
      return OrderTransitionResult.failure(msg);
    }

    try {
      await ApiClient().post('/orders/$orderId/status', {
        'fromStatus': fromStatus,
        'toStatus': toStatus,
        'changedByUserId': changedByUserId,
        if (reason != null) 'reason': reason,
      });
    } catch (e) {
      return OrderTransitionResult.failure(
          'Failed to persist order status change: $e');
    }

    // Automatic inventory sync: the moment an order enters 'preparing'
    // (packing/parceling has begun), decrement stock for every item on the
    // order so `products.stockQuantity`/`branchStock` (Firestore) reflect
    // what's been physically pulled for this parcel.
    if (toStatus == 'preparing') {
      unawaited(_syncStockForPackagedOrder(orderId, changedByUserId));
    }

    // Automatic GST tax invoice generation (Task #54): once an order is
    // marked delivered, persist an immutable, sequentially-numbered GST
    // invoice for it. Best-effort.
    if (toStatus == 'delivered') {
      unawaited(_generateInvoiceForDeliveredOrder(orderId));
    }

    return const OrderTransitionResult.ok();
  }

  /// Fetches the full order from Firestore and creates its GST invoice via
  /// [InvoiceService.createInvoiceForOrder], then stamps the resulting
  /// `invoiceId`/`invoiceNumber`/`invoiceGeneratedAt` back onto the order
  /// document. Safe to call repeatedly — [InvoiceService.createInvoiceForOrder]
  /// reuses any existing invoice instead of creating duplicates.
  Future<void> _generateInvoiceForDeliveredOrder(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      if (!doc.exists) return;

      await InvoiceService.finalizeInvoice(orderId);
    } catch (e) {
      debugPrint('[OrderWorkflowEngine] GST invoice generation failed for order $orderId: $e');
    }
  }

  /// Decrements `products.stockQuantity` (and per-branch `branchStock`, if
  /// the product carries a branch entry matching the order's shop) for every
  /// line item of [orderId] from Firestore.
  Future<void> _syncStockForPackagedOrder(String orderId, String changedByUserId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final items = data['items'] as List? ?? [];
      if (items.isEmpty) return;

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      bool hasWrites = false;

      for (final item in items) {
        final productId = (item['product_id'] ?? item['productId'])?.toString();
        if (productId == null || productId.isEmpty) continue;

        final qtyRaw = item['quantity'] ?? item['qty'] ?? 1;
        final qty = (qtyRaw is num) ? qtyRaw.toInt() : int.tryParse(qtyRaw.toString()) ?? 1;
        if (qty <= 0) continue;

        // Firestore: decrement stockQuantity, never below zero, and flip
        // isAvailable off when it hits zero. branchStock (per-shop counts)
        // is decremented for the order's shopId if present.
        final ref = firestore.collection('products').doc(productId);
        try {
          final snap = await ref.get();
          if (!snap.exists) continue;
          final prodData = snap.data() ?? {};
          final currentStock = (prodData['stockQuantity'] as num?)?.toInt() ?? 0;
          final newStock = (currentStock - qty) < 0 ? 0 : currentStock - qty;

          final updates = <String, dynamic>{
            'stockQuantity': newStock,
            'isAvailable': newStock > 0,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          final shopId = item['shop_id']?.toString() ?? prodData['shopId']?.toString();
          final branchStock = prodData['branchStock'];
          if (shopId != null && branchStock is Map && branchStock.containsKey(shopId)) {
            final currentBranch = (branchStock[shopId] as num?)?.toInt() ?? 0;
            final newBranch = (currentBranch - qty) < 0 ? 0 : currentBranch - qty;
            updates['branchStock.$shopId'] = newBranch;
          }

          batch.update(ref, updates);
          hasWrites = true;
        } catch (e) {
          debugPrint('[OrderWorkflowEngine] Firestore stock sync failed for $productId: $e');
        }
      }

      if (hasWrites) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[OrderWorkflowEngine] Stock sync failed for order $orderId: $e');
    }
  }

  /// Convenience: cancels an order if it is still in a cancellable state.
  Future<OrderTransitionResult> cancel({
    required String orderId,
    required String fromStatus,
    required String changedByUserId,
    String? reason,
  }) {
    return transition(
      orderId: orderId,
      fromStatus: fromStatus,
      toStatus: 'cancelled',
      changedByUserId: changedByUserId,
      reason: reason ?? 'Order cancelled',
    );
  }

  /// Returns the set of statuses [fromStatus] may legally move to —
  /// useful for building action buttons in staff/admin UIs.
  Set<String> nextStatuses(String fromStatus) {
    return validTransitions[fromStatus] ?? const <String>{};
  }
}
