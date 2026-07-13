import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/supplier_contract_model.dart';
import '../../models/supplier_scorecard_model.dart';
import '../../utils/app_theme.dart';

class ContractManagementScreen extends StatelessWidget {
  const ContractManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Contracts & Scorecards')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('supplier_contracts').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active contracts found.'));
          }

          final contracts = snapshot.data!.docs
              .map(
                (doc) => SupplierContractModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: contracts.length,
            itemBuilder: (context, index) {
              final contract = contracts[index];
              return Card(
                child: ExpansionTile(
                  title: Text(contract.title),
                  subtitle: Text(
                    'Supplier ID: ${contract.supplierId} | Status: ${contract.status.name}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contract Period: ${contract.contractStart.toString().substring(0, 10)} to ${contract.contractEnd.toString().substring(0, 10)}',
                          ),
                          Text('Payment Terms: ${contract.paymentTerms}'),
                          Text('Credit Limit: ₹${contract.creditLimit}'),
                          const SizedBox(height: 16),
                          const Text(
                            'Supplier Performance Scorecard',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('supplier_scorecards')
                                .doc(contract.supplierId)
                                .get(),
                            builder: (context, scoreSnap) {
                              if (!scoreSnap.hasData ||
                                  scoreSnap.data == null ||
                                  !scoreSnap.data!.exists)
                                return const Text('No scorecard data yet.');
                              final doc = scoreSnap.data!;
                              final data = doc.data() as Map<String, dynamic>?;
                              if (data == null) return const Text('No scorecard data yet.');
                              final score = SupplierScorecardModel.fromMap(data, doc.id);

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.info.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Damage Rate: ${score.damageRatePercentage.toStringAsFixed(1)}%',
                                    ),
                                    Text(
                                      'Fulfillment Rate: ${score.orderFulfillmentPercentage.toStringAsFixed(1)}%',
                                    ),
                                    Text('Total Orders: ${score.totalOrders}'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Future: Open "New Contract" dialog
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
