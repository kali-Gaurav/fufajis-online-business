import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_client.dart';

class BulkSupplierPaymentScreen extends StatefulWidget {
  const BulkSupplierPaymentScreen({Key? key}) : super(key: key);

  @override
  State<BulkSupplierPaymentScreen> createState() =>
      _BulkSupplierPaymentScreenState();
}

class _BulkSupplierPaymentScreenState extends State<BulkSupplierPaymentScreen> {
  final _supabase = Supabase.instance;
  List<PendingPayment> _pendingPayments = [];
  Set<String> _selectedSuppliers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPendingPayments();
  }

  Future<void> _loadPendingPayments() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all suppliers with pending balances
      final suppliers = await _supabase.client
          .from('suppliers')
          .select()
          .gt('total_pending', 0)
          .order('total_pending', ascending: false);

      setState(() {
        _pendingPayments = suppliers
            .map((s) => PendingPayment.fromJson(s))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading pending payments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double get _totalSelectedAmount {
    return _selectedSuppliers.fold(0, (sum, supplierId) {
      final payment = _pendingPayments.firstWhere(
        (p) => p.id == supplierId,
        orElse: () => PendingPayment.empty(),
      );
      return sum + payment.totalPending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Supplier Payments'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingPayments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green[400],
                      ),
                      const SizedBox(height: 16),
                      const Text('All suppliers are paid up!'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendingPayments.length,
                        itemBuilder: (_, index) =>
                            _buildPaymentCheckbox(_pendingPayments[index]),
                      ),
                    ),
                    _buildSummaryAndAction(),
                  ],
                ),
    );
  }

  Widget _buildPaymentCheckbox(PendingPayment payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: _selectedSuppliers.contains(payment.id),
              onChanged: (selected) {
                setState(() {
                  if (selected ?? false) {
                    _selectedSuppliers.add(payment.id);
                  } else {
                    _selectedSuppliers.remove(payment.id);
                  }
                });
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    payment.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.receipt, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        '${payment.totalOrders} orders',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        payment.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${payment.totalPending.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PENDING',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryAndAction() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selected count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected: ${_selectedSuppliers.length} supplier(s)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Total: ₹${_totalSelectedAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Select All / Clear All
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _selectedSuppliers.length == _pendingPayments.length
                      ? () => setState(() => _selectedSuppliers.clear())
                      : () => setState(() => _selectedSuppliers = Set.from(
                            _pendingPayments.map((p) => p.id),
                          )),
                  child: Text(
                    _selectedSuppliers.length == _pendingPayments.length
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedSuppliers.isEmpty
                      ? null
                      : () => _showPaymentConfirmation(),
                  child: const Text('Process Payments'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentConfirmation() async {
    final selectedPayments = _pendingPayments
        .where((p) => _selectedSuppliers.contains(p.id))
        .toList();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to pay ${selectedPayments.length} supplier(s):',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: selectedPayments.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            '₹${p.totalPending.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount:'),
                  Text(
                    '₹${_totalSelectedAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _processBulkPayment(selectedPayments);
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  Future<void> _processBulkPayment(List<PendingPayment> payments) async {
    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing payments...'),
          ],
        ),
      ),
    );

    try {
      // Call backend to initiate bulk payments via Razorpay Route API
      await ApiClient.instance.post(
        '/suppliers/bulk-payment',
        {
          'supplier_ids': payments.map((p) => p.id).toList(),
          'amounts': payments.map((p) => p.totalPending).toList(),
          'total_amount': _totalSelectedAmount,
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close processing dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payments initiated successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Refresh list
        setState(() => _selectedSuppliers.clear());
        await _loadPendingPayments();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close processing dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class PendingPayment {
  final String id;
  final String name;
  final String email;
  final double rating;
  final int totalOrders;
  final double totalPending;

  PendingPayment({
    required this.id,
    required this.name,
    required this.email,
    required this.rating,
    required this.totalOrders,
    required this.totalPending,
  });

  factory PendingPayment.fromJson(Map<String, dynamic> json) {
    return PendingPayment(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalOrders: json['total_orders'] ?? 0,
      totalPending: (json['total_pending'] ?? 0.0).toDouble(),
    );
  }

  factory PendingPayment.empty() {
    return PendingPayment(
      id: '',
      name: '',
      email: '',
      rating: 0,
      totalOrders: 0,
      totalPending: 0,
    );
  }
}
