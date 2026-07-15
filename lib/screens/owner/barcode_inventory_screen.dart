import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/app_theme.dart';

// ─────────────── ENUMS ───────────────

enum InventoryMode { receiveStock, countStock, pickOrder }

extension InventoryModeExt on InventoryMode {
  String get label {
    switch (this) {
      case InventoryMode.receiveStock:
        return 'Receive Stock';
      case InventoryMode.countStock:
        return 'Count Stock';
      case InventoryMode.pickOrder:
        return 'Pick Order';
    }
  }

  IconData get icon {
    switch (this) {
      case InventoryMode.receiveStock:
        return Icons.add_box_outlined;
      case InventoryMode.countStock:
        return Icons.inventory_outlined;
      case InventoryMode.pickOrder:
        return Icons.remove_shopping_cart_outlined;
    }
  }

  Color get color {
    switch (this) {
      case InventoryMode.receiveStock:
        return AppTheme.info;
      case InventoryMode.countStock:
        return AppTheme.info;
      case InventoryMode.pickOrder:
        return AppTheme.warning;
    }
  }
}

// ─────────────── DATA ───────────────

class _ScanEntry {
  final String barcode;
  final String productName;
  final int quantityChanged;
  final InventoryMode mode;
  final DateTime time;

  _ScanEntry({
    required this.barcode,
    required this.productName,
    required this.quantityChanged,
    required this.mode,
    required this.time,
  });
}

// ─────────────── SCREEN ───────────────

class BarcodeInventoryScreen extends StatefulWidget {
  const BarcodeInventoryScreen({super.key});

  @override
  State<BarcodeInventoryScreen> createState() => _BarcodeInventoryScreenState();
}

class _BarcodeInventoryScreenState extends State<BarcodeInventoryScreen> {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    torchEnabled: false,
    returnImage: false,
  );
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  InventoryMode _mode = InventoryMode.receiveStock;
  bool _torchOn = false;
  bool _isProcessing = false;

  // Product state
  String? _scannedBarcode;
  Map<String, dynamic>? _foundProduct;
  String? _foundProductId;
  int _adjustQty = 1;

  // New product form
  bool _showNewProductForm = false;
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '1');
  String _newUnit = 'piece';
  String _newCategory = 'groceries';

  // Session history (last 10)
  final List<_ScanEntry> _history = [];

  static const List<String> _units = [
    'piece',
    'kg',
    'g',
    'l',
    'ml',
    'packet',
    'bottle',
    'box',
    'dozen',
  ];
  static const List<String> _categories = [
    'groceries',
    'vegetables',
    'fruits',
    'dairy',
    'snacks',
    'beverages',
    'household',
    'other',
  ];

  @override
  void dispose() {
    _scannerCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  // ─── Barcode Logic ───

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode == _scannedBarcode) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessing = true;
      _scannedBarcode = barcode;
      _foundProduct = null;
      _foundProductId = null;
      _showNewProductForm = false;
      _adjustQty = 1;
    });

    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final shopId = authProvider.currentShop?.id ?? 'shop_001';

      final snapshot = await _db
          .collection('products')
          .where('shopId', isEqualTo: shopId)
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        setState(() {
          _foundProduct = doc.data();
          _foundProductId = doc.id;
          _showNewProductForm = false;
        });
      } else {
        _nameCtrl.clear();
        _priceCtrl.clear();
        _stockCtrl.text = '1';
        setState(() => _showNewProductForm = true);
      }
    } catch (e) {
      _showSnack('Error looking up barcode: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmUpdate() async {
    if (_foundProductId == null || _adjustQty == 0) return;

    try {
      final doc = await _db.collection('products').doc(_foundProductId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final currentQty = (data['stockQuantity'] ?? 0) as int;
      int newQty;

      switch (_mode) {
        case InventoryMode.receiveStock:
          newQty = currentQty + _adjustQty;
          break;
        case InventoryMode.countStock:
          newQty = _adjustQty;
          break;
        case InventoryMode.pickOrder:
          newQty = (currentQty - _adjustQty).clamp(0, 999999);
          break;
      }

      await doc.reference.update({
        'stockQuantity': newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final entry = _ScanEntry(
        barcode: _scannedBarcode ?? '',
        productName: data['name'] as String? ?? 'Unknown',
        quantityChanged: _adjustQty,
        mode: _mode,
        time: DateTime.now(),
      );

      setState(() {
        _history.insert(0, entry);
        if (_history.length > 10) _history.removeLast();
        _foundProduct = {...data, 'stockQuantity': newQty};
      });

      _showSnack('${data['name']}: stock → $newQty');
    } catch (e) {
      _showSnack('Update failed: $e', isError: true);
    }
  }

  Future<void> _createNewProduct() async {
    if (_nameCtrl.text.isEmpty) {
      _showSnack('Enter product name', isError: true);
      return;
    }

    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final shopId = authProvider.currentShop?.id ?? 'shop_001';
      final shopName = authProvider.currentShop?.name ?? 'Fufaji Store';

      final newId = 'p_${DateTime.now().millisecondsSinceEpoch}';
      await _db.collection('products').doc(newId).set({
        'id': newId,
        'name': _nameCtrl.text.trim(),
        'barcode': _scannedBarcode ?? '',
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        'stockQuantity': int.tryParse(_stockCtrl.text) ?? 1,
        'unit': _newUnit,
        'category': _newCategory,
        'shopId': shopId,
        'shopName': shopName,
        'description': '',
        'imageUrl': '',
        'isAvailable': true,
        'district': 'Baran',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final entry = _ScanEntry(
        barcode: _scannedBarcode ?? '',
        productName: _nameCtrl.text.trim(),
        quantityChanged: int.tryParse(_stockCtrl.text) ?? 1,
        mode: InventoryMode.receiveStock,
        time: DateTime.now(),
      );

      setState(() {
        _history.insert(0, entry);
        if (_history.length > 10) _history.removeLast();
        _showNewProductForm = false;
        _scannedBarcode = null;
        _foundProduct = null;
        _foundProductId = null;
      });

      _showSnack('Product created: ${_nameCtrl.text.trim()}');
    } catch (e) {
      _showSnack('Error creating product: $e', isError: true);
    }
  }

  void _resetScan() {
    setState(() {
      _scannedBarcode = null;
      _foundProduct = null;
      _foundProductId = null;
      _showNewProductForm = false;
      _adjustQty = 1;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── UI ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey900,
      appBar: AppBar(
        title: const Text(
          'Barcode Scanner',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              _scannerCtrl.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode toggle
          _buildModeToggle(),

          // Scanner
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(controller: _scannerCtrl, onDetect: _onBarcodeDetected),
                // Overlay frame
                Center(
                  child: Container(
                    width: 250,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primary, width: 2.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black45,
                    child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  ),
                if (_scannedBarcode != null)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _scannedBarcode!,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom panel
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: _scannedBarcode == null
                  ? _buildIdlePanel()
                  : _showNewProductForm
                  ? _buildNewProductForm()
                  : _foundProduct != null
                  ? _buildProductPanel()
                  : _buildIdlePanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      color: AppTheme.grey900,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: InventoryMode.values.map((mode) {
          final selected = _mode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? mode.color : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mode.icon, size: 22, color: selected ? Colors.white : Colors.white54),
                    const SizedBox(height: 4),
                    Text(
                      mode.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIdlePanel() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'Point camera at barcode',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.grey700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Barcode will be detected automatically',
          style: TextStyle(fontSize: 13, color: AppTheme.grey400),
        ),
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Session History',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_history.length} scans',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _history.length,
              itemBuilder: (_, i) => _buildHistoryTile(_history[i]),
            ),
          ),
        ] else
          const Expanded(
            child: Center(child: Icon(Icons.qr_code_scanner, size: 80, color: AppTheme.grey200)),
          ),
      ],
    );
  }

  Widget _buildHistoryTile(_ScanEntry entry) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: entry.mode.color.withOpacity(0.15),
        child: Icon(entry.mode.icon, size: 16, color: entry.mode.color),
      ),
      title: Text(
        entry.productName,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(entry.barcode, style: const TextStyle(fontSize: 11, color: AppTheme.grey500)),
      trailing: Text(
        '${entry.mode == InventoryMode.pickOrder ? '-' : '+'}${entry.quantityChanged}',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: entry.mode.color),
      ),
    );
  }

  Widget _buildProductPanel() {
    final product = _foundProduct!;
    final currentQty = product['stockQuantity'] as int? ?? 0;
    final name = product['name']?.toString() ?? 'Unknown';
    final unit = product['unit']?.toString() ?? 'piece';
    final price = (product['price'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '₹${price.toStringAsFixed(0)} / $unit',
                      style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: currentQty < 5
                      ? AppTheme.error.withOpacity(0.1)
                      : AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$currentQty',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: currentQty < 5 ? AppTheme.error : AppTheme.info,
                      ),
                    ),
                    Text(unit, style: const TextStyle(fontSize: 11, color: AppTheme.grey600)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            _mode.label,
            style: TextStyle(fontWeight: FontWeight.w600, color: _mode.color, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Quick-add buttons + custom qty
          Row(
            children: [
              _qtyChip(1),
              _qtyChip(5),
              _qtyChip(10),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextFormField(
                    initialValue: _adjustQty.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Custom',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                    onChanged: (v) => setState(() => _adjustQty = int.tryParse(v) ?? 1),
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Confirm + New Scan buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetScan,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('New Scan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _confirmUpdate,
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mode.color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyChip(int qty) {
    final selected = _adjustQty == qty;
    return GestureDetector(
      onTap: () => setState(() => _adjustQty = qty),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '+$qty',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppTheme.grey700,
          ),
        ),
      ),
    );
  }

  Widget _buildNewProductForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fiber_new, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'New Product',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _resetScan,
                child: const Text('Cancel', style: TextStyle(color: AppTheme.grey600)),
              ),
            ],
          ),
          Text(
            'Barcode: ${_scannedBarcode ?? ""}',
            style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
          ),
          const SizedBox(height: 12),
          _formField(_nameCtrl, 'Product Name', TextInputType.text),
          const SizedBox(height: 10),
          _formField(_priceCtrl, 'Price (₹)', const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          _formField(_stockCtrl, 'Initial Stock', TextInputType.number),
          const SizedBox(height: 10),
          // Unit + Category row
          Row(
            children: [
              Expanded(
                child: _dropdownField(
                  label: 'Unit',
                  value: _newUnit,
                  items: _units,
                  onChanged: (v) => setState(() => _newUnit = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdownField(
                  label: 'Category',
                  value: _newCategory,
                  items: _categories,
                  onChanged: (v) => setState(() => _newCategory = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _createNewProduct,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Create Product',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String label, TextInputType type) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: AppTheme.grey600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: AppTheme.grey600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: AppTheme.grey900),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
