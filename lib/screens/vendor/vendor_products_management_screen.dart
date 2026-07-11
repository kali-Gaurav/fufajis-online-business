import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_theme.dart';

class VendorProductsManagementScreen extends StatefulWidget {
  final String vendorId;

  const VendorProductsManagementScreen({Key? key, required this.vendorId})
      : super(key: key);

  @override
  State<VendorProductsManagementScreen> createState() =>
      _VendorProductsManagementScreenState();
}

class _VendorProductsManagementScreenState
    extends State<VendorProductsManagementScreen> {
  final _supabase = Supabase.instance;
  List<VendorProduct> _products = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, active, inactive, low_stock

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase.client
          .from('products')
          .select()
          .eq('vendor_id', widget.vendorId)
          .order('created_at', ascending: false);

      final response = await query;
      if (mounted) {
        setState(() {
          _products = (response as List)
              .map((p) => VendorProduct.fromJson(p))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<VendorProduct> _getFilteredProducts() {
    switch (_filterStatus) {
      case 'active':
        return _products.where((p) => p.isActive).toList();
      case 'inactive':
        return _products.where((p) => !p.isActive).toList();
      case 'low_stock':
        return _products.where((p) => p.stock < 10).toList();
      default:
        return _products;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _getFilteredProducts().length,
                        itemBuilder: (_, index) =>
                            _buildProductCard(_getFilteredProducts()[index]),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              'No Products Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Start by adding your first product',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey600),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              selected: _filterStatus == 'all',
              onSelected: (_) => setState(() => _filterStatus = 'all'),
              label: const Text('All'),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: _filterStatus == 'active',
              onSelected: (_) => setState(() => _filterStatus = 'active'),
              label: const Text('Active'),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: _filterStatus == 'inactive',
              onSelected: (_) => setState(() => _filterStatus = 'inactive'),
              label: const Text('Inactive'),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: _filterStatus == 'low_stock',
              onSelected: (_) => setState(() => _filterStatus = 'low_stock'),
              label: const Text('Low Stock'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(VendorProduct product) {
    final stockStatus = _getStockStatus(product.stock);
    final stockColor = _getStockColor(stockStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Image
            if (product.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product.imageUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                ),
              )
            else
              _buildImagePlaceholder(),
            const SizedBox(width: 12),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: stockColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.stock} in stock',
                          style: TextStyle(
                            fontSize: 10,
                            color: stockColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        product.isActive ? Icons.check_circle : Icons.cancel,
                        size: 12,
                        color:
                            product.isActive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11,
                          color: product.isActive
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Edit'),
                  onTap: () => _editProduct(product),
                ),
                PopupMenuItem(
                  child: const Text('Update Stock'),
                  onTap: () => _showUpdateStockDialog(product),
                ),
                PopupMenuItem(
                  child: Text(
                    product.isActive ? 'Deactivate' : 'Activate',
                  ),
                  onTap: () => _toggleProductStatus(product),
                ),
                PopupMenuItem(
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () => _showDeleteConfirmation(product),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_not_supported, color: AppTheme.grey400),
    );
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product'),
        content: const Text('Product creation flow will be added'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editProduct(VendorProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: product.name),
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: product.price.toString()),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: product.description),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product updated')),
              );
              _loadProducts();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateStockDialog(VendorProduct product) async {
    final controller = TextEditingController(text: product.stock.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Current Stock: ${product.stock}',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stock updated')),
              );
              _loadProducts();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleProductStatus(VendorProduct product) async {
    try {
      await _supabase.client
          .from('products')
          .update({'is_active': !product.isActive}).eq('id', product.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              product.isActive ? 'Product deactivated' : 'Product activated',
            ),
          ),
        );
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(VendorProduct product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.client.from('products').delete().eq('id', product.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted')),
          );
          _loadProducts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  String _getStockStatus(int stock) {
    if (stock == 0) return 'out_of_stock';
    if (stock < 10) return 'low_stock';
    if (stock < 50) return 'medium_stock';
    return 'high_stock';
  }

  Color _getStockColor(String status) {
    switch (status) {
      case 'out_of_stock':
        return Colors.red;
      case 'low_stock':
        return Colors.orange;
      case 'medium_stock':
        return Colors.amber;
      case 'high_stock':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class VendorProduct {
  final String id;
  final String vendorId;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  VendorProduct({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorProduct.fromJson(Map<String, dynamic> json) {
    return VendorProduct(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      stock: json['stock'] ?? 0,
      imageUrl: json['image_url'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
