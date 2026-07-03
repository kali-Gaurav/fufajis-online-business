import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/purchase_request_model.dart';
import '../../models/supplier_quote_model.dart';
import '../../services/supplier_portal_service.dart';
import '../../utils/app_theme.dart';

class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupplierPortalService _portalService = SupplierPortalService();
  String? get _supplierId => FirebaseAuth.instance.currentUser?.uid;

  void _showQuoteDialog(PurchaseRequestModel request) {
    final priceController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Submit Quote', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Product: ${request.productId}'),
              Text('Requested Qty: ${request.suggestedPurchaseQty}'),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Your Price Per Unit (₹)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text) ?? 0.0;
                if (price <= 0) return;

                final docRef = _firestore.collection('supplier_quotes').doc();
                final quote = SupplierQuoteModel(
                  id: docRef.id,
                  purchaseRequestId: request.id,
                  supplierId: _supplierId ?? 'unknown_supplier',
                  productId: request.productId,
                  requestedQuantity: request.suggestedPurchaseQty,
                  quotedPricePerUnit: price,
                  estimatedDeliveryDate: DateTime.now().add(const Duration(days: 2)), // Mock 2 days
                  notes: notesController.text,
                  createdAt: DateTime.now(),
                );

                Navigator.pop(context); // Close dialog early
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Submitting...')));

                await _portalService.submitQuote(quote);

                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Quote submitted successfully!')));
                }
              },
              child: const Text('Submit'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Open Requests for Bidding',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('purchase_requests')
                .where(
                  'status',
                  isEqualTo: PurchaseRequestStatus.approved.name,
                ) // Approved by Owner, waiting for suppliers
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const CircularProgressIndicator(color: AppTheme.primary);
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No open requests at the moment.'),
                  ),
                );
              }

              final requests = snapshot.data!.docs
                  .map(
                    (doc) =>
                        PurchaseRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
                  )
                  .toList();

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final pr = requests[index];
                  return Card(
                    child: ListTile(
                      title: Text('Product ID: ${pr.productId}'),
                      subtitle: Text(
                        'Quantity needed: ${pr.suggestedPurchaseQty} | Expected Cost: ₹${pr.expectedCost}/unit',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _showQuoteDialog(pr),
                        child: const Text('Send Quote'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
