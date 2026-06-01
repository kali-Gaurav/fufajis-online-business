import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';

class ExpiryManagementScreen extends StatefulWidget {
  const ExpiryManagementScreen({super.key});

  @override
  State<ExpiryManagementScreen> createState() => _ExpiryManagementScreenState();
}

class _ExpiryManagementScreenState extends State<ExpiryManagementScreen> {
  bool _isLoading = false;
  List<ProductModel> _expiringProducts = [];
  String _filterStatus = 'all'; // all, critical, warning, ok

  @override
  void initState() {
    super.initState();
    _loadExpiringProducts();
  }

  Future<void> _loadExpiringProducts() async {
    setState(() => _isLoading = true);
    try {
      final productProvider = context.read<ProductProvider>();
      final products = await productProvider.getProductsWithExpiry();
      setState(() {
        _expiringProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load products');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  ExpiryStatus _getExpiryStatus(ProductModel product) {
    if (product.expiryDate == null) return ExpiryStatus.ok;

    final now = DateTime.now();
    final daysUntilExpiry = product.expiryDate!.difference(now).inDays;

    if (daysUntilExpiry <= 0) return ExpiryStatus.expired;
    if (daysUntilExpiry <= 7) return ExpiryStatus.critical;
    if (daysUntilExpiry <= 30) return ExpiryStatus.warning;
    return ExpiryStatus.ok;
  }

  int _getDaysUntilExpiry(ProductModel product) {
    if (product.expiryDate == null) return 999;
    return product.expiryDate!.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _expiringProducts.where((product) {
      final status = _getExpiryStatus(product);
      if (_filterStatus == 'all') return true;
      return status.name == _filterStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Expiry Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadExpiringProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                SizedBox(width: 8),
                _buildFilterChip('Critical', 'critical', color: Colors.red),
                SizedBox(width: 8),
                _buildFilterChip('Warning', 'warning', color: Colors.orange),
                SizedBox(width: 8),
                _buildFilterChip('OK', 'ok', color: Colors.green),
              ],
            ),
          ),

          // Summary Card
          _buildSummaryCard(),

          // Product List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle,
                                size: 64, color: Colors.green),
                            SizedBox(height: 16),
                            Text(
                              'No products match filter',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          final status = _getExpiryStatus(product);
                          final days = _getDaysUntilExpiry(product);

                          return _buildProductCard(product, status, days);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color?.withOpacity(0.3),
      checkmarkColor: color,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = value);
        }
      },
    );
  }

  Widget _buildSummaryCard() {
    final critical = _expiringProducts
        .where((p) => _getExpiryStatus(p) == ExpiryStatus.critical)
        .length;
    final warning = _expiringProducts
        .where((p) => _getExpiryStatus(p) == ExpiryStatus.warning)
        .length;
    final expired = _expiringProducts
        .where((p) => _getExpiryStatus(p) == ExpiryStatus.expired)
        .length;

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSummaryItem('Expired', expired, Colors.red),
            _buildSummaryItem('Critical', critical, Colors.orange),
            _buildSummaryItem('Warning', warning, Colors.amber),
            _buildSummaryItem('Total', _expiringProducts.length, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildProductCard(
      ProductModel product, ExpiryStatus status, int days) {
    final color = _getStatusColor(status);
    final markdownPercent = _calculateMarkdown(status);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  status == ExpiryStatus.expired
                      ? Icons.error
                      : status == ExpiryStatus.critical
                          ? Icons.warning
                          : Icons.info,
                  color: color,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    status == ExpiryStatus.expired ? 'EXPIRED' : '$days days',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: color,
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Stock: ${product.stockQuantity} ${product.unit}'),
                    if (product.expiryDate != null)
                      Text(
                        'Exp: ${_formatDate(product.expiryDate!)}',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                if (status != ExpiryStatus.ok && markdownPercent > 0)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.discount, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Suggested Markdown: $markdownPercent%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _markAsSold(product),
                        icon: Icon(Icons.sell),
                        label: Text('Mark as Sold'),
                      ),
                    ),
                    SizedBox(width: 8),
                    if (status == ExpiryStatus.expired)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _disposeExpired(product),
                          icon: Icon(Icons.delete),
                          label: Text('Dispose'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateMarkdown(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return 100;
      case ExpiryStatus.critical:
        return 50;
      case ExpiryStatus.warning:
        return 30;
      default:
        return 0;
    }
  }

  Color _getStatusColor(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return Colors.red;
      case ExpiryStatus.critical:
        return Colors.orange;
      case ExpiryStatus.warning:
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _markAsSold(ProductModel product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked ${product.name} as sold')),
    );
  }

  void _disposeExpired(ProductModel product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Disposed ${product.name}')),
    );
  }
}

enum ExpiryStatus {
  expired,
  critical,
  warning,
  ok,
}
