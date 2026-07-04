import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../services/smart_scan_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

class ShelfRefillScreen extends StatefulWidget {
  final String? barcode;

  const ShelfRefillScreen({super.key, this.barcode});

  @override
  State<ShelfRefillScreen> createState() => _ShelfRefillScreenState();
}

class _ShelfRefillScreenState extends State<ShelfRefillScreen> {
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  final SmartScanService _smartScan = SmartScanService();
  final FocusNode _quantityFocusNode = FocusNode();

  String? _scannedBarcode;
  ProductModel? _product;
  bool _isLoading = false;
  final List<RefillItem> _refillHistory = [];

  @override
  void initState() {
    super.initState();
    if (widget.barcode != null) {
      _scannedBarcode = widget.barcode;
      _lookupProduct(widget.barcode!);
    }
  }

  Future<void> _lookupProduct(String barcode) async {
    setState(() {
      _isLoading = true;
    });

    final auth = context.read<AuthProvider>();

    try {
      final result = await _smartScan.autoProduct(
        barcode: barcode,
        shopId: auth.currentShop?.id ?? '',
        branchId: auth.currentBranch?.id ?? '',
      );

      final product =
          result.product ?? context.read<ProductProvider>().getProductByBarcode(barcode);

      if (product != null) {
        setState(() {
          _scannedBarcode = barcode;
          _product = product;
          _isLoading = false;
          _quantityController.text = '5'; // Refill default
        });
        await SmartScanService.hapticSuccess();
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          _quantityFocusNode.requestFocus();
          _quantityController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _quantityController.text.length,
          );
        }
      } else {
        setState(() => _isLoading = false);
        await SmartScanService.hapticError();
        _showError('Product not found: $barcode');
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await SmartScanService.hapticError();
      _showError('Lookup error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.error));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.success));
  }

  Future<void> _performRefill() async {
    if (_product == null) {
      _showError('Please scan a product first');
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

      await service.refillShelf(
        productId: _product!.id,
        barcode: _scannedBarcode ?? '',
        quantity: quantity,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      final productName = _product!.name;

      setState(() {
        _refillHistory.insert(
          0,
          RefillItem(productName: productName, quantity: quantity, timestamp: DateTime.now()),
        );
        _product = null;
        _scannedBarcode = null;
        _quantityController.text = '1';
        _notesController.clear();
        _isLoading = false;
      });

      await SmartScanService.hapticComplete();
      _showSuccess('✓ $quantity × $productName moved to shelf');
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('Failed to refill shelf: $e');
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf Refill', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    Text('Scan Item from Godown', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (_scannedBarcode != null)
                      ListTile(
                        leading: const Icon(Icons.inventory, color: AppTheme.primary),
                        title: Text('Barcode: $_scannedBarcode'),
                        subtitle: Text(_product?.name ?? 'Loading...'),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _showScannerDialog(),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _showScannerDialog(),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Product Barcode'),
                      ),
                  ],
                ),
              ),
            ),

            if (_product != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Refill Details', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _quantityController,
                        focusNode: _quantityFocusNode,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity to move to shelf',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.add_shopping_cart),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _performRefill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Confirm Refill'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_refillHistory.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Recent Refills',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._refillHistory.map(
                (item) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.success,
                      child: Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                    title: Text(item.productName),
                    subtitle: Text('${item.quantity} units moved'),
                    trailing: Text(
                      '${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
              ),
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
          decoration: const InputDecoration(labelText: 'Barcode', border: OutlineInputBorder()),
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
      ),
    );
  }
}

class RefillItem {
  final String productName;
  final int quantity;
  final DateTime timestamp;

  RefillItem({required this.productName, required this.quantity, required this.timestamp});
}
