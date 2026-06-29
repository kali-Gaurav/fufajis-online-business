import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'wallet_service.dart';
import 'inventory_ledger_service.dart';

/// Refund & Inventory Restoration Service
/// Handles refunds with complete inventory restoration (Task #17 FIX)
///
/// CRITICAL FIX: Original refund flow credited wallet but did not restore
/// inventory, creating permanent stock loss. This service ensures:
/// 1. Wallet refund is processed
/// 2. Reserved quantities are cleared
/// 3. Available quantities are restored
/// 4. Audit log records complete transaction
class RefundInventoryService {
  static final RefundInventoryService _instance = RefundInventoryService._internal();
  factory RefundInventoryService() => _instance;
  RefundInventoryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WalletService _wallet = WalletService();
  final InventoryLedgerService _ledger = InventoryLedgerService();

  /// Process refund with complete inventory restoration
  ///
  /// This transaction:
  /// 1. Credits wallet balance
  /// 2. Restores inventory quantities for each item
  /// 3. Creates audit trail
  /// 4. Updates order with refund status
  ///
  /// Returns true if successful
  Future<bool> processRefundWithInventoryRestore({
    required String orderId,
    required String customerId,
    required double refundAmount,
    required List<Map<String, dynamic>> items, // [{productId, quantity}, ...]
    String? reason,
    String? processedBy,
  }) async {
    try {
      final refundId = 'REFUND_${DateTime.now().millisecondsSinceEpoch}';

      await _db.runTransaction((transaction) async {
        final orderRef = _db.collection('orders').doc(orderId);
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw Exception('Order $orderId not found');
        }

        final orderData = orderSnapshot.data()!;
        final currentStatus = orderData['status'] as String? ?? 'unknown';

        // Validate order can be refunded (not already refunded/cancelled)
        if (currentStatus == 'refunded' || currentStatus == 'cancelled') {
          throw Exception('Order $orderId is already $currentStatus. Cannot process refund.');
        }

        // ─────────────────────────────────────────────────
        // 1. WALLET REFUND
        // ─────────────────────────────────────────────────
        final userRef = _db.collection('users').doc(customerId);
        final userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception('Customer profile not found');
        }

        final userData = userSnapshot.data()!;
        final currentBalance = (userData['walletBalance'] as num? ?? 0.0).toDouble();
        final newBalance = currentBalance + refundAmount;
        final lastSeqNum = (userData['lastTransactionSequenceNumber'] as int? ?? 0);
        final newSeqNum = lastSeqNum + 1;

        // Update wallet
        transaction.update(userRef, {
          'walletBalance': newBalance,
          'lastTransactionSequenceNumber': newSeqNum,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Record wallet transaction
        final walletTxnId = 'txn_refund_$refundId';
        transaction.set(
          userRef.collection('wallet_transactions').doc(walletTxnId),
          {
            'id': walletTxnId,
            'userId': customerId,
            'type': 'WalletTransactionType.refund',
            'amount': refundAmount,
            'orderReference': orderId,
            'refundId': refundId,
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Refund for order #${orderData['orderNumber'] ?? orderId}',
            'reason': reason,
            'balanceAfter': newBalance,
            'sequenceNumber': newSeqNum,
          },
        );

        // ─────────────────────────────────────────────────
        // 2. INVENTORY RESTORATION (CRITICAL FIX)
        // ─────────────────────────────────────────────────
        for (var item in items) {
          final productId = item['productId'] as String;
          final quantity = (item['quantity'] as num).toInt();

          final productRef = _db.collection('products').doc(productId);
          final productSnapshot = await transaction.get(productRef);

          if (productSnapshot.exists) {
            final productData = productSnapshot.data()!;

            // Get current reserved and available quantities
            final currentReserved = (productData['reserved_quantity'] as num? ?? 0).toInt();
            final currentAvailable = (productData['available_quantity'] as num? ?? 0).toInt();
            final totalStock = (productData['stockQuantity'] as num? ?? 0).toInt();

            // Restore quantities
            final newReserved = (currentReserved - quantity).clamp(0, totalStock);
            final newAvailable = currentAvailable + quantity;

            transaction.update(productRef, {
              'reserved_quantity': newReserved,
              'available_quantity': newAvailable,
              'lastRefundAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            debugPrint(
              '[RefundInventoryService] Restored $quantity units of $productId '
              '(reserved: $currentReserved→$newReserved, available: $currentAvailable→$newAvailable)'
            );
          }
        }

        // ─────────────────────────────────────────────────
        // 3. ORDER STATUS UPDATE
        // ─────────────────────────────────────────────────
        transaction.update(orderRef, {
          'status': 'refunded',
          'refundId': refundId,
          'refundAmount': refundAmount,
          'refundReason': reason,
          'refundProcessedBy': processedBy ?? 'system',
          'refundProcessedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // ─────────────────────────────────────────────────
        // 4. AUDIT LOG
        // ─────────────────────────────────────────────────
        final auditRef = _db.collection('refund_audit_logs').doc(refundId);
        transaction.set(auditRef, {
          'refundId': refundId,
          'orderId': orderId,
          'customerId': customerId,
          'status': 'completed',
          'refundAmount': refundAmount,
          'itemsRestored': items.map((i) => {
            'productId': i['productId'],
            'quantity': i['quantity'],
          }).toList(),
          'reason': reason,
          'processedBy': processedBy ?? 'system',
          'processedAt': FieldValue.serverTimestamp(),
          'walletTransactionId': walletTxnId,
          'previousOrderStatus': currentStatus,
          'newOrderStatus': 'refunded',
        });
      });

      debugPrint(
        '[RefundInventoryService] Refund $refundId processed successfully '
        '(amount: ₹$refundAmount, items: ${items.length})'
      );

      return true;
    } catch (e) {
      debugPrint('[RefundInventoryService] Refund processing failed: $e');
      return false;
    }
  }

  /// Restore inventory for partial refund (if some items damaged/defective)
  Future<bool> restorePartialInventory({
    required String productId,
    required int quantity,
    required String orderId,
    String? reason,
  }) async {
    try {
      await _db.runTransaction((transaction) async {
        final productRef = _db.collection('products').doc(productId);
        final productSnapshot = await transaction.get(productRef);

        if (!productSnapshot.exists) {
          throw Exception('Product $productId not found');
        }

        final productData = productSnapshot.data()!;
        final currentReserved = (productData['reserved_quantity'] as num? ?? 0).toInt();
        final currentAvailable = (productData['available_quantity'] as num? ?? 0).toInt();
        final totalStock = (productData['stockQuantity'] as num? ?? 0).toInt();

        // Restore to available
        final newReserved = (currentReserved - quantity).clamp(0, totalStock);
        final newAvailable = currentAvailable + quantity;

        transaction.update(productRef, {
          'reserved_quantity': newReserved,
          'available_quantity': newAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Log partial restore
        final logRef = _db.collection('partial_restore_logs').doc();
        transaction.set(logRef, {
          'productId': productId,
          'orderId': orderId,
          'quantity': quantity,
          'reason': reason,
          'restoredAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      debugPrint('[RefundInventoryService] Partial restore failed: $e');
      return false;
    }
  }

  /// Get refund details
  Future<Map<String, dynamic>?> getRefundDetails(String refundId) async {
    try {
      final doc = await _db.collection('refund_audit_logs').doc(refundId).get();
      return doc.data();
    } catch (e) {
      debugPrint('[RefundInventoryService] Get refund failed: $e');
      return null;
    }
  }

  /// List refunds for an order
  Future<List<Map<String, dynamic>>> getOrderRefunds(String orderId) async {
    try {
      final snapshot = await _db
          .collection('refund_audit_logs')
          .where('orderId', isEqualTo: orderId)
          .orderBy('processedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[RefundInventoryService] Get order refunds failed: $e');
      return [];
    }
  }
}
