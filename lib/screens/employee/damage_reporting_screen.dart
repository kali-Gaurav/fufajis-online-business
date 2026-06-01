import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/scanner_models.dart';

class DamageReportingScreen extends StatefulWidget {
  final String? barcode;

  const DamageReportingScreen({super.key, this.barcode});

  @override
  State<DamageReportingScreen> createState() => _DamageReportingScreenState();
}

class _DamageReportingScreenState extends State<DamageReportingScreen> {
  String? _scannedBarcode;
  ProductModel? _product;
  final _quantityController = TextEditingController(text: '1');
  DamageType _selectedDamageType = DamageType.other;
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  final List<DamageReport> _reports = [];

  @override
  void initState() {
    super.initState();
    if (widget.barcode != null) {
      _scannedBarcode = widget.barcode;
      _lookupProduct(widget.barcode!);
    }
  }

  Future<void> _lookupProduct(String barcode) async {
    setState(() => _isLoading = true);
    try {
      final productProvider = context.read<ProductProvider>();
      final product = await productProvider.getProductByBarcode(barcode);
      setState(() {
        _product = product;
        _isLoading = false;
      });
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

  Future<void> _submitReport() async {
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

      await service.reportDamage(
        productId: _product!.id,
        productName: _product!.name,
        barcode: _scannedBarcode ?? '',
        quantity: quantity,
        damageType: _selectedDamageType,
        reason:
            _reasonController.text.isNotEmpty ? _reasonController.text : null,
      );

      setState(() {
        _reports.insert(
          0,
          DamageReport(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            shopId: '',
            branchId: '',
            productId: _product!.id,
            productName: _product!.name,
            barcode: _scannedBarcode ?? '',
            quantity: quantity,
            damageType: _selectedDamageType,
            reason: _reasonController.text,
            employeeId: '',
            employeeName: '',
            reportDate: DateTime.now(),
          ),
        );
        _product = null;
        _scannedBarcode = null;
        _quantityController.text = '1';
        _reasonController.clear();
        _isLoading = false;
      });

      _showSuccess('Damage reported: Stock reduced by $quantity');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Damage Report'),
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
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red),
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
                        label: Text('Scan Damaged Product'),
                      ),
                  ],
                ),
              ),
            ),

            // Product Details
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
                          'Current Stock', _product!.stockQuantity.toString()),
                      _buildDetailRow('Unit', _product!.unit),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Damage Type Selection
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Damage Type',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DamageType.values.map((type) {
                          final isSelected = _selectedDamageType == type;
                          return ChoiceChip(
                            label: Text(
                                type.name.replaceAll('_', ' ').toUpperCase()),
                            selected: isSelected,
                            selectedColor: Colors.red.shade200,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedDamageType = type);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Quantity & Reason
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Quantity Damaged',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        decoration: InputDecoration(
                          labelText: 'Additional Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Report Damage'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Reports
            if (_reports.isNotEmpty) ...[
              SizedBox(height: 24),
              Text(
                'Recent Reports',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              ..._reports.take(5).map((report) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.report_problem, color: Colors.white),
                        backgroundColor: Colors.red,
                      ),
                      title: Text(report.productName),
                      subtitle: Text(
                          '${report.damageType.name}: ${report.quantity} units'),
                      trailing: Icon(Icons.check_circle, color: Colors.green),
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
