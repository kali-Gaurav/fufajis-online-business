import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/fj_button.dart';
import '../../widgets/common/fj_card.dart';
import '../../services/product_service.dart';

class AddProductScreen extends StatefulWidget {
  final String? productId;
  final String? initialBarcode;

  const AddProductScreen({super.key, this.productId, this.initialBarcode});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isEditMode = false;
  String? _existingProductId;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _unitController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _hsnController = TextEditingController();
  final _brandController = TextEditingController();
  final _tagController = TextEditingController();

  ProductCategory _selectedCategory = ProductCategory.groceries;
  bool _isFeatured = false;
  bool _isAvailable = true;

  List<String> _tags = [];
  final List<File> _newImages = [];
  List<String> _existingImageUrls = [];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.productId != null;
    if (_isEditMode) {
      _loadExistingProduct();
    } else if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
    }
  }

  Future<void> _loadExistingProduct() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('products').doc(widget.productId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _existingProductId = doc.id;
        _nameController.text = data['name'] as String? ?? '';
        _descriptionController.text = data['description'] as String? ?? '';
        _priceController.text = (data['price'] as num? ?? 0.0).toString();
        _originalPriceController.text = data['originalPrice']?.toString() ?? '';
        _unitController.text = data['unit'] as String? ?? '';
        _stockController.text = (data['stockQuantity'] as int? ?? 0).toString();
        _minStockController.text = (data['minimumStock'] as int? ?? 10).toString();
        _barcodeController.text = data['barcode'] as String? ?? '';
        _hsnController.text = data['hsnCode'] as String? ?? '';
        _brandController.text = data['brand'] as String? ?? '';
        _isFeatured = data['isFeatured'] as bool? ?? false;
        _isAvailable = data['isAvailable'] as bool? ?? true;
        _tags = List<String>.from(data['tags'] as Iterable? ?? []);
        _existingImageUrls = List<String>.from(data['images'] as Iterable? ?? []);

        final catId = data['categoryId'] ?? data['category'] ?? 'groceries';
        _selectedCategory = ProductCategory.fromId(catId.toString());
      }
    } catch (e) {
      _showError('Failed to load product: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    if (_newImages.length + _existingImageUrls.length >= 5) {
      _showError('Maximum 5 images allowed');
      return;
    }
    final remaining = 5 - _newImages.length - _existingImageUrls.length;
    final picked = await _picker.pickMultiImage(limit: remaining);
    if (picked.isNotEmpty) {
      setState(() {
        _newImages.addAll(picked.map((xf) => File(xf.path)));
      });
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _BarcodeScannerPage(),
      ),
    );
    if (result != null) {
      setState(() => _barcodeController.text = result);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<List<String>> _uploadImages(String productId) async {
    final uploaded = <String>[];
    for (int i = 0; i < _newImages.length; i++) {
      final ref = _storage.ref().child('products/$productId/image_$i.jpg');
      await ref.putFile(_newImages[i]);
      final url = await ref.getDownloadURL();
      uploaded.add(url);
    }
    return uploaded;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final barcode = _barcodeController.text.trim();
      if (barcode.isNotEmpty) {
        final isUnique = await ProductService().isBarcodeUnique(barcode, excludeProductId: _existingProductId);
        if (!isUnique) {
          _showError('Barcode "$barcode" is already assigned to another product.');
          setState(() => _isLoading = false);
          return;
        }
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final shopId = authProvider.currentShop?.id ?? 'shop_001';
      final shopName = authProvider.currentShop?.name ?? 'Fufaji Store';

      final productId = _existingProductId ?? _firestore.collection('products').doc().id;
      final allImageUrls = List<String>.from(_existingImageUrls);
      final newUploaded = await _uploadImages(productId);
      allImageUrls.addAll(newUploaded);

      final data = {
        'id': productId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'originalPrice': _originalPriceController.text.isNotEmpty
            ? double.tryParse(_originalPriceController.text)
            : null,
        'unit': _unitController.text.trim(),
        'stockQuantity': int.tryParse(_stockController.text) ?? 0,
        'minimumStock': int.tryParse(_minStockController.text) ?? 10,
        'barcode': _barcodeController.text.trim(),
        'hsnCode': _hsnController.text.trim(),
        'brand': _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        'categoryId': _selectedCategory.name,
        'category': _selectedCategory.nameEn,
        'isFeatured': _isFeatured,
        'isAvailable': _isAvailable,
        'tags': _tags,
        'images': allImageUrls,
        'imageUrl': allImageUrls.isNotEmpty ? allImageUrls.first : '',
        'shopId': shopId,
        'shopName': shopName,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!_isEditMode) 'createdAt': FieldValue.serverTimestamp(),
        if (!_isEditMode) 'rating': 0.0,
        if (!_isEditMode) 'reviewCount': 0,
        if (!_isEditMode) 'isOnSale': false,
        if (!_isEditMode) 'isNewArrival': true,
        if (!_isEditMode) 'isTrending': false,
      };

      if (_isEditMode) {
         await _firestore.collection('products').doc(productId).set(data, SetOptions(merge: true));
      } else {
        // Use ProductProvider to trigger barcode unique check
        final newProduct = ProductModel.fromMap({...data, 'createdAt': DateTime.now()});
        await Provider.of<ProductProvider>(context, listen: false).addProduct(newProduct);
      }

      if (mounted) {
        await Provider.of<ProductProvider>(context, listen: false).refreshProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Product updated successfully!' : 'Product added successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Failed to save product: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _barcodeController.dispose();
    _hsnController.dispose();
    _brandController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Product' : 'Add Product'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _saveProduct,
              icon: const Icon(Icons.save, color: AppTheme.primary),
              label: const Text('Save', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading && _isEditMode
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: AppTheme.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Product Images'),
                    const SizedBox(height: 12),
                    FjCard(
                      padding: const EdgeInsets.all(12),
                      child: _buildImagesPicker(),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('Basic Information'),
                    const SizedBox(height: 12),
                    FjCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Product Name *', hintText: 'e.g. Basmati Rice'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(labelText: 'Description', hintText: 'Product details...'),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<ProductCategory>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: ProductCategory.values
                                .map((cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat.localizedName(AppLocalizations.of(context)!.localeName)),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedCategory = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('Pricing'),
                    const SizedBox(height: 12),
                    FjCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(labelText: 'Price (₹) *', prefixText: '₹ '),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                              validator: (v) => v == null || v.trim().isEmpty ? 'Price is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _originalPriceController,
                              decoration: const InputDecoration(labelText: 'MRP (₹)', prefixText: '₹ '),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('Stock & Unit'),
                    const SizedBox(height: 12),
                    FjCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _unitController,
                            decoration: const InputDecoration(labelText: 'Unit', hintText: 'kg, g, piece, packet, litre...'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _stockController,
                                  decoration: const InputDecoration(labelText: 'Stock Quantity *'),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Stock is required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _minStockController,
                                  decoration: const InputDecoration(labelText: 'Min Stock Alert'),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('Barcode & Identifiers'),
                    const SizedBox(height: 12),
                    FjCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _barcodeController,
                                  decoration: const InputDecoration(labelText: 'Barcode'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FjButton(
                                label: 'Scan',
                                onPressed: _scanBarcode,
                                icon: Icons.qr_code_scanner,
                                height: 44,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _hsnController,
                                  decoration: const InputDecoration(labelText: 'HSN Code (optional)'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _brandController,
                                  decoration: const InputDecoration(labelText: 'Brand (optional)'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('Tags'),
                    const SizedBox(height: 12),
                    FjCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _tagController,
                                  decoration: const InputDecoration(labelText: 'Add tag', hintText: 'e.g. organic, local'),
                                  onFieldSubmitted: (_) => _addTag(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _addTag,
                                icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                              ),
                            ],
                          ),
                          if (_tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _tags
                                  .map((tag) => Chip(
                                        label: Text(tag),
                                        onDeleted: () => setState(() => _tags.remove(tag)),
                                        deleteIcon: const Icon(Icons.close, size: 16),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('Visibility'),
                    const SizedBox(height: 12),
                    FjCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Featured Product', style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: const Text('Show in Featured / Fufaji\'s Pick section'),
                            value: _isFeatured,
                            activeThumbColor: AppTheme.primary,
                            onChanged: (v) => setState(() => _isFeatured = v),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Available for Sale', style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: const Text('Customers can order this product', style: TextStyle(fontWeight: FontWeight.w700)),
                            value: _isAvailable,
                            activeThumbColor: AppTheme.success,
                            onChanged: (v) => setState(() => _isAvailable = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    FjButton(
                      label: _isEditMode ? 'Update Product' : 'Add Product',
                      onPressed: _isLoading ? null : _saveProduct,
                      isLoading: _isLoading,
                      width: double.infinity,
                      icon: Icons.save,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.grey700,
      ),
    );
  }

  Widget _buildImagesPicker() {
    final allImages = [
      ..._existingImageUrls.map((url) => _ExistingImageItem(url: url)),
      ..._newImages.map((f) => _NewImageItem(file: f)),
    ];
    final totalCount = allImages.length;

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...List.generate(totalCount, (i) {
            if (i < _existingImageUrls.length) {
              return _imageThumb(
                child: Image.network(_existingImageUrls[i], fit: BoxFit.cover),
                onRemove: () => setState(() => _existingImageUrls.removeAt(i)),
              );
            } else {
              final fileIndex = i - _existingImageUrls.length;
              return _imageThumb(
                child: Image.file(_newImages[fileIndex], fit: BoxFit.cover),
                onRemove: () => setState(() => _newImages.removeAt(fileIndex)),
              );
            }
          }),
          if (totalCount < 5)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.grey300, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.grey100,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, color: AppTheme.grey500, size: 32),
                    SizedBox(height: 4),
                    Text('Add Photo', style: TextStyle(fontSize: 11, color: AppTheme.grey500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageThumb({required Widget child, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.grey200),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        Positioned(
          top: 2,
          right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// Placeholder classes for type resolution
class _ExistingImageItem {
  final String url;
  _ExistingImageItem({required this.url});
}

class _NewImageItem {
  final File file;
  _NewImageItem({required this.file});
}

// Inline barcode scanner page
class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_scanned) return;
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final value = barcodes.first.rawValue;
            if (value != null) {
              _scanned = true;
              Navigator.of(context).pop(value);
            }
          }
        },
      ),
    );
  }
}
