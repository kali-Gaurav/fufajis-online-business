import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class ProductCardEnhancementsScreen extends StatefulWidget {
  final String productId;

  const ProductCardEnhancementsScreen({Key? key, required this.productId})
      : super(key: key);

  @override
  State<ProductCardEnhancementsScreen> createState() =>
      _ProductCardEnhancementsScreenState();
}

class _ProductCardEnhancementsScreenState
    extends State<ProductCardEnhancementsScreen> {
  late List<PriceHistory> _priceHistory;
  late Product _product;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  Future<void> _loadProductData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _product = Product(
        id: widget.productId,
        name: 'Organic Tomatoes',
        currentPrice: 45.00,
        category: 'vegetables',
        vendorId: 'vendor_001',
        vendorName: 'Fresh Farms Co.',
        vendorRating: 4.8,
        vendorReviews: 342,
        imageUrl: 'https://via.placeholder.com/300x300?text=Tomatoes',
      );

      _priceHistory = [
        PriceHistory(date: DateTime.now().subtract(const Duration(days: 30)), price: 50.00),
        PriceHistory(date: DateTime.now().subtract(const Duration(days: 25)), price: 48.00),
        PriceHistory(date: DateTime.now().subtract(const Duration(days: 20)), price: 46.00),
        PriceHistory(date: DateTime.now().subtract(const Duration(days: 15)), price: 47.00),
        PriceHistory(date: DateTime.now().subtract(const Duration(days: 10)), price: 44.00),
        PriceHistory(date: DateTime.now().subtract(const Duration(days: 5)), price: 45.00),
        PriceHistory(date: DateTime.now(), price: 45.00),
      ];

      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Product Details', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  _buildProductHeader(),
                  const SizedBox(height: 24),
                  _buildVendorRatingCard(),
                  const SizedBox(height: 24),
                  _buildPriceTrendsChart(),
                  const SizedBox(height: 24),
                  _buildBatchInformationSection(),
                  const SizedBox(height: 24),
                  _buildExpiryIndicators(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildProductHeader() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.grey100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image_not_supported,
                    color: AppTheme.grey400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₹${_product.currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-10%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _product.category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorRatingCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seller Information',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.store,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _product.vendorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${_product.vendorRating.toStringAsFixed(1)} (${_product.vendorReviews} reviews)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Verified',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildVendorStat('On-Time', '98%', Colors.green),
                  _buildVendorStat('Quality', '4.8★', Colors.amber),
                  _buildVendorStat('Support', '24h', Colors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.grey600,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceTrendsChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price Trends (30 Days)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 150,
                  child: CustomPaint(
                    painter: PriceTrendPainter(_priceHistory),
                    size: const Size(double.infinity, 150),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Highest',
                          style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_priceHistory.map((p) => p.price).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.grey900,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Average',
                          style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${(_priceHistory.map((p) => p.price).reduce((a, b) => a + b) / _priceHistory.length).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Lowest',
                          style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_priceHistory.map((p) => p.price).reduce((a, b) => a < b ? a : b).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.grey900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchInformationSection() {
    final batches = [
      BatchInfo(
        batchNumber: 'BATCH-2026-0847',
        lotNumber: 'LOT-202607-001',
        manufacturingDate: DateTime.now().subtract(const Duration(days: 5)),
        expiryDate: DateTime.now().add(const Duration(days: 25)),
        quantity: 150,
        location: 'Shelf A2',
      ),
      BatchInfo(
        batchNumber: 'BATCH-2026-0846',
        lotNumber: 'LOT-202607-002',
        manufacturingDate: DateTime.now().subtract(const Duration(days: 10)),
        expiryDate: DateTime.now().add(const Duration(days: 20)),
        quantity: 85,
        location: 'Shelf A1',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Batch Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: batches.length,
          itemBuilder: (_, index) => _buildBatchCard(batches[index]),
        ),
      ],
    );
  }

  Widget _buildBatchCard(BatchInfo batch) {
    final daysUntilExpiry = batch.expiryDate.difference(DateTime.now()).inDays;
    final expiryColor = daysUntilExpiry <= 3
        ? Colors.red
        : daysUntilExpiry <= 7
            ? Colors.orange
            : Colors.amber;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.batchNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      batch.lotNumber,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: expiryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Exp: ${daysUntilExpiry}d',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: expiryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manufactured',
                      style: TextStyle(fontSize: 9, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${batch.manufacturingDate.day}/${batch.manufacturingDate.month}/${batch.manufacturingDate.year}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Expiry',
                      style: TextStyle(fontSize: 9, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${batch.expiryDate.day}/${batch.expiryDate.month}/${batch.expiryDate.year}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: expiryColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Available',
                      style: TextStyle(fontSize: 9, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${batch.quantity} units',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'Location: ${batch.location}',
                style: const TextStyle(fontSize: 9, color: AppTheme.grey600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryIndicators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expiry Status',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildExpiryCard(
                'Available',
                '235',
                'units in stock',
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExpiryCard(
                'Expiring Soon',
                '47',
                'within 7 days',
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExpiryCard(
                'Critical',
                '12',
                'within 3 days',
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FIFO Picking Recommended',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pick older batches first to minimize waste',
                        style: TextStyle(fontSize: 10, color: AppTheme.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryCard(String label, String count, String subtitle, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PriceTrendPainter extends CustomPainter {
  final List<PriceHistory> priceHistory;

  PriceTrendPainter(this.priceHistory);

  @override
  void paint(Canvas canvas, Size size) {
    if (priceHistory.isEmpty) return;

    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;

    final minPrice = priceHistory.map((p) => p.price).reduce((a, b) => a < b ? a : b);
    final maxPrice = priceHistory.map((p) => p.price).reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    final padding = 20.0;
    final availableWidth = size.width - (2 * padding);
    final availableHeight = size.height - (2 * padding);

    List<Offset> points = [];

    for (int i = 0; i < priceHistory.length; i++) {
      final x = padding + (availableWidth / (priceHistory.length - 1)) * i;
      final normalizedPrice = (priceHistory[i].price - minPrice) / (priceRange == 0 ? 1 : priceRange);
      final y = padding + availableHeight - (normalizedPrice * availableHeight);
      points.add(Offset(x, y));
    }

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    for (final point in points) {
      canvas.drawCircle(point, 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(PriceTrendPainter oldDelegate) => false;
}

class Product {
  final String id;
  final String name;
  final double currentPrice;
  final String category;
  final String vendorId;
  final String vendorName;
  final double vendorRating;
  final int vendorReviews;
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.currentPrice,
    required this.category,
    required this.vendorId,
    required this.vendorName,
    required this.vendorRating,
    required this.vendorReviews,
    required this.imageUrl,
  });
}

class PriceHistory {
  final DateTime date;
  final double price;

  PriceHistory({required this.date, required this.price});
}

class BatchInfo {
  final String batchNumber;
  final String lotNumber;
  final DateTime manufacturingDate;
  final DateTime expiryDate;
  final int quantity;
  final String location;

  BatchInfo({
    required this.batchNumber,
    required this.lotNumber,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.quantity,
    required this.location,
  });
}
