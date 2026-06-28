import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_config_provider.dart';
import '../../models/product_model.dart';
import '../../models/scanner_models.dart';
import '../../models/shop_branch_model.dart';
import '../../utils/app_theme.dart';

class InventoryTransferScreen extends StatefulWidget {
  const InventoryTransferScreen({super.key});

  @override
  State<InventoryTransferScreen> createState() =>
      _InventoryTransferScreenState();
}

class _InventoryTransferScreenState extends State<InventoryTransferScreen> {
  String? _scannedBarcode;
  ProductModel? _product;
  final _quantityController = TextEditingController(text: '1');
  String? _selectedDestinationBranchId;
  String? _selectedDestinationBranchName;
  final _notesController = TextEditingController();
  bool _isLoading = false;
  final List<InventoryTransfer> _transfers = [];

  List<ShopBranchModel> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  void _loadBranches() {
    final branchProvider = context.read<ShopConfigProvider>();
    _branches = branchProvider.branches;
    setState(() {});
  }

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
    setState(() => _isLoading = true);
    try {
      final productProvider = context.read<ProductProvider>();
      final product = productProvider.getProductByBarcode(barcode);
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

  Future<void> _requestTransfer() async {
    if (_product == null) {
      _showError('Please scan a product first');
      return;
    }

    if (_selectedDestinationBranchId == null) {
      _showError('Please select destination branch');
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

      final transferId = await service.requestTransfer(
        productId: _product!.id,
        productName: _product!.name,
        barcode: _scannedBarcode ?? '',
        quantity: quantity,
        destinationBranchId: _selectedDestinationBranchId!,
        destinationBranchName: _selectedDestinationBranchName!,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      setState(() {
        _transfers.insert(
          0,
          InventoryTransfer(
            id: transferId,
            shopId: '',
            sourceBranchId: authProvider.currentBranch?.id ?? '',
            sourceBranchName: authProvider.currentBranch?.name ?? '',
            destinationBranchId: _selectedDestinationBranchId!,
            destinationBranchName: _selectedDestinationBranchName!,
            productId: _product!.id,
            productName: _product!.name,
            barcode: _scannedBarcode ?? '',
            quantity: quantity,
            status: TransferStatus.pending,
            requestedBy: authProvider.currentUser?.uid ?? '',
            requestedByName: authProvider.currentUser?.name ?? '',
            requestedAt: DateTime.now(),
          ),
        );
        _product = null;
        _scannedBarcode = null;
        _quantityController.text = '1';
        _notesController.clear();
        _selectedDestinationBranchId = null;
        _selectedDestinationBranchName = null;
        _isLoading = false;
      });

      _showSuccess('Transfer requested: $transferId');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to request transfer: $e');
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Transfer', style: TextStyle(fontWeight: FontWeight.w700)),
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
                      'Scan Product to Transfer',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_scannedBarcode != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz, color: Colors.purple),
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

            // Transfer Form
            if (_product != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Product', _product!.name),
                      _buildDetailRow(
                          'Current Stock', _product!.stockQuantity.toString()),
                      const SizedBox(height: 12),
                      const Text(
                        'Destination Branch',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDestinationBranchId,
                        hint: const Text('Select branch'),
                        items: _branches
                            .where((b) =>
                                b.id !=
                                context.read<AuthProvider>().currentBranch?.id)
                            .map((branch) {
                          return DropdownMenuItem(
                            value: branch.id,
                            child: Text(branch.branchName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          final branch =
                              _branches.firstWhere((b) => b.id == value);
                          setState(() {
                            _selectedDestinationBranchId = value;
                            _selectedDestinationBranchName = branch.branchName;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity to Transfer',
                          prefixIcon: Icon(Icons.numbers),
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
                          onPressed: _isLoading ? null : _requestTransfer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Request Transfer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Transfers
            if (_transfers.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Recent Transfers',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._transfers.map((transfer) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(transfer.status.name),
                        child: const Icon(Icons.swap_horiz, color: Colors.white),
                      ),
                      title: Text(transfer.productName),
                      subtitle: Text(
                          '${transfer.sourceBranchName} → ${transfer.destinationBranchName}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'x${transfer.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            transfer.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getStatusColor(transfer.status.name),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'shipped':
      case 'inTransit':
        return AppTheme.info;
      case 'received':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return Colors.grey;
    }
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