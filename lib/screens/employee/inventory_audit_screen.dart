import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/scanner_models.dart';

class InventoryAuditScreen extends StatefulWidget {
  final String? auditId;

  const InventoryAuditScreen({super.key, this.auditId});

  @override
  State<InventoryAuditScreen> createState() => _InventoryAuditScreenState();
}

class _InventoryAuditScreenState extends State<InventoryAuditScreen> {
  String? _scannedBarcode;
  ProductModel? _product;
  int _actualStock = 0;
  final _notesController = TextEditingController();
  bool _isLoading = false;
  final List<AuditResult> _auditResults = [];

  @override
  void initState() {
    super.initState();
    if (widget.auditId != null) {
      // Load existing audit
    }
  }

  Future<void> _lookupProduct(String barcode) async {
    setState(() => _isLoading = true);
    try {
      final productProvider = context.read<ProductProvider>();
      final product = await productProvider.getProductByBarcode(barcode);
      if (product != null) {
        setState(() {
          _scannedBarcode = barcode;
          _product = product;
          _actualStock = product.stockQuantity;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError('Product not found: $barcode');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Product not found: $barcode');
    }
  }

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

  Future<void> _submitAudit() async {
    if (_product == null) {
      _showError('Please scan a product first');
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

      final auditId = await service.createAuditRecord(
        productId: _product!.id,
        productName: _product!.name,
        barcode: _scannedBarcode ?? '',
        expectedStock: _product!.stockQuantity,
        actualStock: _actualStock,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      final difference = _actualStock - _product!.stockQuantity;

      setState(() {
        _auditResults.insert(
          0,
          AuditResult(
            id: auditId,
            productName: _product!.name,
            barcode: _scannedBarcode ?? '',
            expectedStock: _product!.stockQuantity,
            actualStock: _actualStock,
            difference: difference,
            timestamp: DateTime.now(),
          ),
        );
        _product = null;
        _scannedBarcode = null;
        _actualStock = 0;
        _notesController.clear();
        _isLoading = false;
      });

      if (difference == 0) {
        _showSuccess('Audit complete: Stock matches');
      } else {
        _showSuccess('Audit complete: Difference of $difference');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to submit audit: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock Audit'),
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
                      'Scan Product',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 12),
                    if (_scannedBarcode != null)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.qr_code, color: Colors.blue),
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

            // Product Details & Count
            if (_product != null) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 12),
                      _buildDetailRow('Name', _product!.name),
                      _buildDetailRow(
                          'Expected Stock', _product!.stockQuantity.toString()),
                      _buildDetailRow('Barcode', _scannedBarcode ?? ''),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Actual Count Input
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Count Actual Stock',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 12),
                      TextFormField(
                        onChanged: (value) {
                          setState(() {
                            _actualStock = int.tryParse(value) ?? 0;
                          });
                        },
                        initialValue: _actualStock.toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Actual Count',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitAudit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Submit Audit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Quick Count Buttons
            if (_product != null)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Count',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [0, 5, 10, 20, 50, 100].map((qty) {
                          return ActionChip(
                            label: Text('$qty'),
                            onPressed: () {
                              setState(() => _actualStock = qty);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Audit Results
            if (_auditResults.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audit Results',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _auditResults.clear()),
                    child: Text('Clear All'),
                  ),
                ],
              ),
              SizedBox(height: 8),
              ..._auditResults.map((result) {
                final hasDiscrepancy = result.difference != 0;
                return Card(
                  color: hasDiscrepancy
                      ? (result.difference > 0
                          ? Colors.green.shade50
                          : Colors.red.shade50)
                      : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        hasDiscrepancy ? Icons.warning : Icons.check_circle,
                        color: Colors.white,
                      ),
                      backgroundColor: hasDiscrepancy
                          ? (result.difference > 0 ? Colors.green : Colors.red)
                          : Colors.grey,
                    ),
                    title: Text(result.productName),
                    subtitle: Text('Expected: ${result.expectedStock}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Actual: ${result.actualStock}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          result.differenceDisplay,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasDiscrepancy
                                ? (result.difference > 0
                                    ? Colors.green
                                    : Colors.red)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Summary
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Total Audited',
                        _auditResults.length.toString(),
                      ),
                      _buildSummaryItem(
                        'Discrepancies',
                        _auditResults
                            .where((r) => r.hasDiscrepancy)
                            .length
                            .toString(),
                      ),
                      _buildSummaryItem(
                        'Total Variance',
                        _auditResults
                            .fold<int>(
                              0,
                              (sum, r) => sum + r.difference,
                            )
                            .toString(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
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

class AuditResult {
  final String id;
  final String productName;
  final String barcode;
  final int expectedStock;
  final int actualStock;
  final int difference;
  final DateTime timestamp;

  AuditResult({
    required this.id,
    required this.productName,
    required this.barcode,
    required this.expectedStock,
    required this.actualStock,
    required this.difference,
    required this.timestamp,
  });

  String get differenceDisplay {
    if (difference > 0) return '+$difference';
    return difference.toString();
  }

  bool get hasDiscrepancy => difference != 0;
}
