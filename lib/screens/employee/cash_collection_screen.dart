import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../models/scanner_models.dart';

class CashCollectionScreen extends StatefulWidget {
  const CashCollectionScreen({super.key});

  @override
  State<CashCollectionScreen> createState() => _CashCollectionScreenState();
}

class _CashCollectionScreenState extends State<CashCollectionScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _orderId;
  OrderModel? _order;
  bool _isLoading = false;
  final List<CashCollection> _collections = [];

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _loadOrder(String orderId) async {
    setState(() => _isLoading = true);
    try {
      final orderProvider = context.read<OrderProvider>();
      final order = await orderProvider.getOrderById(orderId);
      if (order == null) throw Exception('Order not found');
      setState(() {
        _orderId = orderId;
        _order = order;
        _amountController.text = order.totalAmount.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Order not found');
    }
  }

  Future<void> _recordCollection() async {
    if (_order == null) {
      _showError('Please enter an order ID');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final service = EmployeeScannerService(
        shopId: authProvider.currentShop?.id ?? '',
        branchId: authProvider.currentBranch?.id ?? '',
        employeeId: authProvider.currentUser?.uid ?? '',
        employeeName: authProvider.currentUser?.name ?? 'Employee',
      );

      await service.recordCashCollection(
        orderId: _order!.id,
        amount: amount,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      setState(() {
        _collections.insert(
          0,
          CashCollection(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            shopId: '',
            branchId: '',
            orderId: _order!.orderNumber,
            deliveryEmployeeId: '',
            deliveryEmployeeName: authProvider.currentUser?.name ?? '',
            amount: amount,
            collectionTime: DateTime.now(),
          ),
        );
        _order = null;
        _orderId = null;
        _amountController.clear();
        _notesController.clear();
        _isLoading = false;
      });

      _showSuccess('Cash collection recorded: ₹$amount');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Collection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showScannerDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_orderId != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order: $_orderId',
                                    style:
                                        const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (_order != null)
                                    Text('Customer: ${_order!.customerName}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _showScannerDialog(),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Order QR'),
                      ),
                  ],
                ),
              ),
            ),

            // Order Info
            if (_order != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Order #', _order!.orderNumber),
                      _buildDetailRow('Customer', _order!.customerName),
                      _buildDetailRow('Phone', _order!.customerPhone),
                      _buildDetailRow(
                          'Total Amount', '₹${_order!.totalAmount}'),
                      _buildDetailRow('Payment Method', _order!.paymentMethod.name),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Collection Form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash Collection',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount Collected (₹)',
                          prefixIcon: Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _recordCollection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Record Collection'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Collections
            if (_collections.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Today\'s Collections',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Collected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${_collections.fold<double>(0, (sum, c) => sum + c.amount).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._collections.map((collection) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Icon(Icons.payments, color: Colors.white),
                      ),
                      title: Text('Order #${collection.orderId}'),
                      subtitle: Text(collection.deliveryEmployeeName),
                      trailing: Text(
                        '₹${collection.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Order ID'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Order ID',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              _loadOrder(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
