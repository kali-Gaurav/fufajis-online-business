import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../services/smart_scan_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/scanner_models.dart';

class ShelfRefillScreen extends StatefulWidget {
  const ShelfRefillScreen({super.key});

  @override
  State<ShelfRefillScreen> createState() => _ShelfRefillScreenState();
}

class _ShelfRefillScreenState extends State<ShelfRefillScreen> {
  String? _scannedShelfId;
  String? _scannedBarcode;
  ProductModel? _product;
  final _currentQuantityController = TextEditingController();
  final _minimumQuantityController = TextEditingController(text: '10');
  bool _isLoading = false;
  final List<ShelfRefillAlert> _alerts = [];

  // Auto-complete additions
  final _countFocusNode = FocusNode();     // auto-focused after scan
  final SmartScanService _smartScan = SmartScanService();
  int _batchCount = 0;                     // scans processed this session
  int _dbStock = 0;                        // stock level from Firestore
  bool _autoFilled = false;

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

      if (result.found) {
        setState(() {
          _scannedBarcode = barcode;
          _product = result.product;
          _dbStock = result.dbStock;
          // Auto-fill current qty from real DB stock — employee just
          // counts what's actually on the shelf and compares
          _currentQuantityController.text = result.dbStock.toString();
          _isLoading = false;
          _autoFilled = true;
        });
        await SmartScanService.hapticSuccess();
        // Auto-focus the count field so employee just types the real count
        await Future.delayed(const Duration(milliseconds: 120));
        _countFocusNode.requestFocus();
        _currentQuantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _currentQuantityController.text.length,
        );
      } else {
        // Fallback to in-memory cache
        final product =
            context.read<ProductProvider>().getProductByBarcode(barcode);
        setState(() {
          _scannedBarcode = barcode;
          _product = product;
          _dbStock = product?.stockQuantity ?? 0;
          _currentQuantityController.text =
              product != null ? product.stockQuantity.toString() : '';
          _isLoading = false;
          _autoFilled = product != null;
        });
        if (product != null) {
          await SmartScanService.hapticSuccess();
          await Future.delayed(const Duration(milliseconds: 120));
          _countFocusNode.requestFocus();
          _currentQuantityController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _currentQuantityController.text.length,
          );
        } else {
          await SmartScanService.hapticError();
          _showError('Product not found: $barcode');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      await SmartScanService.hapticError();
      _showError('Lookup error: $e');
    }
  }

  Future<void> _reportRefillNeeded() async {
    if (_product == null) {
      _showError('Please scan a product first');
      return;
    }

    final currentQty = int.tryParse(_currentQuantityController.text) ?? 0;
    final minimumQty = int.tryParse(_minimumQuantityController.text) ?? 10;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final service = EmployeeScannerService(
        shopId: authProvider.currentShop?.id ?? '',
        branchId: authProvider.currentBranch?.id ?? '',
        employeeId: authProvider.currentUser?.uid ?? '',
        employeeName: authProvider.currentUser?.name ?? 'Employee',
      );

      await service.reportShelfRefill(
        shelfId:
            _scannedShelfId ?? 'SHELF-${DateTime.now().millisecondsSinceEpoch}',
        shelfName:
            _scannedShelfId?.replaceFirst('SHELF-', '') ?? 'Unknown Shelf',
        productId: _product!.id,
        productName: _product!.name,
        barcode: _scannedBarcode ?? '',
        currentShelfQuantity: currentQty,
        minimumQuantity: minimumQty,
      );

      setState(() {
        _alerts.insert(
          0,
          ShelfRefillAlert(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            shopId: '',
            branchId: '',
            shelfId: _scannedShelfId ?? '',
            shelfName: _scannedShelfId?.replaceFirst('SHELF-', '') ?? 'Unknown',
            productId: _product!.id,
            productName: _product!.name,
            barcode: _scannedBarcode ?? '',
            currentShelfQuantity: currentQty,
            minimumQuantity: minimumQty,
            alertDate: DateTime.now(),
          ),
        );
        _product = null;
        _scannedBarcode = null;
        _scannedShelfId = null;
        _currentQuantityController.clear();
        _isLoading = false;
        _autoFilled = false;
        _dbStock = 0;
        _batchCount++;
      });

      await SmartScanService.hapticComplete();
      _showSuccess(
          '✓ Shelf alert saved  •  $_batchCount item${_batchCount == 1 ? '' : 's'} audited this session');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf Refill'),
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
                      'Scan Shelf or Product',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_scannedBarcode != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.amber),
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

            // Refill Form
            if (_product != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shelf Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      // DB stock hint
                      if (_autoFilled && _dbStock > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'DB stock: $_dbStock  —  enter what you actually see on the shelf',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _currentQuantityController,
                        focusNode: _countFocusNode, // auto-focused after scan
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _reportRefillNeeded(),
                        decoration: InputDecoration(
                          labelText: 'Actual Shelf Count *',
                          prefixIcon: const Icon(Icons.numbers),
                          border: const OutlineInputBorder(),
                          enabledBorder: _autoFilled
                              ? OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.orange.shade400,
                                      width: 2))
                              : null,
                          helperText:
                              _autoFilled ? 'Auto-filled from DB — update if different' : null,
                          helperStyle: const TextStyle(
                              color: Colors.orange),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _minimumQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Required',
                          prefixIcon: Icon(Icons.warning),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _reportRefillNeeded,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Report Refill Needed'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Alerts
            if (_alerts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Recent Alerts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._alerts.map((alert) => Card(
                    color:
                        alert.needsRefill ? Colors.amber.shade50 : Colors.white,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                        child: Icon(Icons.warning, color: Colors.white),
                      ),
                      title: Text(alert.productName),
                      subtitle: Text('Shelf: ${alert.shelfName}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${alert.currentShelfQuantity}/${alert.minimumQuantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            alert.needsRefill ? 'Refill!' : 'OK',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  alert.needsRefill ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
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
        title: const Text('Enter Barcode'),
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
