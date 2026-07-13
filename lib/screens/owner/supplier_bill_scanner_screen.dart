import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../services/gemini_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/bill_item_row.dart';
import '../../utils/monetary_value.dart';

class SupplierBillScannerScreen extends StatefulWidget {
  const SupplierBillScannerScreen({super.key});

  @override
  State<SupplierBillScannerScreen> createState() => _SupplierBillScannerScreenState();
}

class _SupplierBillScannerScreenState extends State<SupplierBillScannerScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final GeminiService _gemini = GeminiService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // State
  bool _isLoading = false;
  bool _hasResult = false;

  // Bill data
  final TextEditingController _supplierCtrl = TextEditingController(text: 'Unknown');
  final TextEditingController _billNumberCtrl = TextEditingController();
  final TextEditingController _billDateCtrl = TextEditingController();
  List<BillItem> _items = [];

  // Animation for loading spinner & laser scan line
  late final AnimationController _spinCtrl;
  late final AnimationController _scanLineCtrl;
  late final Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

    _scanLineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _scanLineAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _scanLineCtrl.dispose();
    _supplierCtrl.dispose();
    _billNumberCtrl.dispose();
    _billDateCtrl.dispose();
    super.dispose();
  }

  // ─── Image Actions ───

  Future<void> _scanWithCamera() async {
    final xFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    await _processImage(bytes);
  }

  Future<void> _uploadFromGallery() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    await _processImage(bytes);
  }

  Future<void> _processImage(Uint8List bytes) async {
    setState(() => _isLoading = true);
    try {
      final result = await _gemini.extractBillWithSupplierDetails(bytes);
      _supplierCtrl.text = result['supplier']?.toString() ?? 'Unknown';
      _billNumberCtrl.text = result['billNumber']?.toString() ?? 'N/A';
      _billDateCtrl.text =
          result['billDate']?.toString() ?? DateTime.now().toString().substring(0, 10);

      final rawItems = result['items'] as List? ?? [];
      _items = rawItems.map((e) => BillItem.fromMap(e as Map<String, dynamic>)).toList();

      if (_items.isEmpty) _items.add(BillItem());

      setState(() {
        _isLoading = false;
        _hasResult = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Error reading bill: $e', isError: true);
    }
  }

  // ─── Update Inventory ───

  Future<void> _updateInventory() async {
    if (_items.isEmpty) {
      _showSnack('No items to update', isError: true);
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(width: 16),
            Text('Updating stock...'),
          ],
        ),
      ),
    );

    int updatedCount = 0;
    int createdCount = 0;
    double totalBillValue = 0;

    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final shopId = authProvider.currentShop?.id ?? 'shop_001';
    final shopName = authProvider.currentShop?.name ?? 'Fufaji Store';

    try {
      for (final item in _items) {
        if (item.name.isEmpty || item.quantity <= 0) continue;
        totalBillValue += item.total;

        // Fuzzy match: search Firestore by name (case-insensitive contains)
        final nameLower = item.name.toLowerCase().trim();
        final snapshot = await _db.collection('products').where('shopId', isEqualTo: shopId).get();

        DocumentSnapshot? match;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final prodName = (data['name'] ?? '').toString().toLowerCase();
          if (prodName.contains(nameLower) || nameLower.contains(prodName)) {
            match = doc;
            break;
          }
        }

        if (match != null) {
          final currentQty = (match.data() as Map<String, dynamic>)['stockQuantity'] ?? 0;
          await match.reference.update({
            'stockQuantity': currentQty + item.quantity.toInt(),
            'costPrice': item.pricePerUnit,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updatedCount++;
        } else {
          // Create new product
          final newId =
              'p_${DateTime.now().millisecondsSinceEpoch}_${item.name.replaceAll(' ', '_')}';
          final newProduct = ProductModel(
            id: newId,
            name: item.name,
            description: 'Added via supplier bill',
            price: MonetaryValue(item.pricePerUnit),
            unit: item.unit,
            categoryId: 'groceries',
            category: 'groceries',
            shopId: shopId,
            shopName: shopName,
            imageUrl: '',
            stockQuantity: item.quantity.toInt(),
            district: 'Baran',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          final productProvider = Provider.of<ProductProvider>(context, listen: false);
          await productProvider.addProduct(newProduct);
          createdCount++;
        }
      }

      // Save bill record
      await _db.collection('purchase_bills').add({
        'supplier': _supplierCtrl.text,
        'billNumber': _billNumberCtrl.text,
        'billDate': _billDateCtrl.text,
        'items': _items.map((e) => e.toMap()).toList(),
        'totalValue': totalBillValue,
        'shopId': shopId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.of(context).pop(); // close dialog
      _showSnack(
        'Stock updated: $updatedCount updated, $createdCount created. Total: ₹${totalBillValue.toStringAsFixed(0)}',
      );
      setState(() => _hasResult = false);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showSnack('Error updating inventory: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── UI ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Supplier Bill Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.white,
        elevation: 0,
        actions: _hasResult
            ? [
                TextButton.icon(
                  onPressed: () => setState(() => _hasResult = false),
                  icon: const Icon(Icons.refresh, color: AppTheme.white),
                  label: const Text('Rescan', style: TextStyle(color: AppTheme.white)),
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? _buildLoading()
          : _hasResult
          ? _buildResultView()
          : _buildLandingView(),
    );
  }

  // ─── Landing ───

  Widget _buildLandingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.document_scanner_outlined, size: 60, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan Supplier Bill',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.grey900),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI will extract all product details\nfrom your supplier bill or challan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 40),
            _buildLandingButton(
              icon: Icons.camera_alt,
              label: 'Scan Bill',
              subtitle: 'Use camera to capture',
              onTap: _scanWithCamera,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            _buildLandingButton(
              icon: Icons.photo_library,
              label: 'Upload Photo',
              subtitle: 'Choose from gallery',
              onTap: _uploadFromGallery,
              color: AppTheme.info,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandingButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Loading ───

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Scanner view frame mockup
            Container(
              width: 240,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.02),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dotted guidelines
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Opacity(
                        opacity: 0.3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            10,
                            (_) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                6,
                                (_) => Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.grey500,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Invoice Mock icon background
                    Icon(
                      Icons.receipt_long,
                      size: 100,
                      color: AppTheme.primary.withOpacity(0.15),
                    ),
                    // Animated Laser Scan Line
                    AnimatedBuilder(
                      animation: _scanLineAnim,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanLineAnim.value * 280, // sweeps within 300px height
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.success,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.success.withOpacity(0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Pulse Text
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (context, val, child) => Opacity(opacity: val, child: child),
              child: const Text(
                'Reading bill with AI...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Analyzing margins & cost variations...',
              style: TextStyle(fontSize: 13, color: AppTheme.grey500),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Result View ───

  Widget _buildResultView() {
    final totalValue = _items.fold<double>(0, (s, item) => s + item.total);

    return Column(
      children: [
        // Bill metadata card
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Bill Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₹${totalValue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.info,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetaField('Supplier', _supplierCtrl, Icons.store),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetaField('Bill No.', _billNumberCtrl, Icons.tag)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetaField('Date', _billDateCtrl, Icons.calendar_today)),
                ],
              ),
            ],
          ),
        ),

        // Column headers
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Product',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Qty',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Unit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Price',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey600,
                  ),
                ),
              ),
              SizedBox(width: 32),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _items.length + 1, // +1 for "Add Row" button
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _items.add(BillItem())),
                    icon: const Icon(Icons.add, color: AppTheme.primary),
                    label: const Text('Add Row', style: TextStyle(color: AppTheme.primary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                );
              }
              return BillItemRow(
                key: ValueKey(index),
                item: _items[index],
                onDelete: () => setState(() => _items.removeAt(index)),
                onChanged: () => setState(() {}),
              );
            },
          ),
        ),

        // Bottom action
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _updateInventory,
                icon: const Icon(Icons.inventory_2, color: Colors.white),
                label: Text(
                  'Update Inventory (${_items.length} items)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaField(String label, TextEditingController ctrl, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.grey500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 16, color: AppTheme.primary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.grey200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.grey200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}
