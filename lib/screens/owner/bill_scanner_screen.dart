import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/ocr_service.dart';
import '../../services/purchase_order_service.dart';
import '../../providers/product_provider.dart';
import '../../utils/app_theme.dart';

class BillScannerScreen extends StatefulWidget {
  const BillScannerScreen({super.key});

  @override
  State<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends State<BillScannerScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final BillOCRService _ocrService = BillOCRService();
  final PurchaseOrderService _poService = PurchaseOrderService();

  bool _isLoading = false;
  String _loadingMessage = '';
  String? _errorMessage;
  BillScanResult? _scanResult;
  bool _hasScanned = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Image Picking ──────────────────────────────────

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _processBill(bytes);
      }
    } catch (e) {
      _showError('Camera se photo nahi li: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _processBill(bytes);
      }
    } catch (e) {
      _showError('Gallery se photo nahi mili: $e');
    }
  }

  Future<void> _processBill(Uint8List imageBytes) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Gemini AI se bill padh raha hai...';
      _errorMessage = null;
      _scanResult = null;
      _hasScanned = false;
    });

    try {
      // 1. Structured Scan
      final result = await _ocrService.scanBillStructured(imageBytes);

      if (result.items.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Bill mein koi item nahi mila. Dobara try karein.';
        });
        return;
      }

      setState(() => _loadingMessage = 'Stock se match kar raha hai...');
      await Future.delayed(const Duration(milliseconds: 500));

      // 2. Match with existing inventory
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      _ocrService.matchItemsToProducts(result, productProvider.products);

      setState(() {
        _isLoading = false;
        _scanResult = result;
        _hasScanned = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bill scan mein error: $e';
      });
    }
  }

  // ── Inventory Update & PO Creation ──────────────────────────────

  Future<void> _saveAndProcess({required bool createPO}) async {
    if (_scanResult == null) return;
    
    final selectedItems = _scanResult!.items.where((item) => item.isSelected).toList();
    if (selectedItems.isEmpty) {
      _showError('Koi item select nahi hai.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = createPO ? 'PO aur Stock save ho raha hai...' : 'Stock update ho raha hai...';
    });

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final shopId = productProvider.currentShopId ?? 'shop_001';

      int updatedCount = 0;
      
      // 1. Update Inventory for matched products
      for (final item in selectedItems) {
        if (item.isMatched && item.matchedProductId != null) {
          try {
            final product = productProvider.products.firstWhere((p) => p.id == item.matchedProductId);
            
            // Update stock and cost price
            final newStock = product.stockQuantity + item.quantity.round();
            final updated = product.copyWith(
              stockQuantity: newStock,
              costPrice: item.pricePerUnit, // Save cost price from bill
              updatedAt: DateTime.now(),
            );
            await productProvider.updateProduct(updated);
            updatedCount++;
          } catch (e) {
            debugPrint('Failed to update matched product: $e');
          }
        }
      }

      // 2. Create Purchase Order (optional)
      if (createPO) {
        final poItems = selectedItems.map((i) => {
          'matchedProductId': i.matchedProductId,
          'name': i.name,
          'quantity': i.quantity,
          'unit': i.unit,
          'total': i.total,
        }).toList();

        await _poService.createPOFromBillScan(
          shopId: shopId,
          supplierName: _scanResult!.supplierName,
          billNumber: _scanResult!.billNumber,
          billDate: _scanResult!.billDate,
          items: poItems,
        );
      }

      setState(() => _isLoading = false);

      if (mounted) {
        final msg = createPO 
            ? 'Purchase Order created and $updatedCount items stock updated!' 
            : '$updatedCount items ka stock update ho gaya!';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text(
          'Bill Scanner OCR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _hasScanned && _scanResult != null
              ? _buildResultsView()
              : _buildPickerView(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _loadingMessage,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.grey200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(Icons.receipt_long, size: 56, color: Colors.white),
                SizedBox(height: 12),
                Text(
                  'Supplier Bill Scan Karo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'AI extracts supplier info, items, and cost prices',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Camera button
          _PickerButton(
            icon: Icons.camera_alt_outlined,
            label: 'Camera se Photo Lo',
            subtitle: 'Bill ki fresh photo lena',
            onTap: _pickFromCamera,
            isPrimary: true,
          ),

          const SizedBox(height: 16),

          // Gallery button
          _PickerButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery se Photo Lo',
            subtitle: 'Saved bill image choose karo',
            onTap: _pickFromGallery,
            isPrimary: false,
          ),

          const SizedBox(height: 32),

          // Tips
          const _TipsCard(),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    final result = _scanResult!;
    
    return Column(
      children: [
        // Supplier Header Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.supplierName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Bill: ${result.billNumber}', style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
                        const SizedBox(width: 12),
                        Text('Date: ${result.billDate}', style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.primary,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${result.items.length} items | ${result.matchedCount} matched in inventory',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Total: ₹${result.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  final allSelected = result.items.every((i) => i.isSelected);
                  for (final item in result.items) {
                    item.isSelected = !allSelected;
                  }
                }),
                icon: const Icon(Icons.select_all, color: Colors.white, size: 18),
                label: const Text(
                  'Select',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        // Item list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: result.items.length,
            itemBuilder: (context, index) {
              return _BillItemCard(
                item: result.items[index],
                onChanged: () => setState(() {}),
              );
            },
          ),
        ),

        // Bottom action bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: AppTheme.cardShadows,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _hasScanned = false;
                      _scanResult = null;
                    }),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: result.selectedCount > 0 
                          ? () => _saveAndProcess(createPO: false) 
                          : null,
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: const Text('Update Stock'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: result.selectedCount > 0 
                          ? () => _saveAndProcess(createPO: true) 
                          : null,
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Save as PO'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────── CHILD WIDGETS ───────────────

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: isPrimary
              ? null
              : Border.all(color: AppTheme.primary, width: 1.5),
          boxShadow: AppTheme.cardShadows,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isPrimary ? Colors.white : AppTheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isPrimary ? Colors.white : AppTheme.grey900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isPrimary ? Colors.white70 : AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isPrimary ? Colors.white : AppTheme.grey400,
            ),
          ],
        ),
      ),
    );
  }
}

class _BillItemCard extends StatefulWidget {
  final BillScanItem item;
  final VoidCallback onChanged;

  const _BillItemCard({required this.item, required this.onChanged});

  @override
  State<_BillItemCard> createState() => _BillItemCardState();
}

class _BillItemCardState extends State<_BillItemCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _unitCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _priceCtrl = TextEditingController(text: widget.item.pricePerUnit.toString());
    _unitCtrl = TextEditingController(text: widget.item.unit);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    setState(() {
      widget.item.total = widget.item.quantity * widget.item.pricePerUnit;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isMatched = widget.item.isMatched;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: widget.item.isSelected
            ? const BorderSide(color: AppTheme.primary, width: 1.5)
            : BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: widget.item.isSelected,
                  activeColor: AppTheme.primary,
                  onChanged: (v) {
                    setState(() => widget.item.isSelected = v ?? false);
                    widget.onChanged();
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        onChanged: (v) => widget.item.name = v,
                        decoration: const InputDecoration(
                          labelText: 'Scanned Item Name',
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (isMatched) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: AppTheme.success),
                            const SizedBox(width: 4),
                            Text(
                              'Matched: ${widget.item.matchedProductName}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 2),
                        const Row(
                          children: [
                            Icon(Icons.warning_amber, size: 14, color: AppTheme.warning),
                            SizedBox(width: 4),
                            Text(
                              'New Item (Stock won\'t update)',
                              style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      widget.item.quantity = double.tryParse(v) ?? 1.0;
                      _recalcTotal();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitCtrl,
                    onChanged: (v) => widget.item.unit = v,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      widget.item.pricePerUnit = double.tryParse(v) ?? 0.0;
                      _recalcTotal();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Cost/Unit (₹)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Subtotal: ₹${widget.item.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppTheme.info, size: 18),
              SizedBox(width: 6),
              Text(
                'Tips for best results',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...[
            'Supplier name header mein hona chahiye',
            'Achhi roshni mein photo lo',
            'Blurry photo na lo',
            'Printed bills better kaam karte hain',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppTheme.grey600)),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.grey700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
