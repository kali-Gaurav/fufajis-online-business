import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/employee_scanner_service.dart';
import '../../services/smart_scan_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/scanner_models.dart';
import '../../utils/app_theme.dart';

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

  // Smart-scan additions
  final _orderIdFocusNode = FocusNode();
  final SmartScanService _smartScan = SmartScanService();
  int _batchCount = 0;
  bool _autoFilled = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.success),
    );
  }

  Future<void> _lookupProduct(String barcode) async {
    setState(() {
      _isLoading = true;
      _autoFilled = false;
    });

    final auth = context.read<AuthProvider>();

    try {
      final result = await _smartScan.autoProduct(
        barcode: barcode,
        shopId: auth.currentShop?.id ?? '',
        branchId: auth.currentBranch?.id ?? '',
      );

      final product = result.product ??
          context.read<ProductProvider>().getProductByBarcode(barcode);

      // Try to find the most recent delivered order containing this product
      String? autoOrderId;
      if (product != null) {
        try {
          final orderSnap = await FirebaseFirestore.instance
              .collection('shops')
              .doc(auth.currentShop?.id ?? 'shop_001')
              .collection('orders')
              .where('status', isEqualTo: 'delivered')
              .orderBy('deliveredAt', descending: true)
              .limit(20)
              .get();

          for (final doc in orderSnap.docs) {
            final items = (doc.data()['items'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
            if (items.any((i) =>
                i['productId'] == product.id ||
                i['barcode'] == barcode)) {
              autoOrderId = doc.id;
              break;
            }
          }
        } catch (_) {}
      }

      setState(() {
        _scannedBarcode = barcode;
        _product = product;
        _isLoading = false;
        _autoFilled = product != null;
        if (autoOrderId != null && _orderIdController.text.isEmpty) {
          _orderIdController.text = autoOrderId;
        }
      });

      if (product != null) {
        await SmartScanService.hapticSuccess();
        // Auto-focus order ID only if not pre-filled, else focus quantity
        await Future.delayed(const Duration(milliseconds: 120));
        _orderIdFocusNode.requestFocus();
      } else {
        await SmartScanService.hapticError();
        _showError('Product not found: $barcode');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      await SmartScanService.hapticError();
      _showError('Lookup error: $e');
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
        _autoFilled = false;
        _batchCount++;
      });

      await SmartScanService.hapticComplete();
      _showSuccess(
          '✓ Return processed  •  $_batchCount return${_batchCount == 1 ? '' : 's'} this session');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to process return: $e');
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Returns Processing', style: TextStyle(fontWeight: FontWeight.w700)),
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
            // Scan Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Returned Product',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_scannedBarcode != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.brown.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.replay, color: Colors.brown),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Barcode: $_scannedBarcode',
                                    style:
                                        const TextStyle(fontWeight: FontWeight.bold),
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
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Product'),
                      ),
                  ],
                ),
              ),
            ),

            // Return Form
            if (_product != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _orderIdController,
                        focusNode: _orderIdFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Order ID',
                          prefixIcon: const Icon(Icons.receipt),
                          border: const OutlineInputBorder(),
                          enabledBorder: _autoFilled &&
                                  _orderIdController.text.isNotEmpty
                              ? const OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: AppTheme.success,
                                      width: 2))
                              : null,
                          helperText: _autoFilled &&
                                  _orderIdController.text.isNotEmpty
                              ? '✓ Auto-matched from last delivery'
                              : null,
                          helperStyle:
                              const TextStyle(color: AppTheme.success),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Condition',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Return Reason (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _processReturn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Process Return'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Returns
            if (_returns.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Recent Returns',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._returns.take(5).map((returnItem) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.brown,
                        child: Icon(Icons.replay, color: Colors.white),
                      ),
                      title: Text(returnItem.productName),
                      subtitle: Text(
                          'Order: ${returnItem.orderId} • ${returnItem.condition.name}'),
                      trailing: Text(
                        'x${returnItem.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
        title: const Text('Enter Barcode', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
