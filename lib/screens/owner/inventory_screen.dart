import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:math';
import '../../utils/app_theme.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import 'products_management.dart';
import 'bill_scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['All', 'Low Stock', 'Out of Stock', 'Expiring Soon', 'Expired'];
  final ProductService _productService = ProductService();
  String _searchQuery = '';
  bool _autoReorderEnabled = false;
  bool _isAutoReordering = false;
  int _globalThreshold = 10;

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    var products = [...productProvider.products];

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      products = products
          .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Filter by stock and expiry status
    if (_selectedFilter == 1) {
      // Low stock (below minimumStock)
      products = products
          .where((p) => p.stockQuantity > 0 && p.stockQuantity < p.minimumStock)
          .toList();
    } else if (_selectedFilter == 2) {
      // Out of stock (0)
      products = products.where((p) => p.stockQuantity == 0).toList();
    } else if (_selectedFilter == 3) {
      // Expiring Soon (1-7 days)
      products = products
          .where(
            (p) =>
                p.expiryDate != null &&
                p.expiryDate!.difference(DateTime.now()).inDays >= 0 &&
                p.expiryDate!.difference(DateTime.now()).inDays <= 7,
          )
          .toList();
    } else if (_selectedFilter == 4) {
      // Expired
      products = products
          .where(
            (p) => p.isExpired || (p.expiryDate != null && p.expiryDate!.isBefore(DateTime.now())),
          )
          .toList();
    }

    // Handle Auto-Reorder logic if enabled
    if (_autoReorderEnabled) {
      final lowStockProducts = products.where((p) => p.stockQuantity < p.minimumStock).toList();
      if (lowStockProducts.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _triggerAutoReorder(lowStockProducts, productProvider);
        });
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inventory',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              const SizedBox(height: 12),
              // Primary Actions Row (Scan Bill + Quick Add Stock)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => const BillScannerScreen())),
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Scan Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddStockDialog(context, productProvider.products),
                      icon: const Icon(Icons.add),
                      label: const Text('Quick Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.white,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Secondary Actions Row (Audit Logs + Threshold Settings)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/owner/inventory-audit'),
                      icon: const Icon(Icons.history),
                      label: const Text('Audit Logs'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.ownerAccent,
                        side: const BorderSide(color: AppTheme.ownerAccent),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showSettingsDialog(context),
                      icon: const Icon(Icons.settings),
                      label: const Text('Settings'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.grey800,
                        side: const BorderSide(color: AppTheme.grey300),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats Cards
          _buildStatsRow(productProvider.products),
          const SizedBox(height: 20),
          // Low Stock Warnings
          _buildAlertsPanel(productProvider.products, productProvider),
          const SizedBox(height: 24),
          // Search & Filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products by name...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppTheme.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: _filters[_selectedFilter],
                  underline: const SizedBox(),
                  isDense: true,
                  items: _filters
                      .map(
                        (filter) => DropdownMenuItem(
                          value: filter,
                          child: Text(filter, style: const TextStyle(fontSize: 14)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedFilter = _filters.indexOf(value);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Inventory List
          _buildInventoryList(products),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<ProductModel> allProducts) {
    final lowStockCount = allProducts
        .where((p) => p.stockQuantity > 0 && p.stockQuantity < p.minimumStock)
        .length;
    final outOfStockCount = allProducts.where((p) => p.stockQuantity == 0).length;
    final expiringSoonCount = allProducts
        .where(
          (p) =>
              p.expiryDate != null &&
              p.expiryDate!.difference(DateTime.now()).inDays >= 0 &&
              p.expiryDate!.difference(DateTime.now()).inDays <= 7,
        )
        .length;
    final expiredCount = allProducts
        .where(
          (p) => p.isExpired || (p.expiryDate != null && p.expiryDate!.isBefore(DateTime.now())),
        )
        .length;

    final stats = [
      {'label': 'Low Stock', 'value': lowStockCount.toString(), 'color': AppTheme.warning},
      {'label': 'Out of Stock', 'value': outOfStockCount.toString(), 'color': AppTheme.error},
      {'label': 'Expiring Soon', 'value': expiringSoonCount.toString(), 'color': AppTheme.warning},
      {'label': 'Expired', 'value': expiredCount.toString(), 'color': AppTheme.error},
    ];

    return Row(
      children: stats.map((stat) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat['value'] as String,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: stat['color'] as Color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat['label'] as String,
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInventoryList(List<ProductModel> products) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text('No inventory items match the current filters.'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildInventoryItem(product);
      },
    );
  }

  Widget _buildInventoryItem(ProductModel product) {
    final bool isLowStock =
        product.stockQuantity > 0 && product.stockQuantity < product.minimumStock;
    final bool isOutOfStock = product.stockQuantity == 0;

    // Expiry status
    String? expiryText;
    Color expiryColor = AppTheme.success;
    if (product.expiryDate != null) {
      final daysToExpiry = product.expiryDate!.difference(DateTime.now()).inDays;
      if (daysToExpiry < 0) {
        expiryText = 'Expired';
        expiryColor = AppTheme.error;
      } else if (daysToExpiry <= 7) {
        expiryText = 'Expiring in $daysToExpiry days';
        expiryColor = AppTheme.warning;
      } else {
        expiryText = 'Expires: ${intl.DateFormat('dd/MM').format(product.expiryDate!)}';
        expiryColor = AppTheme.success;
      }
    }

    final stockStatus = isOutOfStock
        ? 'Out of Stock'
        : isLowStock
        ? 'Low Stock'
        : 'In Stock';

    final statusColor = isOutOfStock
        ? AppTheme.error
        : isLowStock
        ? AppTheme.warning
        : AppTheme.success;

    final sku = product.id
        .toUpperCase()
        .replaceAll('PROD_', '')
        .substring(0, min(6, product.id.length));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Thumbnail
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2, color: AppTheme.primary),
          ),
          const SizedBox(width: 16),
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'SKU: $sku | ₹${product.price}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                    if (expiryText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: expiryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          expiryText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: expiryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    stockStatus,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          // Stock Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.stockQuantity}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor),
              ),
              Text(
                'Min: ${product.minimumStock}',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Actions - 48dp touch targets for accessibility
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => EditProductDialog(product: product),
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _quickIncrementStock(product, 10),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_circle, color: AppTheme.success, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickIncrementStock(ProductModel product, int amount) async {
    try {
      await _productService.updateProduct(product.id, {
        'stockQuantity': product.stockQuantity + amount,
        'isAvailable': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Quick added $amount units to ${product.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update stock: $e')));
      }
    }
  }

  void _showAddStockDialog(BuildContext context, List<ProductModel> allProducts) {
    if (allProducts.isEmpty) return;
    ProductModel selectedProduct = allProducts.first;
    final controller = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Quick Inventory Addition',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ProductModel>(
                initialValue: selectedProduct,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Product',
                  border: OutlineInputBorder(),
                ),
                items: allProducts
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedProduct = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stock Units to Add',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = int.tryParse(controller.text);
                if (amount != null) {
                  try {
                    await _productService.updateProduct(selectedProduct.id, {
                      'stockQuantity': selectedProduct.stockQuantity + amount,
                      'isAvailable': true,
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Quick stock added successfully!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              child: const Text('Add Stock'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsPanel(List<ProductModel> products, ProductProvider provider) {
    final lowStockItems = products.where((p) => p.stockQuantity < p.minimumStock).toList();
    if (lowStockItems.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Low Stock Warning Alerts (${lowStockItems.length} items)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.error,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (!_autoReorderEnabled)
                TextButton.icon(
                  onPressed: () async {
                    for (final item in lowStockItems) {
                      await _quickIncrementStock(item, 50);
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reorder All (+50)', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: lowStockItems.length,
              itemBuilder: (context, index) {
                final item = lowStockItems[index];
                return Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'Stock: ${item.stockQuantity} (Min: ${item.minimumStock})',
                              style: const TextStyle(fontSize: 10, color: AppTheme.grey600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await _quickIncrementStock(item, 50);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error.withOpacity(0.1),
                          foregroundColor: AppTheme.error,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(60, 32),
                        ),
                        child: const Text('Reorder', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerAutoReorder(
    List<ProductModel> lowStockItems,
    ProductProvider provider,
  ) async {
    if (_isAutoReordering) return;
    _isAutoReordering = true;

    int reorderCount = 0;
    for (final item in lowStockItems) {
      try {
        await _productService.updateProduct(item.id, {
          'stockQuantity': item.stockQuantity + 50,
          'isAvailable': true,
        });
        reorderCount++;
      } catch (e) {
        debugPrint('Auto-reorder failed for ${item.name}: $e');
      }
    }

    if (reorderCount > 0) {
      await provider.refreshProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-Reorder Executed: Replenished $reorderCount low-stock products (+50 units each).',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
    _isAutoReordering = false;
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Reorder Threshold Settings'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure warning levels and automation rules for replenishment pipelines.',
                style: TextStyle(fontSize: 12, color: AppTheme.grey600),
              ),
              const SizedBox(height: 20),
              Text(
                'Warning Threshold Limit: $_globalThreshold units',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('1'),
                  Expanded(
                    child: Slider(
                      value: _globalThreshold.toDouble(),
                      min: 1,
                      max: 20,
                      divisions: 19,
                      activeColor: AppTheme.primary,
                      onChanged: (val) {
                        setDialogState(() => _globalThreshold = val.round());
                        setState(() {});
                      },
                    ),
                  ),
                  const Text('20'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Pilot Reorder Refills',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Auto-purchase +50 stock under threshold',
                        style: TextStyle(fontSize: 10, color: AppTheme.grey500),
                      ),
                    ],
                  ),
                  Switch(
                    value: _autoReorderEnabled,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) {
                      setDialogState(() => _autoReorderEnabled = val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply Configuration'),
            ),
          ],
        ),
      ),
    );
  }
}
