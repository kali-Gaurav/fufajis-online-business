import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';
import 'bill_scanner_screen.dart';

// ─────────────── DATA MODEL ───────────────

class _ReceivedItem {
  String productId;
  String productName;
  String barcode;
  double receivedQty;
  String unit;
  double costPerUnit;
  bool isVerified;

  _ReceivedItem({
    this.productId = '',
    required this.productName,
    this.barcode = '',
    required this.receivedQty,
    required this.unit,
  }) : costPerUnit = 0.0,
       isVerified = false;

  bool get isValid => productName.isNotEmpty && receivedQty > 0;
}

// ─────────────── SCREEN ───────────────

class InventoryReceivingScreen extends StatefulWidget {
  const InventoryReceivingScreen({super.key});

  @override
  State<InventoryReceivingScreen> createState() => _InventoryReceivingScreenState();
}

class _InventoryReceivingScreenState extends State<InventoryReceivingScreen>
    with SingleTickerProviderStateMixin {
  final List<_ReceivedItem> _items = [];
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isScannerActive = false;
  bool _isSubmitting = false;
  String? _scanFeedback;
  String _supplierName = '';
  String _invoiceNumber = '';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // ── Bill Scanner Integration ──────────────────

  Future<void> _openBillScanner() async {
    final result = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(builder: (_) => const BillScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        for (final item in result) {
          _items.add(
            _ReceivedItem(
              productName: item['name']?.toString() ?? '',
              receivedQty: (item['quantity'] as num?)?.toDouble() ?? 1.0,
              unit: item['unit']?.toString() ?? 'kg',
            ),
          );
        }
      });
      _showSnackBar('${result.length} items bill se auto-fill ho gaye!', isSuccess: true);
    }
  }

  // ── Barcode Scanner ──────────────────────────

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue ?? '';
    if (code.isEmpty) return;

    // Pause scanner briefly to avoid duplicate reads
    _scannerController.stop();

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final product = productProvider.getProductByBarcode(code);

    if (product != null) {
      setState(() {
        _scanFeedback = 'Mila: ${product.name}';
        _items.add(
          _ReceivedItem(
            productId: product.id,
            productName: product.name,
            barcode: code,
            receivedQty: 1.0,
            unit: product.unit,
          ),
        );
        _isScannerActive = false;
      });
      _showSnackBar('${product.name} list mein add ho gaya!', isSuccess: true);
    } else {
      // Try Firestore directly (barcode may not be in-memory cache)
      try {
        final snap = await FirebaseFirestore.instance
            .collection('products')
            .where('barcode', isEqualTo: code)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          final p = ProductModel.fromMap(snap.docs.first.data());
          setState(() {
            _items.add(
              _ReceivedItem(
                productId: p.id,
                productName: p.name,
                barcode: code,
                receivedQty: 1.0,
                unit: p.unit,
              ),
            );
            _isScannerActive = false;
            _scanFeedback = 'Mila: ${p.name}';
          });
          _showSnackBar('${p.name} list mein add ho gaya!', isSuccess: true);
        } else {
          setState(() {
            _scanFeedback = 'Barcode $code - product nahi mila, manually add karein';
            _items.add(
              _ReceivedItem(barcode: code, productName: '', receivedQty: 1.0, unit: 'piece'),
            );
          });
          // Resume scanner after a moment
          await Future.delayed(const Duration(seconds: 2));
          if (mounted && _isScannerActive) _scannerController.start();
        }
      } catch (e) {
        setState(() => _scanFeedback = 'Scan error: $e');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && _isScannerActive) _scannerController.start();
      }
    }
  }

  // ── Batch Confirm ────────────────────────────

  Future<void> _confirmAllReceived() async {
    final validItems = _items.where((i) => i.isValid).toList();
    if (validItems.isEmpty) {
      _showSnackBar('Koi valid item nahi hai confirm karne ko.', isSuccess: false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Receiving', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          '${validItems.length} items ka stock update ho jayega.\n'
          'Kya aap sure hain?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Haan, Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      int updated = 0;
      int newItems = 0;

      for (final item in validItems) {
        if (item.productId.isNotEmpty) {
          // Update existing product stock
          final product = productProvider.getProductById(item.productId);
          if (product != null) {
            final newStock = product.stockQuantity + item.receivedQty.round();
            final ref = db.collection('products').doc(item.productId);
            batch.update(ref, {
              'stockQuantity': newStock,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            updated++;
          }
        } else {
          // Try to find by name
          final nameLower = item.productName.toLowerCase();
          final product = productProvider.products.firstWhere(
            (p) => p.name.toLowerCase() == nameLower || p.name.toLowerCase().contains(nameLower),
            orElse: () => throw Exception('skip'),
          );
          final newStock = product.stockQuantity + item.receivedQty.round();
          final ref = db.collection('products').doc(product.id);
          batch.update(ref, {'stockQuantity': newStock, 'updatedAt': FieldValue.serverTimestamp()});
          updated++;
        }
      }

      // Record receiving log
      final logRef = db.collection('inventory_receiving_logs').doc();
      batch.set(logRef, {
        'id': logRef.id,
        'supplierName': _supplierName,
        'invoiceNumber': _invoiceNumber,
        'items': validItems
            .map(
              (i) => {
                'productId': i.productId,
                'productName': i.productName,
                'barcode': i.barcode,
                'receivedQty': i.receivedQty,
                'unit': i.unit,
                'costPerUnit': i.costPerUnit,
              },
            )
            .toList(),
        'receivedAt': FieldValue.serverTimestamp(),
        'totalItems': validItems.length,
      });

      await batch.commit();

      // Reload provider
      await productProvider.fetchProductsPaged(isRefresh: true);

      setState(() => _isSubmitting = false);

      if (mounted) {
        _showSnackBar(
          '$updated items ka stock update ho gaya! $newItems naye items skip.',
          isSuccess: true,
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnackBar('Error: $e', isSuccess: false);
    }
  }

  void _showSnackBar(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isSuccess ? AppTheme.success : AppTheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _addEmptyItem() {
    setState(() {
      _items.add(_ReceivedItem(productName: '', receivedQty: 1.0, unit: 'kg'));
    });
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Maal Receive Karo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Items List', icon: Icon(Icons.list_alt, size: 18)),
            Tab(text: 'Barcode Scan', icon: Icon(Icons.qr_code_scanner, size: 18)),
          ],
        ),
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Stock update ho raha hai...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildItemsTab(), _buildScannerTab()],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildItemsTab() {
    return Column(
      children: [
        // Supplier info + action bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              // Supplier name and invoice
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Supplier Name',
                        prefixIcon: Icon(Icons.store_outlined),
                        isDense: true,
                      ),
                      onChanged: (v) => _supplierName = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Invoice No.',
                        prefixIcon: Icon(Icons.receipt_outlined),
                        isDense: true,
                      ),
                      onChanged: (v) => _invoiceNumber = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openBillScanner,
                      icon: const Icon(Icons.document_scanner_outlined, size: 18),
                      label: const Text('Scan Bill'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _tabController.animateTo(1);
                        setState(() => _isScannerActive = true);
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Barcode'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addEmptyItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Items list
        Expanded(
          child: _items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.grey300),
                      SizedBox(height: 16),
                      Text(
                        'Koi item nahi hai',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.grey500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '"Scan Bill" ya "Add Item" se shuru karein',
                        style: TextStyle(color: AppTheme.grey400, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (context, index) => _ItemEntryCard(
                    item: _items[index],
                    index: index,
                    productProvider: Provider.of<ProductProvider>(context, listen: false),
                    onDelete: () => setState(() => _items.removeAt(index)),
                    onChanged: () => setState(() {}),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildScannerTab() {
    return Column(
      children: [
        // Scanner view
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              MobileScanner(controller: _scannerController, onDetect: _onBarcodeDetected),
              // Viewfinder overlay
              Center(
                child: Container(
                  width: 240,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              // Instruction
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Barcode frame mein rakhein',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Feedback
        if (_scanFeedback != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppTheme.success.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_scanFeedback!, style: const TextStyle(color: AppTheme.success)),
                ),
              ],
            ),
          ),

        // Scanner controls
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _scannerController.toggleTorch(),
                  icon: const Icon(Icons.flashlight_on),
                  label: const Text('Torch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.grey800,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _tabController.animateTo(0);
                  },
                  icon: const Icon(Icons.list_alt),
                  label: Text('List (${_items.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scanned items summary
        if (_items.isNotEmpty)
          Container(
            height: 140,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.grey200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(
                    'Scanned Items:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName.isEmpty ? '(Unknown)' : item.productName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              '${item.receivedQty} ${item.unit}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final validCount = _items.where((i) => i.isValid).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: AppTheme.cardShadows),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: validCount > 0 && !_isSubmitting ? _confirmAllReceived : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Confirm All Received ($validCount items)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}

// ─────────────── ITEM ENTRY CARD ───────────────

class _ItemEntryCard extends StatefulWidget {
  final _ReceivedItem item;
  final int index;
  final ProductProvider productProvider;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ItemEntryCard({
    required this.item,
    required this.index,
    required this.productProvider,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_ItemEntryCard> createState() => _ItemEntryCardState();
}

class _ItemEntryCardState extends State<_ItemEntryCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _costCtrl;
  List<ProductModel> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.productName);
    _qtyCtrl = TextEditingController(text: widget.item.receivedQty.toString());
    _unitCtrl = TextEditingController(text: widget.item.unit);
    _costCtrl = TextEditingController(text: widget.item.costPerUnit.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    widget.item.productName = val;
    if (val.length >= 2) {
      final results = widget.productProvider.searchProducts(val);
      setState(() => _suggestions = results.take(4).toList());
    } else {
      setState(() => _suggestions = []);
    }
    widget.onChanged();
  }

  void _selectProduct(ProductModel p) {
    setState(() {
      widget.item.productId = p.id;
      widget.item.productName = p.name;
      widget.item.unit = p.unit;
      _nameCtrl.text = p.name;
      _unitCtrl.text = p.unit;
      _suggestions = [];
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = widget.item.productId.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(
          color: isVerified ? AppTheme.success.withOpacity(0.4) : AppTheme.grey200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isVerified ? AppTheme.success.withOpacity(0.15) : AppTheme.grey100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isVerified
                        ? const Icon(Icons.check, size: 16, color: AppTheme.success)
                        : Text(
                            '${widget.index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.grey600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    onChanged: _onNameChanged,
                    decoration: InputDecoration(
                      hintText: 'Product name...',
                      isDense: true,
                      border: InputBorder.none,
                      suffixIcon: widget.item.barcode.isNotEmpty
                          ? const Icon(Icons.qr_code, size: 16, color: AppTheme.grey400)
                          : null,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppTheme.grey400, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            // Suggestions dropdown
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.grey200),
                  boxShadow: AppTheme.cardShadows,
                ),
                child: Column(
                  children: _suggestions
                      .map(
                        (p) => InkWell(
                          onTap: () => _selectProduct(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 16,
                                  color: AppTheme.grey500,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
                                Text(
                                  p.unit,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            const Divider(height: 12),

            // Quantity, unit, cost row
            Row(
              children: [
                // Quantity
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      widget.item.receivedQty = double.tryParse(v) ?? 1.0;
                      widget.onChanged();
                    },
                    decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                // Unit
                Expanded(
                  child: TextField(
                    controller: _unitCtrl,
                    onChanged: (v) => widget.item.unit = v,
                    decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                // Cost per unit
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      widget.item.costPerUnit = double.tryParse(v) ?? 0.0;
                      widget.onChanged();
                    },
                    decoration: const InputDecoration(labelText: 'Cost/Unit (Rs.)', isDense: true),
                  ),
                ),
              ],
            ),

            // Barcode badge
            if (widget.item.barcode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, size: 14, color: AppTheme.grey500),
                    const SizedBox(width: 4),
                    Text(
                      widget.item.barcode,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
