import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/product_provider.dart';
import '../../providers/product_provider_extensions.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

/// Expiry Tracking Screen
/// Displays products with expiry dates and dynamic markdown pricing
class ExpiryTrackingScreen extends StatefulWidget {
  const ExpiryTrackingScreen({super.key});

  @override
  State<ExpiryTrackingScreen> createState() => _ExpiryTrackingScreenState();
}

class _ExpiryTrackingScreenState extends State<ExpiryTrackingScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = false;
  List<ProductModel> _filteredProducts = [];
  Map<String, dynamic> _expiryStats = {};

  @override
  void initState() {
    super.initState();
    _loadExpiryData();
  }

  Future<void> _loadExpiryData() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ProductProvider>();

      // Get expiring products
      final expiringProducts = await provider.getExpiringProducts();
      final expiredProducts = await provider.getExpiredProducts();

      // Calculate stats
      _expiryStats = {
        'expiringToday': expiringProducts
            .where((p) => p.expiryDate?.difference(DateTime.now()).inDays == 0)
            .length,
        'expiringThisWeek': expiringProducts.where((p) {
          final days = p.expiryDate?.difference(DateTime.now()).inDays ?? 0;
          return days > 0 && days <= 7;
        }).length,
        'expiringThisMonth': expiringProducts.where((p) {
          final days = p.expiryDate?.difference(DateTime.now()).inDays ?? 0;
          return days > 7 && days <= 30;
        }).length,
        'expired': expiredProducts.length,
        'totalLoss': _calculateTotalLoss(expiredProducts),
      };

      _filterProducts(expiringProducts, expiredProducts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading expiry data: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _calculateTotalLoss(List<ProductModel> expiredProducts) {
    return expiredProducts.fold(0.0, (sum, product) {
      return sum + (product.price * product.stockQuantity).toDouble();
    });
  }

  void _filterProducts(List<ProductModel> expiringProducts, List<ProductModel> expiredProducts) {
    List<ProductModel> filtered = [];

    switch (_selectedFilter) {
      case 'Today':
        filtered = expiringProducts
            .where((p) => p.expiryDate?.difference(DateTime.now()).inDays == 0)
            .toList();
        break;
      case 'This Week':
        filtered = expiringProducts.where((p) {
          final days = p.expiryDate?.difference(DateTime.now()).inDays ?? 0;
          return days > 0 && days <= 7;
        }).toList();
        break;
      case 'This Month':
        filtered = expiringProducts.where((p) {
          final days = p.expiryDate?.difference(DateTime.now()).inDays ?? 0;
          return days > 7 && days <= 30;
        }).toList();
        break;
      case 'Expired':
        filtered = expiredProducts;
        break;
      default:
        filtered = [...expiringProducts, ...expiredProducts];
    }

    // Sort by expiry date
    filtered.sort((a, b) {
      final aDate = a.expiryDate ?? DateTime.now();
      final bDate = b.expiryDate ?? DateTime.now();
      return aDate.compareTo(bDate);
    });

    setState(() => _filteredProducts = filtered);
  }

  Future<void> _markAsSold(ProductModel product) async {
    try {
      final provider = context.read<ProductProvider>();
      await provider.markProductAsSold(product.id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product marked as sold')));
      }

      await _loadExpiryData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _extendExpiry(ProductModel product) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: product.expiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDate != null) {
      try {
        final provider = context.read<ProductProvider>();
        await provider.updateExpiryDate(product.id, newDate);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Expiry date updated')));
        }

        await _loadExpiryData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  int _getDaysUntilExpiry(DateTime? expiryDate) {
    if (expiryDate == null) return 0;
    return expiryDate.difference(DateTime.now()).inDays;
  }

  double _getMarkdownPercentage(int daysUntilExpiry) {
    if (daysUntilExpiry <= 0) return 100; // Expired
    if (daysUntilExpiry == 1) return 50;
    if (daysUntilExpiry <= 3) return 30;
    if (daysUntilExpiry <= 7) return 15;
    return 0;
  }

  Color _getExpiryColor(int daysUntilExpiry) {
    if (daysUntilExpiry <= 0) return AppTheme.error;
    if (daysUntilExpiry == 1) return AppTheme.error;
    if (daysUntilExpiry <= 3) return AppTheme.warning;
    if (daysUntilExpiry <= 7) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiry Tracking', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : Column(
              children: [
                // Stats Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatCard(
                          'Today',
                          _expiryStats['expiringToday']?.toString() ?? '0',
                          AppTheme.error,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'This Week',
                          _expiryStats['expiringThisWeek']?.toString() ?? '0',
                          AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'This Month',
                          _expiryStats['expiringThisMonth']?.toString() ?? '0',
                          AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'Expired',
                          _expiryStats['expired']?.toString() ?? '0',
                          Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),

                // Loss Alert
                if ((_expiryStats['totalLoss'] as num? ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.error),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: AppTheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Potential loss: ₹${(_expiryStats['totalLoss'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Today', 'This Week', 'This Month', 'Expired']
                          .map(
                            (filter) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter),
                                selected: _selectedFilter == filter,
                                onSelected: (_) {
                                  setState(() => _selectedFilter = filter);
                                  _loadExpiryData();
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Products List
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 64, color: AppTheme.success),
                              const SizedBox(height: 16),
                              const Text(
                                'No products',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No expiring products in this category',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final daysUntilExpiry = _getDaysUntilExpiry(product.expiryDate);
                            final markdownPercentage = _getMarkdownPercentage(daysUntilExpiry);
                            final markdownPrice = product.price * (1 - markdownPercentage / 100);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Stock: ${product.stockQuantity}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getExpiryColor(
                                              daysUntilExpiry,
                                            ).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            daysUntilExpiry <= 0
                                                ? 'Expired'
                                                : '$daysUntilExpiry days',
                                            style: TextStyle(
                                              color: _getExpiryColor(daysUntilExpiry),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Expiry Date
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Expires: ${DateFormat('MMM dd, yyyy').format(product.expiryDate ?? DateTime.now())}',
                                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Pricing
                                    if (markdownPercentage > 0)
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warning,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Original Price',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  product.price.toDisplayString(),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Markdown Price',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  markdownPrice.toDisplayString(),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.success,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.error,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '-${markdownPercentage.toStringAsFixed(0)}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Text(
                                        'Price: ${product.price.toDisplayString()}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    const SizedBox(height: 12),

                                    // Actions
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _markAsSold(product),
                                            child: const Text('Mark as Sold'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _extendExpiry(product),
                                            child: const Text('Extend Expiry'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
