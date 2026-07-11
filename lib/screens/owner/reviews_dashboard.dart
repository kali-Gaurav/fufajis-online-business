import 'package:flutter/material.dart';
import '../../models/product_review_model.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

class ReviewsDashboard extends StatefulWidget {
  final List<ProductReviewModel> reviews;
  final List<ProductModel> products;

  const ReviewsDashboard({
    super.key,
    required this.reviews,
    required this.products,
  });

  @override
  State<ReviewsDashboard> createState() => _ReviewsDashboardState();
}

class _ReviewsDashboardState extends State<ReviewsDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Filters
  String _selectedDateRange = 'all';
  String _selectedProduct = 'all';
  String _selectedRating = 'all';
  String _selectedIssue = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ProductReviewModel> _getFilteredReviews() {
    List<ProductReviewModel> filtered = List.from(widget.reviews);

    // Date filter
    if (_selectedDateRange == '7d') {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      filtered =
          filtered.where((r) => r.createdAt.isAfter(sevenDaysAgo)).toList();
    } else if (_selectedDateRange == '30d') {
      final thirtyDaysAgo =
          DateTime.now().subtract(const Duration(days: 30));
      filtered =
          filtered.where((r) => r.createdAt.isAfter(thirtyDaysAgo)).toList();
    }

    // Product filter
    if (_selectedProduct != 'all') {
      filtered = filtered.where((r) => r.productId == _selectedProduct).toList();
    }

    // Rating filter
    if (_selectedRating != 'all') {
      if (_selectedRating == '5') {
        filtered = filtered.where((r) => r.rating == 5).toList();
      } else if (_selectedRating == '4') {
        filtered = filtered.where((r) => r.rating == 4).toList();
      } else if (_selectedRating == '3') {
        filtered = filtered.where((r) => r.rating == 3).toList();
      } else if (_selectedRating == '1-2') {
        filtered = filtered.where((r) => r.rating <= 2).toList();
      }
    }

    // Issue filter
    if (_selectedIssue != 'all') {
      filtered = filtered.where((r) => r.tags.contains(_selectedIssue)).toList();
    }

    return filtered;
  }

  Map<String, dynamic> _getProductStats(String productId) {
    final productReviews =
        widget.reviews.where((r) => r.productId == productId).toList();
    if (productReviews.isEmpty) {
      return {'avgRating': 0.0, 'count': 0, 'trend': '→'};
    }

    final avgRating =
        productReviews.map((r) => r.rating).reduce((a, b) => a + b) /
            productReviews.length;
    return {
      'avgRating': avgRating,
      'count': productReviews.length,
      'trend': '→',
    };
  }

  double _getOverallAvgRating() {
    if (widget.reviews.isEmpty) return 0.0;
    final sum = widget.reviews.map((r) => r.rating).reduce((a, b) => a + b);
    return sum / widget.reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Reviews'),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(),
                _buildIssuesTab(),
                _buildTrendsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FILTERS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    'Date Range',
                    _selectedDateRange,
                    ['all', '7d', '30d'],
                    ['All time', 'Last 7 days', 'Last 30 days'],
                    (value) => setState(() => _selectedDateRange = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown(
                    'Rating',
                    _selectedRating,
                    ['all', '5', '4', '1-2'],
                    ['All', '5 stars', '4 stars', '1-2 stars'],
                    (value) => setState(() => _selectedRating = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    'Product',
                    _selectedProduct,
                    ['all'] +
                        widget.products.map((p) => p.id).toList(),
                    ['All Products'] +
                        widget.products.map((p) => p.name).toList(),
                    (value) => setState(() => _selectedProduct = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown(
                    'Issues',
                    _selectedIssue,
                    ['all', 'quality', 'freshness', 'packaging', 'damage'],
                    ['All Issues', 'Quality', 'Freshness', 'Packaging', 'Damage'],
                    (value) => setState(() => _selectedIssue = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.grey600,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Products'),
                Tab(text: 'Issues'),
                Tab(text: 'Trends'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String selectedValue,
    List<String> values,
    List<String> labels,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
        ),
        const SizedBox(height: 6),
        DropdownButton<String>(
          value: selectedValue,
          onChanged: (value) => onChanged(value ?? selectedValue),
          items: List.generate(
            values.length,
            (index) => DropdownMenuItem(
              value: values[index],
              child: Text(labels[index], style: const TextStyle(fontSize: 12)),
            ),
          ),
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildProductsTab() {
    final filtered = _getFilteredReviews();
    final productIds = widget.products.map((p) => p.id).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avg Rating: ⭐${_getOverallAvgRating().toStringAsFixed(1)}/5.0',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(widget.products.length, (index) {
            final product = widget.products[index];
            final stats = _getProductStats(product.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  border: Border.all(color: AppTheme.grey200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID: #${product.id.substring(0, 8)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.grey600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${stats['avgRating'].toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stats['count']} reviews',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildIssuesTab() {
    final flaggedReviews = _getFilteredReviews()
        .where((r) => r.isFlagged || r.rating <= 2)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: flaggedReviews.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No quality issues found!',
                  style: TextStyle(color: AppTheme.grey600),
                ),
              ),
            )
          : Column(
              children: flaggedReviews.map((review) {
                final product = widget.products
                    .firstWhere((p) => p.id == review.productId);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: review.rating <= 2
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFFFF3E0),
                      border: Border.all(
                        color: review.rating <= 2
                            ? AppTheme.error
                            : AppTheme.warning,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_rounded,
                                color: review.rating <= 2
                                    ? AppTheme.error
                                    : AppTheme.warning,
                                size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${product.name} - ${review.rating} stars',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'ID: #${review.productId.substring(0, 8)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.grey600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (review.reviewText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              review.reviewText!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.grey700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTrendsTab() {
    final avgRating = _getOverallAvgRating();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Rating',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '⭐${avgRating.toStringAsFixed(1)}/5.0',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on ${widget.reviews.length} reviews',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Key Insights:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            'Total Reviews',
            '${widget.reviews.length}',
            Icons.assessment,
          ),
          const SizedBox(height: 8),
          _buildInsightCard(
            '5-Star Reviews',
            '${widget.reviews.where((r) => r.rating == 5).length}',
            Icons.star,
          ),
          const SizedBox(height: 8),
          _buildInsightCard(
            'Quality Issues',
            '${widget.reviews.where((r) => r.rating <= 2).length}',
            Icons.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.grey600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
