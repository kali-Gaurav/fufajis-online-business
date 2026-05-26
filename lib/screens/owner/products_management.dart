import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import '../../services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/app_theme.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../services/firestore_service.dart';
import '../../services/global_catalog_service.dart';
import '../../services/image_processing_service.dart';
import '../../widgets/voice_to_stock_dialog.dart';

class ProductsManagementScreen extends StatefulWidget {
  const ProductsManagementScreen({super.key});

  @override
  State<ProductsManagementScreen> createState() => _ProductsManagementScreenState();
}

class _ProductsManagementScreenState extends State<ProductsManagementScreen> {
  int _selectedCategory = 0;
  final List<String> _categories = [
    'All',
    'Groceries',
    'Vegetables',
    'Fruits',
    'Dairy',
    'Bakery',
    'Beverages',
    'Household',
  ];

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final categoryName = _categories[_selectedCategory];
    final products = categoryName == 'All' 
        ? productProvider.products 
        : productProvider.getProductsByCategory(categoryName.toLowerCase());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Products',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await productProvider.seedDatabase();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Database seeded with mock products!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to seed: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download_done),
                    label: const Text('Seed DB'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: AppTheme.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showBulkUploadDialog(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Bulk Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: AppTheme.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => showDialog(context: context, builder: (context) => const VoiceToStockDialog()),
                    icon: const Icon(Icons.mic),
                    label: const Text('Voice Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: AppTheme.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddProductDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search & Filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    // search query integration can go here
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppTheme.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _categories[_selectedCategory],
                  underline: const SizedBox(),
                  items: _categories.map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = _categories.indexOf(value);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Products Grid
          productProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildProductsGrid(products),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(List<ProductModel> products) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text('No products found in this category.'),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final discount = product.discountPercentage;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: AppTheme.grey100,
                            highlightColor: AppTheme.grey200,
                            child: Container(
                              color: AppTheme.white,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.inventory_2,
                            size: 48,
                            color: AppTheme.grey400,
                          ),
                        )
                      : const Icon(
                          Icons.inventory_2,
                          size: 48,
                          color: AppTheme.grey400,
                        ),
                ),
                if ((discount ?? 0) > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$discount% OFF',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.white,
                        ),
                      ),
                    ),
                  ),
                if (product.stockQuantity == 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Center(
                        child: Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Product Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${product.price}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          if ((discount ?? 0) > 0)
                            Text(
                              '₹${product.originalPrice}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.grey500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: AppTheme.secondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showEditProductDialog(context, product),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: AppTheme.error),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDelete(context, product),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: product.stockQuantity > 10
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : product.stockQuantity > 0
                              ? AppTheme.warning.withValues(alpha: 0.1)
                              : AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${product.stockQuantity} in stock',
                      style: TextStyle(
                        fontSize: 10,
                        color: product.stockQuantity > 10
                            ? AppTheme.success
                            : product.stockQuantity > 0
                                ? AppTheme.warning
                                : AppTheme.error,
                      ),
                      textAlign: TextAlign.center,
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

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SmartAddProductDialog(),
    );
  }

  void _showBulkUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BulkUploadDialog(),
    );
  }

  void _showEditProductDialog(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => EditProductDialog(product: product),
    );
  }

  void _confirmDelete(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "${product.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              try {
                await productProvider.deleteProduct(product.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text('DELETE', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}


class SmartAddProductDialog extends StatefulWidget {
  const SmartAddProductDialog({super.key});

  @override
  State<SmartAddProductDialog> createState() => _SmartAddProductDialogState();
}

class _SmartAddProductDialogState extends State<SmartAddProductDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  GlobalCatalogProduct? _selectedProduct;
  List<GlobalCatalogProduct> _searchResults = [];
  bool _isSaving = false;

  void _onSearch(String query) {
    setState(() {
      _searchResults = GlobalCatalogService.search(query);
    });
  }

  void _selectProduct(GlobalCatalogProduct product) {
    setState(() {
      _selectedProduct = product;
      _priceController.text = product.mrp.toString();
      _stockController.text = "100";
      _searchResults = [];
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || _selectedProduct == null) return;

    setState(() => _isSaving = true);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final newProduct = ProductModel(
        id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
        name: _selectedProduct!.name,
        description: 'Premium ${_selectedProduct!.name} from ${_selectedProduct!.brand}',
        price: double.parse(_priceController.text),
        originalPrice: _selectedProduct!.mrp,
        discountPercentage: ((_selectedProduct!.mrp - double.parse(_priceController.text)) / _selectedProduct!.mrp * 100).roundToDouble(),
        unit: _selectedProduct!.unit,
        category: _selectedProduct!.category,
        shopId: authProvider.currentUser?.id ?? 'shop_001',
        shopName: authProvider.currentUser?.name ?? "Fufaji Online",
        imageUrl: _selectedProduct!.imageUrl,
        stockQuantity: int.parse(_stockController.text),
        district: authProvider.currentUser?.district ?? 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: _selectedProduct!.tags,
        brand: _selectedProduct!.brand,
      );

      await productProvider.addProduct(newProduct);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added to your shop!'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quick Add Product', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              
              if (_selectedProduct == null) ...[
                const Text('Search from Global Catalog', style: TextStyle(color: AppTheme.grey600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'e.g. Maggi, Coca Cola, Parle-G...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchResults = []; }))
                        : null,
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.grey200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = _searchResults[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: p.imageUrl, width: 40, height: 40, fit: BoxFit.cover),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${p.brand} • MRP ₹${p.mrp}'),
                          onTap: () => _selectProduct(p),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 40),
                const Center(
                  child: Text('OR', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey400)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(context: context, builder: (context) => const AddProductDialog());
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Add Custom Product (Manual)'),
                  ),
                ),
              ] else ...[
                // Selected Product Preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.grey50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.grey200),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: _selectedProduct!.imageUrl, width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedProduct!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${_selectedProduct!.brand} • MRP ₹${_selectedProduct!.mrp}', style: const TextStyle(color: AppTheme.grey600)),
                            Text('Unit: ${_selectedProduct!.unit}', style: const TextStyle(color: AppTheme.grey600, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => setState(() => _selectedProduct = null), icon: const Icon(Icons.edit, color: AppTheme.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Selling Price', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(prefixText: '₹ ', isDense: true),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Stock Quantity', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                    child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Add to Shop Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _originalPriceController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController(text: '10');
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: '1 unit');
  DateTime? _expiryDate;

  String _selectedCategory = 'Groceries';
  String _selectedStrategy = 'match';
  File? _selectedImage;
  bool _isUploading = false;
  bool _isRemovingBg = false;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final ImageProcessingService _imageProcessingService = ImageProcessingService();

  Future<void> _removeBackground() async {
    if (_selectedImage == null) return;
    
    setState(() => _isRemovingBg = true);
    try {
      final processed = await _imageProcessingService.removeBackgroundAI(_selectedImage!);
      setState(() {
        _selectedImage = processed;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background removed successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isRemovingBg = false);
    }
  }

  // Variants/Unit Options
  final List<ProductUnitOption> _unitOptions = [];
  final TextEditingController _variantNameController = TextEditingController();
  final TextEditingController _variantPriceController = TextEditingController();
  final TextEditingController _variantStockController = TextEditingController();

  final List<String> _categories = [
    'Groceries',
    'Vegetables',
    'Fruits',
    'Dairy',
    'Bakery',
    'Beverages',
    'Household',
    'Personal Care',
  ];

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _addVariant() {
    if (_variantNameController.text.isEmpty || _variantPriceController.text.isEmpty) return;
    
    setState(() {
      _unitOptions.add(ProductUnitOption(
        id: 'var_${DateTime.now().millisecondsSinceEpoch}',
        name: _variantNameController.text,
        price: double.parse(_variantPriceController.text),
        stockQuantity: int.tryParse(_variantStockController.text) ?? 100,
      ));
      _variantNameController.clear();
      _variantPriceController.clear();
      _variantStockController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Product',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.grey900),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Image Upload
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.grey100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedImage != null ? AppTheme.primary : AppTheme.grey300,
                        style: BorderStyle.solid,
                      ),
                      image: _selectedImage != null
                          ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 40, color: AppTheme.grey500),
                              SizedBox(height: 8),
                              Text('Tap to add product photo', style: TextStyle(color: AppTheme.grey500)),
                            ],
                          )
                        : Stack(
                            children: [
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.white,
                                      radius: 18,
                                      child: IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: AppTheme.primary),
                                        onPressed: _pickImage,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    CircleAvatar(
                                      backgroundColor: AppTheme.secondary,
                                      radius: 18,
                                      child: _isRemovingBg 
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : IconButton(
                                            icon: const Icon(Icons.auto_fix_high, size: 18, color: Colors.white),
                                            tooltip: 'AI Remove Background',
                                            onPressed: _removeBackground,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                        items: _categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                        onChanged: (value) => setState(() => _selectedCategory = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(labelText: 'Base Unit (e.g. 1 kg)', border: OutlineInputBorder()),
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _costPriceController,
                        decoration: const InputDecoration(labelText: 'Cost Price (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _originalPriceController,
                        decoration: const InputDecoration(labelText: 'MRP (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStrategy,
                  decoration: const InputDecoration(labelText: 'Pricing Strategy', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'beat', child: Text('Beat Competitors (2% lower)')),
                    DropdownMenuItem(value: 'match', child: Text('Match Competitors')),
                    DropdownMenuItem(value: 'premium', child: Text('Premium (5% higher)')),
                    DropdownMenuItem(value: 'cost_plus', child: Text('Cost Plus (15% margin)')),
                  ],
                  onChanged: (value) => setState(() => _selectedStrategy = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(labelText: 'Main Stock Quantity', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _minStockController,
                  decoration: const InputDecoration(labelText: 'Min Stock for Alert', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                // Expiry Date Picker
                ListTile(
                  title: Text(_expiryDate == null
                      ? 'No Expiry Date'
                      : 'Expires: ${intl.DateFormat('dd/MM/yyyy').format(_expiryDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  tileColor: AppTheme.grey50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) setState(() => _expiryDate = date);
                  },
                ),
                const SizedBox(height: 16),
                
                // --- Variants Section ---
                const Divider(height: 32),
                const Text('Product Variants (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_unitOptions.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _unitOptions.length,
                    itemBuilder: (context, index) {
                      final opt = _unitOptions[index];
                      return ListTile(
                        title: Text('${opt.name} - ₹${opt.price}'),
                        subtitle: Text('Stock: ${opt.stockQuantity}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                          onPressed: () => setState(() => _unitOptions.removeAt(index)),
                        ),
                      );
                    },
                  ),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _variantNameController, decoration: const InputDecoration(labelText: 'Unit (e.g. 500g)', isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _variantPriceController, decoration: const InputDecoration(labelText: 'Price', isDense: true), keyboardType: TextInputType.number)),
                    IconButton(onPressed: _addVariant, icon: const Icon(Icons.add_circle, color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.white),
                      child: _isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Add Product'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _storageService.uploadImage(_selectedImage!, 'products');
      }

      final newProduct = ProductModel(
        id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        originalPrice: _originalPriceController.text.isNotEmpty ? double.parse(_originalPriceController.text) : double.parse(_priceController.text),
        unit: _unitController.text,
        category: _selectedCategory.toLowerCase(),
        shopId: authProvider.currentUser?.id ?? 'shop_001',
        shopName: authProvider.currentUser?.name ?? "Fufaji Online",
        imageUrl: imageUrl ?? 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400',
        stockQuantity: int.parse(_stockController.text),
        minimumStock: int.parse(_minStockController.text),
        costPrice: _costPriceController.text.isNotEmpty ? double.parse(_costPriceController.text) : null,
        pricingStrategy: _selectedStrategy,
        expiryDate: _expiryDate,
        district: authProvider.currentUser?.district ?? 'Jaipur',
        unitOptions: _unitOptions,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await productProvider.addProduct(newProduct);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding product: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

class EditProductDialog extends StatefulWidget {
  final ProductModel product;
  const EditProductDialog({super.key, required this.product});

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _costPriceController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  late String _selectedStrategy;
  late bool _isFeatured;
  late bool _isOnSale;
  late bool _isAvailable;
  DateTime? _expiryDate;
  final List<CompetitorPrice> _competitorPrices = [];
  final TextEditingController _compNameController = TextEditingController();
  final TextEditingController _compPriceController = TextEditingController();

  final List<String> _categories = [
    'Groceries',
    'Vegetables',
    'Fruits',
    'Dairy',
    'Bakery',
    'Beverages',
    'Household',
    'Personal Care',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _originalPriceController = TextEditingController(text: widget.product.originalPrice?.toString() ?? '');
    _costPriceController = TextEditingController(text: widget.product.costPrice?.toString() ?? '');
    _stockController = TextEditingController(text: widget.product.stockQuantity.toString());
    _minStockController = TextEditingController(text: widget.product.minimumStock.toString());
    _descriptionController = TextEditingController(text: widget.product.description);
    _selectedCategory = widget.product.category[0].toUpperCase() + widget.product.category.substring(1);
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'Groceries';
    }
    _selectedStrategy = widget.product.pricingStrategy ?? 'match';
    _isFeatured = widget.product.isFeatured;
    _isOnSale = widget.product.isOnSale;
    _isAvailable = widget.product.isAvailable;
    _expiryDate = widget.product.expiryDate;
    _competitorPrices.addAll(widget.product.competitorPrices);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    _compNameController.dispose();
    _compPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Product',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Selling Price (₹)',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _costPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Cost Price (₹)',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _originalPriceController,
                        decoration: const InputDecoration(
                          labelText: 'MRP (₹)',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStrategy,
                  decoration: const InputDecoration(
                    labelText: 'Pricing Strategy',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'beat', child: Text('Beat Competitors (2% lower)')),
                    DropdownMenuItem(value: 'match', child: Text('Match Competitors')),
                    DropdownMenuItem(value: 'premium', child: Text('Premium (5% higher)')),
                    DropdownMenuItem(value: 'cost_plus', child: Text('Cost Plus (15% margin)')),
                  ],
                  onChanged: (value) => setState(() => _selectedStrategy = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _minStockController,
                  decoration: const InputDecoration(
                    labelText: 'Min Stock for Alert',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                // Expiry Date Picker
                ListTile(
                  title: Text(_expiryDate == null
                      ? 'No Expiry Date'
                      : 'Expires: ${intl.DateFormat('dd/MM/yyyy').format(_expiryDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  tileColor: AppTheme.grey50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) setState(() => _expiryDate = date);
                  },
                ),
                const SizedBox(height: 16),
                // Competitor Prices
                const Text('Competitor Prices', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._competitorPrices.map((cp) => ListTile(
                  title: Text(cp.competitorName),
                  trailing: Text('₹${cp.price.round()}'),
                  dense: true,
                  onLongPress: () => setState(() => _competitorPrices.remove(cp)),
                )),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _compNameController, decoration: const InputDecoration(labelText: 'Store Name', isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _compPriceController, decoration: const InputDecoration(labelText: 'Price', isDense: true), keyboardType: TextInputType.number)),
                    IconButton(onPressed: () {
                      if (_compNameController.text.isNotEmpty && _compPriceController.text.isNotEmpty) {
                        setState(() {
                          _competitorPrices.add(CompetitorPrice(
                            competitorName: _compNameController.text,
                            price: double.parse(_compPriceController.text),
                            updatedAt: DateTime.now(),
                          ));
                          _compNameController.clear();
                          _compPriceController.clear();
                        });
                      }
                    }, icon: const Icon(Icons.add_circle_outline)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Switches for Featured/OnSale/Available
                SwitchListTile(
                  title: const Text('Available for Purchase'),
                  value: _isAvailable,
                  onChanged: (val) => setState(() => _isAvailable = val),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primary,
                ),
                SwitchListTile(
                  title: const Text('Mark as Featured'),
                  value: _isFeatured,
                  onChanged: (val) => setState(() => _isFeatured = val),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primary,
                ),
                SwitchListTile(
                  title: const Text('Mark as On Sale'),
                  value: _isOnSale,
                  onChanged: (val) => setState(() => _isOnSale = val),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.primary,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final productProvider = Provider.of<ProductProvider>(context, listen: false);

                          final updatedProduct = widget.product.copyWith(
                            name: _nameController.text,
                            description: _descriptionController.text,
                            price: double.parse(_priceController.text),
                            originalPrice: _originalPriceController.text.isNotEmpty
                                ? double.parse(_originalPriceController.text)
                                : double.parse(_priceController.text),
                            discountPercentage: _originalPriceController.text.isNotEmpty
                                ? (((double.parse(_originalPriceController.text) - double.parse(_priceController.text)) / double.parse(_originalPriceController.text)) * 100).roundToDouble()
                                : 0.0,
                            category: _selectedCategory.toLowerCase(),
                            stockQuantity: int.parse(_stockController.text),
                            minimumStock: int.parse(_minStockController.text),
                            costPrice: _costPriceController.text.isNotEmpty ? double.parse(_costPriceController.text) : null,
                            pricingStrategy: _selectedStrategy,
                            expiryDate: _expiryDate,
                            competitorPrices: _competitorPrices,
                            isAvailable: _isAvailable,
                            isFeatured: _isFeatured,
                            isOnSale: _isOnSale,
                            updatedAt: DateTime.now(),
                          );

                          try {
                            await productProvider.updateProduct(updatedProduct);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Product updated successfully!')),
                              );
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error updating product: $e')),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.white,
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BulkUploadDialog extends StatefulWidget {
  const BulkUploadDialog({super.key});

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog> {
  final TextEditingController _csvController = TextEditingController();
  bool _isUploading = false;
  String? _statusLog;

  final String _csvTemplate =
      'Name,Category,Price,OriginalPrice,Stock,Unit,Description\n'
      'Fresh Organic Potatoes,Vegetables,40,48,150,1 kg,Direct from local farm\n'
      'Mandi Red Onions,Vegetables,30,35,200,1 kg,High quality dry onions\n'
      'Desi Cow Ghee (A2),Dairy,680,750,45,500 ml,Bilona churned pure ghee\n'
      'Fresh Buffalo Milk,Dairy,64,68,120,1 L,Morning fresh milking\n'
      'Local Hapus Mango,Fruits,180,220,80,1 kg,Sweet ripe Alphonso\n'
      'Premium Basmati Rice,Groceries,115,130,300,1 kg,1121 long grain old rice\n'
      'Whole Wheat Flour (Atta),Groceries,45,52,500,5 kg,Freshly ground stone-milled flour\n'
      'Unrefined Jaggery (Gur),Groceries,55,70,90,1 kg,No chemical processing\n'
      'Organic Turmeric Powder,Groceries,160,180,150,250g,High curcumin content';

  void _loadTemplate() {
    setState(() {
      _csvController.text = _csvTemplate;
    });
  }

  Future<void> _startImport() async {
    final csvText = _csvController.text.trim();
    if (csvText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter CSV data or load template first.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _statusLog = 'Parsing CSV rows...';
    });

    final firestore = FirestoreService();
    final lines = csvText.split('\n');
    int successCount = 0;
    int errorCount = 0;
    final List<String> errors = [];

    // Skip header line if it looks like header
    int startIndex = 0;
    if (lines.isNotEmpty && lines[0].toLowerCase().contains('name')) {
      startIndex = 1;
    }

    final List<ProductModel> bulkItems = [];

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length < 5) {
        errorCount++;
        errors.add('Row ${i + 1}: Insufficient columns');
        continue;
      }

      try {
        final name = parts[0].trim();
        final category = parts[1].trim().toLowerCase();
        final price = double.parse(parts[2].trim());
        final originalPrice = double.parse(parts[3].trim());
        final stock = int.parse(parts[4].trim());
        final unit = parts.length > 5 ? parts[5].trim() : '1 unit';
        final description = parts.length > 6 ? parts[6].trim() : 'Premium quality $name';

        bulkItems.add(ProductModel(
          id: 'prod_bulk_${DateTime.now().millisecondsSinceEpoch}_$i',
          name: name,
          description: description,
          price: price,
          originalPrice: originalPrice,
          discountPercentage: originalPrice > 0 ? (((originalPrice - price) / originalPrice) * 100).roundToDouble() : 0.0,
          unit: unit,
          category: category,
          shopId: 'shop_001',
          shopName: "Fufaji Online",
          imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
          images: [],
          rating: 4.8,
          reviewCount: 0,
          stockQuantity: stock,
          isAvailable: true,
          isFeatured: false,
          isOnSale: false,
          isNewArrival: true,
          isTrending: false,
          specifications: {},
          tags: [name.toLowerCase(), category],
          district: 'Jaipur',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      } catch (e) {
        errorCount++;
        errors.add('Row ${i + 1}: $e');
      }
    }

    if (bulkItems.isNotEmpty) {
      try {
        setState(() => _statusLog = 'Uploading ${bulkItems.length} products in batches...');
        await firestore.batchAddProducts(bulkItems);
        successCount = bulkItems.length;
      } catch (e) {
        errors.add('Batch Write Failed: $e');
      }
    }

    setState(() {
      _isUploading = false;
      _statusLog = 'Import completed!\n'
          'Successfully imported: $successCount products.\n'
          'Failed: $errorCount rows.\n'
          '${errors.isNotEmpty ? '\nErrors:\n${errors.join('\n')}' : ''}';
    });

    if (context.mounted && successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully bulk-uploaded $successCount products!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 550,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bulk CSV Catalog Uploader',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Copy & paste comma-separated product lists to instantly add them in bulk. Column order must match: Name, Category, Price, OriginalPrice, Stock, Unit, Description',
              style: TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isUploading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          Text(
                            _statusLog ?? 'Processing catalog database...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey800),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _csvController,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Paste CSV rows here...',
                              border: const OutlineInputBorder(),
                              fillColor: AppTheme.grey50,
                              filled: true,
                            ),
                          ),
                        ),
                        if (_statusLog != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 120,
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.grey100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.grey300),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _statusLog!,
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.grey700),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            if (!_isUploading)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadTemplate,
                    icon: const Icon(Icons.note_add),
                    label: const Text('Insert Sample Template'),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _startImport,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Start Import'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
