import 'package:flutter/material.dart';
import '../../services/supplier_service.dart';

class SupplierLeaderboardScreen extends StatefulWidget {
  const SupplierLeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<SupplierLeaderboardScreen> createState() =>
      _SupplierLeaderboardScreenState();
}

class _SupplierLeaderboardScreenState extends State<SupplierLeaderboardScreen> {
  final _supplierService = SupplierService();
  late Future<List<SupplierProfile>> _suppliersF;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  void _loadSuppliers() {
    _suppliersF = Future.value([]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Leaderboard'),
      ),
      body: FutureBuilder<List<SupplierProfile>>(
        future: _suppliersF,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error loading suppliers'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _loadSuppliers()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final suppliers = snapshot.data ?? [];

          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No suppliers yet'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: suppliers.length,
            itemBuilder: (_, index) => _buildSupplierCard(suppliers[index], index + 1),
          );
        },
      ),
    );
  }

  Widget _buildSupplierCard(SupplierProfile supplier, int rank) {
    Color getMedalColor(int rank) {
      switch (rank) {
        case 1:
          return Colors.amber;
        case 2:
          return Colors.grey[400] ?? Colors.grey;
        case 3:
          return Colors.brown[400] ?? Colors.brown;
        default:
          return Colors.blue;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: getMedalColor(rank),
              ),
              child: Center(
                child: Text(
                  rank.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        supplier.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.receipt, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        '${supplier.totalOrders} orders',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'On-time: ${supplier.onTimeDeliveryRate.toStringAsFixed(1)}% | Quality: ${supplier.qualityScore.toStringAsFixed(1)}/100',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: supplier.status == 'approved' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                supplier.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: supplier.status == 'approved' ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
