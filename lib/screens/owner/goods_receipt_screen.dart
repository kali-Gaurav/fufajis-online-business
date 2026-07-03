import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/purchase_order_model.dart';
import '../../models/goods_receipt_model.dart';
import '../../services/supplier_portal_service.dart';
import '../../utils/app_theme.dart';

class GoodsReceiptScreen extends StatefulWidget {
  const GoodsReceiptScreen({super.key});

  @override
  State<GoodsReceiptScreen> createState() => _GoodsReceiptScreenState();
}

class _GoodsReceiptScreenState extends State<GoodsReceiptScreen> {
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupplierPortalService _portalService = SupplierPortalService();

  void _showReceiveDialog(PurchaseOrderModel po) {
    final receivedController = TextEditingController(text: po.quantity.toString());
    final damagedController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Receive Goods', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Expected Quantity: ${po.quantity}'),
              const SizedBox(height: 16),
              TextField(
                controller: receivedController,
                decoration: const InputDecoration(labelText: 'Total Received Quantity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: damagedController,
                decoration: const InputDecoration(labelText: 'Damaged/Rejected Quantity'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final received = int.tryParse(receivedController.text) ?? 0;
                final damaged = int.tryParse(damagedController.text) ?? 0;
                final accepted = received - damaged;

                if (accepted < 0) return;

                final docRef = _firestore.collection('goods_receipts').doc();
                final receipt = GoodsReceiptModel(
                  id: docRef.id,
                  purchaseOrderId: po.id,
                  supplierId: po.supplierId,
                  branchId: po.branchId,
                  productId: po.productId,
                  receivedQuantity: received,
                  damagedQuantity: damaged,
                  acceptedQuantity: accepted,
                  recordedByUserId: FirebaseAuth.instance.currentUser?.uid ?? 'sys',
                  timestamp: DateTime.now(),
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Processing receipt...')));

                await _portalService.receiveGoods(
                  receipt,
                  FirebaseAuth.instance.currentUser?.uid ?? 'sys',
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Goods received and inventory updated!')),
                  );
                }
              },
              child: const Text('Confirm Receipt'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goods Receipt')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('purchase_orders')
            .where(
              'status',
              whereIn: [
                PurchaseOrderStatus.po_generated.name,
                PurchaseOrderStatus.supplier_accepted.name,
                PurchaseOrderStatus.dispatched.name,
                PurchaseOrderStatus.in_transit.name,
                PurchaseOrderStatus.partially_received.name,
                PurchaseOrderStatus.fully_received.name,
              ],
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending deliveries.'));
          }

          final orders = snapshot.data!.docs
              .map((doc) => PurchaseOrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final po = orders[index];
              return Card(
                child: ListTile(
                  title: Text('PO: ${po.id}'),
                  subtitle: Text(
                    'Product: ${po.productId}\nExpected: ${po.quantity} | Delivery: ${po.expectedDeliveryDate.toString().substring(0, 10)}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (po.status != PurchaseOrderStatus.fully_received)
                        ElevatedButton(
                          onPressed: () => _showReceiveDialog(po),
                          child: const Text('Receive'),
                        ),
                      if (po.status == PurchaseOrderStatus.fully_received)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          onPressed: () {
                            // Mocking the creation of a supplier invoice & 3-way match
                            _showInvoiceMatchDialog(po);
                          },
                          child: const Text('Match Invoice'),
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

  void _showInvoiceMatchDialog(PurchaseOrderModel po) {
    final invoiceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '3-Way Match Verification',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PO: ${po.id}'),
              Text('Agreed Price/Unit: ₹${po.agreedPricePerUnit}'),
              const SizedBox(height: 16),
              TextField(
                controller: invoiceController,
                decoration: const InputDecoration(labelText: 'Supplier Invoice Total Amount (₹)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(invoiceController.text) ?? 0.0;
                if (amount <= 0) return;

                final invoiceDoc = _firestore.collection('supplier_invoices').doc();
                await invoiceDoc.set({
                  'id': invoiceDoc.id,
                  'purchaseOrderId': po.id,
                  'supplierId': po.supplierId,
                  'invoiceNumber': 'INV-${DateTime.now().millisecondsSinceEpoch}',
                  'billedAmount': amount,
                  'status': 'pending_match',
                  'isThreeWayMatched': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'dueDate': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Verifying 3-Way Match...')));
                }

                final isMatched = await _portalService.verifyThreeWayMatch(invoiceDoc.id);
                if (context.mounted) {
                  if (isMatched) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ 3-Way Match SUCCESS. Invoice ready for payment.'),
                      ),
                    );
                    // Update PO to closed
                    await _firestore.collection('purchase_orders').doc(po.id).update({
                      'status': PurchaseOrderStatus.closed.name,
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ 3-Way Match DISCREPANCY. Flagged for review.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Simulate OCR & Match'),
            ),
          ],
        );
      },
    );
  }
}
