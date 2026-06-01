import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/scanner_models.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  String? _scannedBarcode;
  ProductModel? _product;
  final _orderIdController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  ReturnCondition _selectedCondition = ReturnCondition.opened;
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  final List<ReturnRecord> _returns = [];

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

  Future<void> _lookupProduct(String barcode) async {
    setState(() => _isLoading = true);
    try {
      final productProvider = context.read<ProductProvider>();
      final product = await productProvider.getProductByBarcode(barcode);
      setState(() {
        _scannedBarcode = barcode;
        _product = product;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Product not found: $barcode');
    }
  }

  Future<void> _processReturn() async {
    if (_product == null) {
      _showError('Please scan a product first');
      return;
    }

    final orderId = _orderIdController.text.trim();
    if (orderId.isEmpty) {
      _showError('Please enter order ID');
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showError('Please enter a valid quantity');
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

      await service.processReturn(
        orderId: orderId,
        productId: _product!.id,
        productName: _product!.name,
        barcode: _scannedBarcode ?? '',
        quantity: quantity,
        condition: _selectedCondition,
        reason:
            _reasonController.text.isNotEmpty ? _reasonController.text : null,
      );

      setState(() {
        _returns.insert(
          0,
          ReturnRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            shopId: '',
            branchId: '',
            orderId: orderId,
            productId: _product!.id,
            productName: _product!.name,
            barcode: _scannedBarcode ?? '',
            quantity: quantity,
            condition: _selectedCondition,
            reason: _reasonController.text,
            employeeId: '',
            employeeName: authProvider.currentUser?.name ?? '',
            returnDate: DateTime.now(),
          ),
        );
        _product = null;
        _scannedBarcode = null;
        _orderIdController.clear();
        _quantityController.text = '1';
        _reasonController.clear();
        _isLoading = false;
      });

      _showSuccess('Return processed: Stock restored by $quantity');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to process return: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Returns Processing'),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner),
            onPressed: () => _showScannerDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scan Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Returned Product',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 12),
                    if (_scannedBarcode != null)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.brown.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.replay, color: Colors.brown),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Barcode: $_scannedBarcode',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (_product != null) Text(_product!.name),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _showScannerDialog(),
                        icon: Icon(Icons.qr_code_scanner),
                        label: Text('Scan Product'),
                      ),
                  ],
                ),
              ),
            ),

            // Return Form
            if (_product != null) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _orderIdController,
                        decoration: InputDecoration(
                          labelText: 'Order ID',
                          prefixIcon: Icon(Icons.receipt),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Condition',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ReturnCondition.values.map((condition) {
                          final isSelected = _selectedCondition == condition;
                          return ChoiceChip(
                            label: Text(condition.name
                                .replaceAll('_', ' ')
                                .toUpperCase()),
                            selected: isSelected,
                            selectedColor: Colors.brown.shade200,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCondition = condition);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        decoration: InputDecoration(
                          labelText: 'Return Reason (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _processReturn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Process Return'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Returns
            if (_returns.isNotEmpty) ...[
              SizedBox(height: 24),
              Text(
                'Recent Returns',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              ..._returns.take(5).map((returnItem) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.replay, color: Colors.white),
                        backgroundColor: Colors.brown,
                      ),
                      title: Text(returnItem.productName),
                      subtitle: Text(
                          'Order: ${returnItem.orderId} • ${returnItem.condition.name}'),
                      trailing: Text(
                        'x${returnItem.quantity}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  void _showScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Barcode'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Barcode',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              setState(() {
                _scannedBarcode = value;
              });
              _lookupProduct(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
