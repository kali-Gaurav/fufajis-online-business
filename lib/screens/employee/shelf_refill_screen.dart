import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
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
        _currentQuantityController.text = '3';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Product not found: $barcode');
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
      });

      _showSuccess('Shelf refill alert created');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shelf Refill'),
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
                      'Scan Shelf or Product',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 12),
                    if (_scannedBarcode != null)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.amber),
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

            // Refill Form
            if (_product != null) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shelf Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _currentQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Current Shelf Quantity',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _minimumQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Minimum Required',
                          prefixIcon: Icon(Icons.warning),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _reportRefillNeeded,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Report Refill Needed'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Alerts
            if (_alerts.isNotEmpty) ...[
              SizedBox(height: 24),
              Text(
                'Recent Alerts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              ..._alerts.map((alert) => Card(
                    color:
                        alert.needsRefill ? Colors.amber.shade50 : Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.warning, color: Colors.white),
                        backgroundColor: Colors.amber,
                      ),
                      title: Text(alert.productName),
                      subtitle: Text('Shelf: ${alert.shelfName}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${alert.currentShelfQuantity}/${alert.minimumQuantity}',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
