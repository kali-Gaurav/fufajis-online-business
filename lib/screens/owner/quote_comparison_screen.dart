import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/supplier_quote_model.dart';
import '../../models/purchase_request_model.dart';
import '../../services/supplier_portal_service.dart';
import '../../utils/app_theme.dart';

class QuoteComparisonScreen extends StatefulWidget {
  final String purchaseRequestId;

  const QuoteComparisonScreen({super.key, required this.purchaseRequestId});

  @override
  State<QuoteComparisonScreen> createState() => _QuoteComparisonScreenState();
}

class _QuoteComparisonScreenState extends State<QuoteComparisonScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupplierPortalService _portalService = SupplierPortalService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Quotes')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('purchase_requests')
            .doc(widget.purchaseRequestId)
            .snapshots(),
        builder: (context, prSnapshot) {
          if (!prSnapshot.hasData || !prSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }

          final pr = PurchaseRequestModel.fromMap(
            prSnapshot.data!.data() as Map<String, dynamic>,
            prSnapshot.data!.id,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: AppTheme.info.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase Request: ${pr.id}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Product ID: ${pr.productId}'),
                        Text('Requested Quantity: ${pr.suggestedPurchaseQty}'),
                        Text('AI Expected Cost: ₹${pr.expectedCost}/unit'),
                        Text(
                          'Status: ${pr.status.name.toUpperCase()}',
                          style: TextStyle(
                            color: pr.status == PurchaseRequestStatus.ordered
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Supplier Quotes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('supplier_quotes')
                      .where('purchaseRequestId', isEqualTo: widget.purchaseRequestId)
                      .snapshots(),
                  builder: (context, quoteSnapshot) {
                    if (quoteSnapshot.connectionState == ConnectionState.waiting)
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.ownerAccent),
                      );
                    if (!quoteSnapshot.hasData || quoteSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No quotes received yet.'));
                    }

                    final quotes = quoteSnapshot.data!.docs
                        .map(
                          (doc) => SupplierQuoteModel.fromMap(
                            doc.data() as Map<String, dynamic>,
                            doc.id,
                          ),
                        )
                        .toList();
                    // Sort by price ascending
                    quotes.sort((a, b) => a.quotedPricePerUnit.compareTo(b.quotedPricePerUnit));

                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: quotes.length,
                      itemBuilder: (context, index) {
                        final quote = quotes[index];
                        final isAccepted = quote.status == SupplierQuoteStatus.accepted;
                        final isRejected = quote.status == SupplierQuoteStatus.rejected;

                        return Card(
                          color: isAccepted
                              ? AppTheme.success.withValues(alpha: 0.1)
                              : (isRejected ? AppTheme.error.withValues(alpha: 0.1) : null),
                          child: ListTile(
                            title: Text('Supplier ID: ${quote.supplierId}'),
                            subtitle: Text(
                              'Price: ₹${quote.quotedPricePerUnit}/unit\nDelivery: ${quote.estimatedDeliveryDate.toString().substring(0, 10)}\nNotes: ${quote.notes ?? "None"}',
                            ),
                            trailing: isAccepted
                                ? const Chip(
                                    label: Text(
                                      'Accepted',
                                      style: TextStyle(color: AppTheme.success),
                                    ),
                                  )
                                : isRejected
                                ? const Chip(
                                    label: Text(
                                      'Rejected',
                                      style: TextStyle(color: AppTheme.error),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: pr.status == PurchaseRequestStatus.ordered
                                        ? null
                                        : () async {
                                            try {
                                              final ownerId =
                                                  FirebaseAuth.instance.currentUser?.uid ?? 'sys';
                                              await _portalService.acceptQuoteAndCreatePO(
                                                quote.id,
                                                ownerId,
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Quote accepted! PO generated.'),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error: $e')),
                                                );
                                              }
                                            }
                                          },
                                    child: const Text('Accept'),
                                  ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
