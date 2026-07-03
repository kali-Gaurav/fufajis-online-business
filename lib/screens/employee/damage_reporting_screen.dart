import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../services/smart_scan_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/scanner_models.dart';
import '../../utils/app_theme.dart';

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

  // Smart-scan additions
  final _quantityFocusNode = FocusNode();
  final SmartScanService _smartScan = SmartScanService();
  int _batchCount = 0;
  bool _autoFilled = false;

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
      _autoFilled = false;
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

      setState(() {
        _scannedBarcode = barcode;
        _product = product;
        _isLoading = false;
        _autoFilled = product != null;
        // Auto-suggest damage type based on category
        if (product != null) {
          final cat = product.category.toLowerCase();
          if (cat.contains('dairy') || cat.contains('doodh') || cat.contains('liquid')) {
            _selectedDamageType = DamageType.leaking;
          } else if (cat.contains('glass') || cat.contains('bottle')) {
            _selectedDamageType = DamageType.broken;
          } else if (cat.contains('biscuit') || cat.contains('snack') || cat.contains('packet')) {
            _selectedDamageType = DamageType.damagedPackaging;
          }
        }
      });

      if (product != null) {
        await SmartScanService.hapticSuccess();
        await Future.delayed(const Duration(milliseconds: 120));
        _quantityFocusNode.requestFocus();
        _quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _quantityController.text.length,
        );
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
        reason: _reasonController.text.isNotEmpty ? _reasonController.text : null,
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
        _autoFilled = false;
        _selectedDamageType = DamageType.other;
        _batchCount++;
      });

      await SmartScanService.hapticComplete();
      _showSuccess(
        '✓ Damage reported  •  $_batchCount report${_batchCount == 1 ? '' : 's'} this session',
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to report: $e');
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Damage Report', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    Text('Scan Product', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (_scannedBarcode != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: AppTheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Barcode: $_scannedBarcode',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                        label: const Text('Scan Damaged Product'),
                      ),
                  ],
                ),
              ),
            ),

            // Product Details
            if (_product != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Product Details', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _buildDetailRow('Name', _product!.name),
                      _buildDetailRow('Current Stock', _product!.stockQuantity.toString()),
                      _buildDetailRow('Unit', _product!.unit),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Damage Type Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Damage Type', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DamageType.values.map((type) {
                          final isSelected = _selectedDamageType == type;
                          return ChoiceChip(
                            label: Text(type.name.replaceAll('_', ' ').toUpperCase()),
                            selected: isSelected,
                            selectedColor: AppTheme.error,
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

              const SizedBox(height: 16),

              // Quantity & Reason
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Details', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _quantityController,
                        focusNode: _quantityFocusNode,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitReport(),
                        decoration: InputDecoration(
                          labelText: 'Quantity Damaged *',
                          prefixIcon: const Icon(Icons.numbers),
                          border: const OutlineInputBorder(),
                          enabledBorder: _autoFilled
                              ? const OutlineInputBorder(
                                  borderSide: BorderSide(color: AppTheme.error, width: 2),
                                )
                              : null,
                          helperText: _autoFilled
                              ? 'Auto-focused — enter damaged count, then press Enter'
                              : null,
                          helperStyle: const TextStyle(color: AppTheme.warning),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Report Damage'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Reports
            if (_reports.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Recent Reports', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._reports
                  .take(5)
                  .map(
                    (report) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.error,
                          child: Icon(Icons.report_problem, color: Colors.white),
                        ),
                        title: Text(report.productName),
                        subtitle: Text('${report.damageType.name}: ${report.quantity} units'),
                        trailing: const Icon(Icons.check_circle, color: AppTheme.success),
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
