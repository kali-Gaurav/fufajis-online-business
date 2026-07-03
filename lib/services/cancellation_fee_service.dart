import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import 'wallet_service.dart';

/// Task #93 — Cancellation Fee Service
///
/// Applies a configurable cancellation fee when an order is cancelled after
/// preparation has started. The fee is deducted from the refund amount.
/// Fee schedule (overrideable via Remote Config / Firestore config doc):
///   - Cancelled before 'confirmed'   → 0%  fee
///   - Cancelled during 'preparing'   → 5%  fee (₹ min 10)
///   - Cancelled at 'ready_for_pickup' → 10% fee (₹ min 20)
///   - Cancelled at 'out_for_delivery' → 15% fee (₹ min 30)
class CancellationFeeService {
  static final CancellationFeeService _i = CancellationFeeService._();
  factory CancellationFeeService() => _i;
  CancellationFeeService._();

  final _db = FirebaseFirestore.instance;

  static const Map<String, double> _feeRates = {
    'pending': 0.00,
    'confirmed': 0.00,
    'preparing': 0.05,
    'ready_for_pickup': 0.10,
    'out_for_delivery': 0.15,
  };

  static const Map<String, double> _minimumFees = {
    'preparing': 10.0,
    'ready_for_pickup': 20.0,
    'out_for_delivery': 30.0,
  };

  /// Calculates the cancellation fee for [order] at its current status.
  /// Returns [CancellationFeeResult] with the fee and net refund amount.
  CancellationFeeResult calculateFee(OrderModel order) {
    final status = order.status.toString().split('.').last;
    final rate = _feeRates[status] ?? 0.0;
    final minFee = _minimumFees[status] ?? 0.0;
    final orderTotal = order.totalAmount.toDouble();
    final rawFee = orderTotal * rate;
    final fee = rawFee < minFee && rawFee > 0 ? minFee : rawFee;
    final netRefund = (orderTotal - fee).clamp(0.0, orderTotal);
    return CancellationFeeResult(
      fee: fee,
      feeRate: rate,
      netRefund: netRefund,
      orderTotal: orderTotal,
      status: status,
      waived: fee == 0,
    );
  }

  /// Applies the cancellation fee and issues net refund to wallet.
  /// Records the fee as a ledger entry.
  Future<bool> applyAndRefund({
    required OrderModel order,
    required String cancelledBy,
    required String reason,
    bool waiveFee = false,
  }) async {
    final result = calculateFee(order);
    final actualFee = waiveFee ? 0.0 : result.fee;
    final actualRefund = order.totalAmount.toDouble() - actualFee;

    try {
      final ledgerRef = _db
          .collection('cancellation_fee_ledger')
          .doc('cancellation_fee_${order.id}');

      // FIX (Module 10, P0-10.3): stock was NEVER restored on cancellation —
      // OrderService.createOrder deducts branchStock at order placement, but
      // the cancel flow only refunded the wallet, causing permanent phantom
      // stock loss on every cancelled order. The transaction below restores
      // stock atomically WITH the idempotency-ledger write, so a retry can
      // neither double-restore stock nor skip restoration.
      final branchId = order.branchId ?? 'primary';

      // Aggregate quantities per product (an order can contain the same
      // product in multiple lines).
      final Map<String, int> qtyByProduct = {};
      for (final item in order.items) {
        qtyByProduct.update(
          item.productId,
          (q) => q + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }

      final ledgerData = <String, dynamic>{
        'orderId': order.id,
        'orderNumber': order.orderNumber,
        'customerId': order.customerId,
        'orderTotal': order.totalAmount.toDouble(),
        'feeRate': actualFee > 0 ? result.feeRate : 0.0,
        'feeAmount': actualFee,
        'netRefund': actualRefund,
        'statusAtCancellation': result.status,
        'cancelledBy': cancelledBy,
        'reason': reason,
        'waivedByAdmin': actualFee > 0 ? waiveFee : true,
        'stockRestored': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _db.runTransaction((txn) async {
        // 1. Idempotency gate (read must precede all writes in a txn).
        final ledgerSnap = await txn.get(ledgerRef);
        if (ledgerSnap.exists) {
          debugPrint(
            '[CancellationFee] Cancellation fee already applied for order ${order.id}. Skipping.',
          );
          return;
        }

        // 2. Read all product docs first.
        final productReads = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final productId in qtyByProduct.keys) {
          final snap = await txn.get(_db.collection('products').doc(productId));
          if (snap.exists) productReads[productId] = snap;
          // A deleted product simply can't have its stock restored — log and
          // continue rather than failing the whole cancellation.
        }

        // 3. Write ledger (idempotency marker) + restored stock together.
        txn.set(ledgerRef, ledgerData);

        productReads.forEach((productId, snap) {
          final data = snap.data()!;
          final qty = qtyByProduct[productId]!;
          final Map<dynamic, dynamic> rawBranchStock = data['branchStock'] as Map? ?? {};
          final Map<String, int> branchStock = rawBranchStock.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          );

          // Mirror OrderService.createOrder's deduction logic in reverse:
          // restore to the branch the order deducted from (falling back to
          // the same 'primary'/global seed rule it uses).
          final current = branchStock[branchId] ??
              ((branchId == 'primary' || branchStock.isEmpty)
                  ? ((data['stockQuantity'] ?? 0) as num).toInt()
                  : 0);
          branchStock[branchId] = current + qty;

          // Recompute global stock the same way OrderService does.
          final int newGlobalStock = branchStock.containsKey('primary')
              ? branchStock['primary']!
              : branchStock.values.fold(0, (total, v) => total + v);

          txn.update(snap.reference, {
            'branchStock': branchStock,
            'stockQuantity': newGlobalStock,
            'isAvailable': newGlobalStock > 0 || branchStock.values.any((v) => v > 0),
          });
        });

        final missing = qtyByProduct.keys.where((id) => !productReads.containsKey(id));
        for (final id in missing) {
          debugPrint(
            '[CancellationFee] Product $id from order ${order.id} no longer exists — stock not restored for it.',
          );
        }
      });

      // Wallet refund for net amount (if order was paid)
      if (order.paymentStatus == 'paid' && actualRefund > 0) {
        await WalletService().addToWallet(
          userId: order.customerId,
          amount: actualRefund,
          transactionType: WalletTransactionType.refund,
          orderReference: order.id,
          description: actualFee > 0
              ? 'Refund for #${order.orderNumber} (₹${actualFee.toStringAsFixed(2)} cancellation fee applied)'
              : 'Full refund for cancelled order #${order.orderNumber}',
          transactionId: 'txn_cancellation_fee_${order.id}',
        );
      }

      return true;
    } catch (e) {
      debugPrint('[CancellationFee] Error applying fee: $e');
      return false;
    }
  }
}

class CancellationFeeResult {
  final double fee;
  final double feeRate;
  final double netRefund;
  final double orderTotal;
  final String status;
  final bool waived;

  const CancellationFeeResult({
    required this.fee,
    required this.feeRate,
    required this.netRefund,
    required this.orderTotal,
    required this.status,
    required this.waived,
  });

  String get feePercentLabel => '${(feeRate * 100).toStringAsFixed(0)}%';
}
