import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class InventoryVisualImprovementsScreen extends StatefulWidget {
  const InventoryVisualImprovementsScreen({Key? key}) : super(key: key);

  @override
  State<InventoryVisualImprovementsScreen> createState() =>
      _InventoryVisualImprovementsScreenState();
}

class _InventoryVisualImprovementsScreenState
    extends State<InventoryVisualImprovementsScreen> {
  List<InventoryItem> _items = [];
  String _filterCategory = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _items = [
        InventoryItem(
          id: '1',
          name: 'Milk (1L)',
          category: 'dairy',
          currentStock: 45,
          maxStock: 100,
          reorderPoint: 20,
          expiryDays: 3,
          location: 'Shelf A1',
          unit: 'pcs',
        ),
        InventoryItem(
          id: '2',
          name: 'Bread',
          category: 'bakery',
          currentStock: 8,
          maxStock: 50,
          reorderPoint: 15,
          expiryDays: 1,
          location: 'Display Front',
          unit: 'pcs',
        ),
        InventoryItem(
          id: '3',
          name: 'Tomatoes',
          category: 'vegetables',
          currentStock: 125,
          maxStock: 200,
          reorderPoint: 50,
          expiryDays: 5,
          location: 'Shelf C3',
          unit: 'kg',
        ),
        InventoryItem(
          id: '4',
          name: 'Apples',
          category: 'fruits',
          currentStock: 78,
          maxStock: 150,
          reorderPoint: 40,
          expiryDays: 7,
          location: 'Display Produce',
          unit: 'kg',
        ),
        InventoryItem(
          id: '5',
          name: 'Butter',
          category: 'dairy',
          currentStock: 5,
          maxStock: 30,
          reorderPoint: 10,
          expiryDays: 30,
          location: 'Shelf A2',
          unit: 'pcs',
        ),
        InventoryItem(
          id: '6',
          name: 'Rice (5kg)',
          category: 'pantry',
          currentStock: 12,
          maxStock: 40,
          reorderPoint: 15,
          expiryDays: 365,
          location: 'Shelf B1',
          unit: 'bags',
        ),
      ];
      _isLoading = false;
    });
  }

  List<InventoryItem> _getFilteredItems() {
    if (_filterCategory == 'all') return _items;
    return _items.where((item) => item.category == _filterCategory).toList();
  }

  List<InventoryItem> _getItemsByExpiry(int days) {
    return _items
        .where((item) => item.expiryDays > 0 && item.expiryDays <= days)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Inventory Management', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStockGauges(),
                  const SizedBox(height: 24),
                  _buildExpiryMatrix(),
                  const SizedBox(height: 24),
                  _buildInventoryGrid(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStockGauges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stock Gauges',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _items
                .take(3)
                .map((item) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildStockGauge(item),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStockGauge(InventoryItem item) {
    final percentage = (item.currentStock / item.maxStock).clamp(0.0, 1.0);
    final statusColor = _getStockColor(item.currentStock, item.maxStock, item.reorderPoint);

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${item.currentStock}/${item.maxStock}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.grey600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getStockStatus(item.currentStock, item.maxStock, item.reorderPoint),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryMatrix() {
    final criticalExpiry = _getItemsByExpiry(1);
    final warningExpiry = _getItemsByExpiry(7);
    final soonExpiry = _getItemsByExpiry(30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expiry Alert Matrix',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildExpiryCard(
                'Critical',
                criticalExpiry.length,
                Colors.red,
                'Expires today/tomorrow',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExpiryCard(
                'Warning',
                warningExpiry.length,
                Colors.orange,
                'Expires within 7 days',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExpiryCard(
                'Soon',
                soonExpiry.length,
                Colors.amber,
                'Expires within 30 days',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (criticalExpiry.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.red[600], size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Critical Expiry Items',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  children: criticalExpiry
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text(item.name,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                const Spacer(),
                                Text('Expires in ${item.expiryDays} day(s)',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.grey600)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildExpiryCard(String label, int count, Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 9, color: AppTheme.grey600),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Inventory Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            DropdownButton<String>(
              value: _filterCategory,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Categories')),
                DropdownMenuItem(value: 'dairy', child: Text('Dairy')),
                DropdownMenuItem(value: 'vegetables', child: Text('Vegetables')),
                DropdownMenuItem(value: 'fruits', child: Text('Fruits')),
                DropdownMenuItem(value: 'bakery', child: Text('Bakery')),
                DropdownMenuItem(value: 'pantry', child: Text('Pantry')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _filterCategory = val);
                }
              },
              underline: const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: _getFilteredItems()
              .map((item) => _buildInventoryItemCard(item))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildInventoryItemCard(InventoryItem item) {
    final statusColor = _getStockColor(item.currentStock, item.maxStock, item.reorderPoint);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Text(
                      '${(item.currentStock / item.maxStock * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (item.currentStock / item.maxStock).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.currentStock}${item.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                Text(
                  'Max: ${item.maxStock}',
                  style: const TextStyle(fontSize: 9, color: AppTheme.grey600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.expiryDays > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getExpiryColor(item.expiryDays).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'Expires in ${item.expiryDays}d',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: _getExpiryColor(item.expiryDays),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              item.location,
              style: const TextStyle(fontSize: 9, color: AppTheme.grey600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStockColor(int current, int max, int reorder) {
    if (current < reorder) return Colors.red;
    if (current < (max * 0.5)) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatus(int current, int max, int reorder) {
    if (current < reorder) return 'CRITICAL';
    if (current < (max * 0.5)) return 'LOW';
    return 'GOOD';
  }

  Color _getExpiryColor(int days) {
    if (days <= 1) return Colors.red;
    if (days <= 7) return Colors.orange;
    if (days <= 30) return Colors.amber;
    return Colors.green;
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final int currentStock;
  final int maxStock;
  final int reorderPoint;
  final int expiryDays;
  final String location;
  final String unit;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.maxStock,
    required this.reorderPoint,
    required this.expiryDays,
    required this.location,
    required this.unit,
  });
}
