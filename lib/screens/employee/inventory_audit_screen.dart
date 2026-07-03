import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../services/smart_scan_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

class InventoryAuditScreen extends StatefulWidget {
  final String? auditId;
  final String? barcode;

  const InventoryAuditScreen({super.key, this.auditId, this.barcode});

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

  // Auto-complete additions
  final _actualCountFocusNode = FocusNode();
  final _actualCountController = TextEditingController(text: '0');
  final SmartScanService _smartScan = SmartScanService();
  int _expectedStock = 0; // from DB — shown as reference
  int _discrepancyTotal = 0; // running session tally
  bool _autoFilled = false;

  @override
  void initState() {
    super.initState();
    if (widget.barcode != null) {
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

      if (product != null) {
        setState(() {
          _scannedBarcode = barcode;
          _product = product;
          _expectedStock = result.dbStock > 0 ? result.dbStock : product.stockQuantity;
          // Pre-fill actual count with expected — employee just
          // corrects it if wrong (saves time when stock matches)
          _actualStock = _expectedStock;
          _actualCountController.text = _expectedStock.toString();
          _isLoading = false;
          _autoFilled = true;
        });
        await SmartScanService.hapticSuccess();
        await Future.delayed(const Duration(milliseconds: 120));
        // Auto-focus + select-all so employee can type to override
        _actualCountFocusNode.requestFocus();
        _actualCountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _actualCountController.text.length,
        );
      } else {
        setState(() => _isLoading = false);
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

  Future<void> _submitAudit() async {
    if (_product == null) {
      _showError('Please scan a product first');
      return;
    }

    // Read actual count from the dedicated controller
    final actualCount = int.tryParse(_actualCountController.text) ?? _actualStock;
    setState(() {
      _actualStock = actualCount;
      _isLoading = true;
    });

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
        expectedStock: _expectedStock,
        actualStock: actualCount,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      final difference = actualCount - _expectedStock;
      _discrepancyTotal += difference.abs();

      setState(() {
        _auditResults.insert(
          0,
          AuditResult(
            id: auditId,
            productName: _product!.name,
            barcode: _scannedBarcode ?? '',
            expectedStock: _expectedStock,
            actualStock: actualCount,
            difference: difference,
            timestamp: DateTime.now(),
          ),
        );
        // Auto-reset for next scan immediately
        _product = null;
        _scannedBarcode = null;
        _actualStock = 0;
        _expectedStock = 0;
        _actualCountController.text = '0';
        _notesController.clear();
        _isLoading = false;
        _autoFilled = false;
      });

      await SmartScanService.hapticComplete();

      final msg = difference == 0
          ? '✓ Stock matches  •  ${_auditResults.length} scanned'
          : '${difference > 0 ? '+' : ''}$difference  •  ${_auditResults.length} scanned  •  total gap: $_discrepancyTotal';
      _showSuccess(msg);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to submit audit: $e');
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _actualCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Audit', style: TextStyle(fontWeight: FontWeight.w700)),
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
                          color: AppTheme.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code, color: AppTheme.info),
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
                        label: const Text('Scan Product'),
                      ),
                  ],
                ),
              ),
            ),

            // Product Details & Count
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
                      _buildDetailRow('Expected Stock', _product!.stockQuantity.toString()),
                      _buildDetailRow('Barcode', _scannedBarcode ?? ''),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Actual Count Input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Count Actual Stock',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          // Running discrepancy tally
                          if (_auditResults.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _discrepancyTotal == 0
                                    ? AppTheme.success.withValues(alpha: 0.1)
                                    : AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_auditResults.length} scanned  •  gap: ${_discrepancyTotal > 0 ? '+' : ''}$_discrepancyTotal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _discrepancyTotal == 0
                                      ? AppTheme.success
                                      : AppTheme.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Expected stock reference
                      if (_autoFilled)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: AppTheme.info,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'DB expects: ',
                                style: TextStyle(fontSize: 12, color: AppTheme.info),
                              ),
                              Text(
                                '$_expectedStock',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.info,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                '  —  enter what you physically counted',
                                style: TextStyle(fontSize: 12, color: AppTheme.info),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _actualCountController,
                        focusNode: _actualCountFocusNode,
                        onChanged: (value) =>
                            setState(() => _actualStock = int.tryParse(value) ?? 0),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitAudit(),
                        decoration: InputDecoration(
                          labelText: 'Actual Count *',
                          prefixIcon: const Icon(Icons.numbers),
                          border: const OutlineInputBorder(),
                          enabledBorder: _autoFilled
                              ? const OutlineInputBorder(
                                  borderSide: BorderSide(color: AppTheme.warning, width: 2),
                                )
                              : null,
                          helperText: _autoFilled
                              ? 'Pre-filled from DB — change if different'
                              : null,
                          helperStyle: const TextStyle(color: AppTheme.warning),
                          // Live discrepancy hint
                          suffixText: _autoFilled && _expectedStock > 0
                              ? (_actualStock - _expectedStock) == 0
                                    ? '✓ match'
                                    : '${_actualStock - _expectedStock > 0 ? '+' : ''}${_actualStock - _expectedStock}'
                              : null,
                          suffixStyle: TextStyle(
                            color: (_actualStock - _expectedStock) == 0
                                ? AppTheme.success
                                : AppTheme.error,
                            fontWeight: FontWeight.bold,
                          ),
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
                          onPressed: _isLoading ? null : _submitAudit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warning,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Submit Audit'),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Count', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
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

            const SizedBox(height: 16),

            // Audit Results
            if (_auditResults.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Audit Results', style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: () => setState(() => _auditResults.clear()),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._auditResults.map((result) {
                final hasDiscrepancy = result.difference != 0;
                return Card(
                  color: hasDiscrepancy
                      ? (result.difference > 0
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.error.withValues(alpha: 0.1))
                      : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: hasDiscrepancy
                          ? (result.difference > 0 ? AppTheme.success : AppTheme.error)
                          : Colors.grey,
                      child: Icon(
                        hasDiscrepancy ? Icons.warning : Icons.check_circle,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(result.productName),
                    subtitle: Text('Expected: ${result.expectedStock}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Actual: ${result.actualStock}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          result.differenceDisplay,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasDiscrepancy
                                ? (result.difference > 0 ? AppTheme.success : AppTheme.error)
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Total Audited', _auditResults.length.toString()),
                      _buildSummaryItem(
                        'Discrepancies',
                        _auditResults.where((r) => r.hasDiscrepancy).length.toString(),
                      ),
                      _buildSummaryItem(
                        'Total Variance',
                        _auditResults.fold<int>(0, (sum, r) => sum + r.difference).toString(),
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

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
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
              _lookupProduct(value);
            }
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
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
