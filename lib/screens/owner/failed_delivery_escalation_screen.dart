import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/order_workflow_engine.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';

/// Task #92 — Failed Delivery Escalation Screen (Owner/Dispatcher)
///
/// Shows all orders currently in 'delivery_failed' status and lets the
/// dispatcher either:
///  - Reassign to another rider (→ out_for_delivery)
///  - Initiate return (→ return_initiated)
///  - Cancel the order (→ cancelled)
class FailedDeliveryEscalationScreen extends StatelessWidget {
  const FailedDeliveryEscalationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Failed Delivery Escalation', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.error,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('status', isEqualTo: 'OrderStatus.delivery_failed')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.success, size: 64),
                  SizedBox(height: 16),
                  Text('No failed deliveries', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final orderId = docs[i].id;
              final orderNumber = d['orderNumber'] ?? orderId.substring(0, 8);
              final customerName = d['customerName'] ?? 'Customer';
              final total = (d['totalAmount'] as num?)?.toDouble() ?? 0;
              final updatedAt = (d['updatedAt'] as Timestamp?)?.toDate();
              final failReason = d['deliveryFailedReason'] ?? 'No reason provided';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.error)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('#$orderNumber',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.error)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(customerName,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Text('₹${total.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.error_outline, size: 14, color: AppTheme.warning),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(failReason,
                                style: const TextStyle(fontSize: 12, color: AppTheme.warning)),
                          ),
                        ],
                      ),
                      if (updatedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Failed: ${DateFormat('dd MMM HH:mm').format(updatedAt)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.replay, size: 14),
                              label: const Text('Reassign', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.info),
                              onPressed: () => _handleEscalation(
                                  context, orderId, orderNumber, 'out_for_delivery',
                                  d['customerId'] ?? '', d['orderNumber'] ?? ''),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.keyboard_return, size: 14),
                              label: const Text('Return', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.warning),
                              onPressed: () => _handleEscalation(
                                  context, orderId, orderNumber, 'return_initiated',
                                  d['customerId'] ?? '', d['orderNumber'] ?? ''),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cancel_outlined, size: 14),
                              label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                              onPressed: () => _handleEscalation(
                                  context, orderId, orderNumber, 'cancelled',
                                  d['customerId'] ?? '', d['orderNumber'] ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleEscalation(BuildContext context, String orderId,
      String orderNumber, String toStatus, String customerId, String orderNum) async {
    final engine = OrderWorkflowEngine();
    final result = await engine.transition(
      orderId: orderId,
      fromStatus: 'delivery_failed',
      toStatus: toStatus,
      changedByUserId: 'dispatcher',
      reason: 'Escalation: $toStatus',
    );

    if (!context.mounted) return;
    if (result.success) {
      try {
        await NotificationService().sendOrderStatusNotification(
          userId: customerId,
          orderId: orderId,
          orderNumber: orderNum,
          status: toStatus,
          message: toStatus == 'out_for_delivery'
              ? 'Your order #$orderNum has been reassigned to a new rider.'
              : toStatus == 'return_initiated'
                  ? 'Your order #$orderNum could not be delivered. Return initiated.'
                  : 'Your order #$orderNum has been cancelled. A refund will follow.',
        );
      } catch (_) {}
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #$orderNumber → $toStatus'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${result.error}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
