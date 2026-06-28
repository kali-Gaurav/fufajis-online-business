import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

class ReviewsModerationScreen extends StatefulWidget {
  const ReviewsModerationScreen({super.key});

  @override
  State<ReviewsModerationScreen> createState() =>
      _ReviewsModerationScreenState();
}

class _ReviewsModerationScreenState extends State<ReviewsModerationScreen> {
  // State list of mock reviews
  late List<ProductReview> _reviews;
  String _searchQuery = '';
  String _selectedTab =
      'All'; // 'All', 'Low Ratings', 'Flagged', 'Pending Reply', 'Featured'

  // New state for multi-select
  final Set<String> _selectedReviewIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _initializeMockReviews();
  }

  void _initializeMockReviews() {
    _reviews = [
      ProductReview(
        id: 'rev_1',
        productId: 'prod_tomatoes',
        userId: 'u_101',
        userName: 'Ramesh Chaudhary',
        userImage:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100',
        rating: 2.0,
        review:
            'The tomatoes delivered were a bit squished and overripe. Delivery rider reached Bassi village very late today.',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ownerReply: null,
        isFlagged: false,
        isFeatured: false,
      ),
      ProductReview(
        id: 'rev_2',
        productId: 'prod_potatoes',
        userId: 'u_102',
        userName: 'Kamla Devi',
        userImage:
            'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100',
        rating: 5.0,
        review:
            'आलू बहुत अच्छे और ताज़ा हैं! हमारे गांव में इतनी अच्छी सर्विस पहली बार मिली है। बहुत-बहुत धन्यवाद।',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ownerReply:
            'बहुत धन्यवाद कमला जी, हम हमेशा आपके लिए ताज़ा सब्ज़ियां लाते रहेंगे!',
        isFlagged: false,
        isFeatured: true,
      ),
      ProductReview(
        id: 'rev_3',
        productId: 'prod_mango',
        userId: 'u_103',
        userName: 'Mahendra Singh',
        userImage:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100',
        rating: 4.0,
        review:
            'Alphonso Mangoes are delicious and sweet. One or two mangoes were small but overall great quality.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ownerReply: null,
        isFlagged: false,
        isFeatured: false,
      ),
      ProductReview(
        id: 'rev_4',
        productId: 'prod_onions',
        userId: 'u_104',
        userName: 'Suresh Gurjar',
        userImage:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
        rating: 1.0,
        review:
            'The onions had a foul smell and black spots inside. Unusable in my Dhaba. Extremely disappointed.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ownerReply: null,
        isFlagged: true,
        isFeatured: false,
      ),
      ProductReview(
        id: 'rev_5',
        productId: 'prod_milk',
        userId: 'u_105',
        userName: 'Vikram Yadav',
        userImage:
            'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=100',
        rating: 5.0,
        review:
            'Full cream milk delivered chilled before 7 AM at Chomu outskirts. Outstanding service consistency!',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        ownerReply:
            'Thank you Vikram! Glad we met your morning timing expectations.',
        isFlagged: false,
        isFeatured: true,
      ),
      ProductReview(
        id: 'rev_6',
        productId: 'prod_atta',
        userId: 'u_106',
        userName: 'Rajesh Meena',
        userImage:
            'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=100',
        rating: 3.0,
        review:
            'Atta packing was slightly torn, flour was spilling inside the bag. Please look into logistics.',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ownerReply: null,
        isFlagged: false,
        isFeatured: false,
      ),
    ];
  }

  // AI Insights Generation (Mocked for automation)
  Map<String, dynamic> _getAIInsights() {
    return {
      'sentiment': 'Mostly Positive (78%)',
      'main_praise': 'Product freshness and community-focused service.',
      'main_complaint':
          'Delivery delays in Bassi village and packaging durability.',
      'action_item':
          'Check Bassi delivery route & replace paper bags for Atta.',
      'urgent_alerts': _reviews
          .where((r) => r.rating <= 2 && !r.isFlagged)
          .length,
    };
  }

  // Get product names dynamically for mock UI
  String _getProductName(String productId) {
    switch (productId) {
      case 'prod_tomatoes':
        return 'Fresh Tomatoes (टमाटर)';
      case 'prod_potatoes':
        return 'Fresh Potatoes (आलू)';
      case 'prod_mango':
        return 'Mango Alphonso (आम)';
      case 'prod_onions':
        return 'Fresh Onions (प्याज़)';
      case 'prod_milk':
        return 'Full Cream Milk (दूध)';
      case 'prod_atta':
        return 'Aashirvaad Atta (आटा)';
      default:
        return 'Fresh Grocery Item';
    }
  }

  // Calculate statistics
  double get _avgRating {
    if (_reviews.isEmpty) return 0.0;
    return _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        _reviews.length;
  }

  int get _totalReviews => _reviews.length;
  int get _flaggedCount => _reviews.where((r) => r.isFlagged).length;
  int get _pendingReplyCount =>
      _reviews.where((r) => r.ownerReply == null).length;

  int _ratingCount(double val) =>
      _reviews.where((r) => r.rating.roundToDouble() == val).length;

  // Bulk action handlers
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedReviewIds.contains(id)) {
        _selectedReviewIds.remove(id);
      } else {
        _selectedReviewIds.add(id);
      }
      _isSelectionMode = _selectedReviewIds.isNotEmpty;
    });
  }

  void _bulkFlag() {
    setState(() {
      for (var id in _selectedReviewIds) {
        final index = _reviews.indexWhere((r) => r.id == id);
        if (index != -1) {
          final current = _reviews[index];
          _reviews[index] = ProductReview(
            id: current.id,
            productId: current.productId,
            userId: current.userId,
            userName: current.userName,
            userImage: current.userImage,
            rating: current.rating,
            review: current.review,
            createdAt: current.createdAt,
            ownerReply: current.ownerReply,
            isFlagged: true,
            isFeatured: current.isFeatured,
          );
        }
      }
      _selectedReviewIds.clear();
      _isSelectionMode = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Selected reviews flagged.')));
  }

  void _bulkFeature() {
    setState(() {
      for (var id in _selectedReviewIds) {
        final index = _reviews.indexWhere((r) => r.id == id);
        if (index != -1) {
          final current = _reviews[index];
          _reviews[index] = ProductReview(
            id: current.id,
            productId: current.productId,
            userId: current.userId,
            userName: current.userName,
            userImage: current.userImage,
            rating: current.rating,
            review: current.review,
            createdAt: current.createdAt,
            ownerReply: current.ownerReply,
            isFlagged: current.isFlagged,
            isFeatured: true,
          );
        }
      }
      _selectedReviewIds.clear();
      _isSelectionMode = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Selected reviews featured.')));
  }

  // Handler to toggle Flagged state
  void _toggleFlag(String reviewId) {
    setState(() {
      final index = _reviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        final current = _reviews[index];
        _reviews[index] = ProductReview(
          id: current.id,
          productId: current.productId,
          userId: current.userId,
          userName: current.userName,
          userImage: current.userImage,
          rating: current.rating,
          review: current.review,
          createdAt: current.createdAt,
          ownerReply: current.ownerReply,
          isFlagged: !current.isFlagged,
          isFeatured: current.isFeatured,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryColor,
            content: Text(
              _reviews[index].isFlagged
                  ? 'Review by ${current.userName} flagged/hidden from product details.'
                  : 'Review by ${current.userName} unflagged.',
            ),
          ),
        );
      }
    });
  }

  // Handler to toggle Pinned/Featured state
  void _toggleFeature(String reviewId) {
    setState(() {
      final index = _reviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        final current = _reviews[index];
        _reviews[index] = ProductReview(
          id: current.id,
          productId: current.productId,
          userId: current.userId,
          userName: current.userName,
          userImage: current.userImage,
          rating: current.rating,
          review: current.review,
          createdAt: current.createdAt,
          ownerReply: current.ownerReply,
          isFlagged: current.isFlagged,
          isFeatured: !current.isFeatured,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.warning,
            content: Text(
              _reviews[index].isFeatured
                  ? 'Review highlighted as featured feedback!'
                  : 'Review removed from featured list.',
            ),
          ),
        );
      }
    });
  }

  // Handler to reply to a review
  void _submitReply(String reviewId, String replyText) {
    if (replyText.trim().isEmpty) return;
    setState(() {
      final index = _reviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        final current = _reviews[index];
        _reviews[index] = ProductReview(
          id: current.id,
          productId: current.productId,
          userId: current.userId,
          userName: current.userName,
          userImage: current.userImage,
          rating: current.rating,
          review: current.review,
          createdAt: current.createdAt,
          ownerReply: replyText,
          isFlagged: current.isFlagged,
          isFeatured: current.isFeatured,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(
              'Reply submitted successfully to ${current.userName}.',
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // Filter reviews
    final filteredReviews = _reviews.where((r) {
      // Filter by Search Query
      final matchQuery =
          r.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.review.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          _getProductName(
            r.productId,
          ).toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchQuery) return false;

      // Filter by Tab
      switch (_selectedTab) {
        case 'Low Ratings':
          return r.rating <= 3.0;
        case 'Flagged':
          return r.isFlagged;
        case 'Pending Reply':
          return r.ownerReply == null;
        case 'Featured':
          return r.isFeatured;
        case 'All':
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side list/details
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSelectionMode)
                    _buildSelectionToolbar()
                  else
                    _buildHeader(),
                  const SizedBox(height: 24),
                  _buildAIInsightsCard(),
                  const SizedBox(height: 24),
                  _buildFilterTabs(),
                  const SizedBox(height: 16),
                  _buildSearchAndResultsCount(filteredReviews.length),
                  const SizedBox(height: 16),
                  if (filteredReviews.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredReviews.length,
                      itemBuilder: (context, index) {
                        return _buildReviewCard(filteredReviews[index]);
                      },
                    ),
                ],
              ),
            ),
          ),

          // Right side analytics panel
          Expanded(
            flex: 1,
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Colors.grey[200]!)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rating Distribution',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDistributionCharts(),
                    const Divider(height: 48),
                    _buildModerationGuidelinesCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() {
              _selectedReviewIds.clear();
              _isSelectionMode = false;
            }),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Text(
            '${_selectedReviewIds.length} Selected',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _bulkFeature,
            icon: const Icon(Icons.star, color: Colors.white, size: 18),
            label: const Text(
              'Feature All',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton.icon(
            onPressed: _bulkFlag,
            icon: const Icon(Icons.flag, color: Colors.white, size: 18),
            label: const Text(
              'Flag All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightsCard() {
    final insights = _getAIInsights();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.ownerAccent, AppTheme.ownerAccent.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ownerAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.warning, size: 24),
              const SizedBox(width: 12),
              const Text(
                'AI Smart Insights for Fufaji',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              if (insights['urgent_alerts'] > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${insights['urgent_alerts']} URGENT ALERTS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInsightItem(
                  Icons.mood,
                  'Sentiment',
                  insights['sentiment'],
                ),
              ),
              Expanded(
                child: _buildInsightItem(
                  Icons.recommend,
                  'Top Praise',
                  insights['main_praise'],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppTheme.warning,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Suggestion: ${insights['action_item']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.ownerAccent,
                      content: Text(
                        'AI Optimization Applied: Rerouting Bassi deliveries and updated packaging requirements for Atta.',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Apply Fix', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Review Moderation',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                Text(
                  'Review ratings, reply to rural users, and manage storefront visibility.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            _buildQuickStatsBadge(),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStatsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppTheme.warning, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_avgRating.toStringAsFixed(1)} / 5.0',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              Text(
                '$_totalReviews Total Reviews',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final List<Map<String, dynamic>> tabs = [
      {
        'name': 'All',
        'icon': Icons.rate_review_outlined,
        'count': _reviews.length,
      },
      {
        'name': 'Low Ratings',
        'icon': Icons.thumb_down_alt_outlined,
        'count': _reviews.where((r) => r.rating <= 3.0).length,
      },
      {
        'name': 'Pending Reply',
        'icon': Icons.reply_all_outlined,
        'count': _pendingReplyCount,
      },
      {'name': 'Flagged', 'icon': Icons.flag_outlined, 'count': _flaggedCount},
      {
        'name': 'Featured',
        'icon': Icons.star_outline_rounded,
        'count': _reviews.where((r) => r.isFeatured).length,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab['name'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                tab['icon'],
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              label: Text('${tab['name']} (${tab['count']})'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedTab = tab['name'];
                });
              },
              selectedColor: AppTheme.primaryColor,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: AppTheme.cream,
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey[300]!,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchAndResultsCount(int resultsCount) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search customer name, product, or review text...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[400],
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Showing $resultsCount reviews',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.rate_review_rounded,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No Reviews Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try changing filters or search terms.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(ProductReview review) {
    final String prodName = _getProductName(review.productId);
    final isLowRating = review.rating <= 3.0;
    final isSelected = _selectedReviewIds.contains(review.id);

    return InkWell(
      onLongPress: () => _toggleSelection(review.id),
      onTap: _isSelectionMode ? () => _toggleSelection(review.id) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : review.isFeatured
                ? AppTheme.warning.withValues(alpha: 0.5)
                : review.isFlagged
                ? AppTheme.error.withValues(alpha: 0.3)
                : Colors.grey[200]!,
            width: isSelected || review.isFeatured || review.isFlagged
                ? 1.5
                : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner tags if featured or flagged
            if (review.isFeatured || review.isFlagged)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: review.isFeatured ? AppTheme.warning : AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      review.isFeatured
                          ? Icons.star_rounded
                          : Icons.warning_amber_rounded,
                      size: 16,
                      color: review.isFeatured
                          ? AppTheme.warning
                          : AppTheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      review.isFeatured
                          ? 'FEATURED / HIGHLIGHTED REVIEW'
                          : 'FLAGGED / HIDDEN FROM STOREFRONT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: review.isFeatured
                            ? AppTheme.warning
                            : AppTheme.error,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top user info and actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isSelectionMode)
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(review.id),
                          activeColor: AppTheme.primaryColor,
                        ),
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(review.userImage ?? ''),
                        backgroundColor: Colors.grey[200],
                        child: review.userImage == null
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  review.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildVerifiedBadge(),
                                const SizedBox(width: 8),
                                _buildRatingStars(review.rating),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getUserVillage(review.userName),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•   ${_formatDate(review.createdAt)}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildModerationMenu(review),
                    ],
                  ),
                  const Divider(height: 24),

                  // Product link info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_basket_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Product Reviewed: ',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          prodName,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Review Text
                  Text(
                    review.review,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Colors.grey[800],
                      fontStyle: isLowRating
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),

                  // Owner Reply Bubble or Action Box
                  const SizedBox(height: 16),
                  if (review.ownerReply != null)
                    _buildReplyBubble(review.ownerReply!)
                  else
                    _buildReplyComposer(review.id, isLowRating),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.ownerAccent.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified, size: 10, color: AppTheme.info),
          SizedBox(width: 3),
          Text(
            'VERIFIED',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: AppTheme.ownerAccent,
            ),
          ),
        ],
      ),
    );
  }

  String _getUserVillage(String name) {
    if (name.contains('Chaudhary')) return 'Bassi Village, Jaipur';
    if (name.contains('Kamla')) return 'Chomu Village, Jaipur';
    if (name.contains('Singh')) return 'Govindgarh, Jaipur';
    if (name.contains('Gurjar')) return 'Sanganer Outskirts, Jaipur';
    if (name.contains('Yadav')) return 'Shahpura, Jaipur';
    return 'Rural District, Jaipur';
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return Icon(
          starValue <= rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: starValue <= rating ? AppTheme.warning : Colors.grey[300],
          size: 18,
        );
      }),
    );
  }

  Widget _buildModerationMenu(ProductReview review) {
    return Row(
      children: [
        IconButton(
          tooltip: review.isFeatured ? 'Unpin' : 'Highlight review',
          onPressed: () => _toggleFeature(review.id),
          icon: Icon(
            review.isFeatured ? Icons.star_rounded : Icons.star_border_rounded,
            color: review.isFeatured ? AppTheme.warning : Colors.grey[400],
            size: 22,
          ),
        ),
        IconButton(
          tooltip: review.isFlagged ? 'Unflag Review' : 'Flag / Hide Review',
          onPressed: () => _toggleFlag(review.id),
          icon: Icon(
            review.isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
            color: review.isFlagged ? AppTheme.error : Colors.grey[400],
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildReplyBubble(String replyText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront, size: 14, color: AppTheme.success),
              SizedBox(width: 6),
              Text(
                'Owner Response',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            replyText,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.success),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyComposer(String reviewId, bool isLowRating) {
    final controller = TextEditingController();
    final suggestions = isLowRating
        ? [
            'हम असुविधा के लिए खेद है, हम सुधार करेंगे।',
            'We are looking into this quality issue.',
          ]
        : [
            'बहुत धन्यवाद! आपके सहयोग के लिए आभार।',
            'Thank you for your kind words!',
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: suggestions
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 10)),
                      onPressed: () => _submitReply(reviewId, s),
                      backgroundColor: AppTheme.cream,
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.mic_none,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Type or speak response...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    _submitReply(reviewId, controller.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Reply',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionCharts() {
    final stars = [5.0, 4.0, 3.0, 2.0, 1.0];
    return Column(
      children: stars.map((star) {
        final count = _ratingCount(star);
        final pct = _totalReviews == 0 ? 0.0 : (count / _totalReviews);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${star.toInt()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppTheme.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.grey[150],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      star >= 4.0
                          ? AppTheme.success
                          : star == 3.0
                          ? AppTheme.warning
                          : AppTheme.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 36,
                child: Text(
                  '${(pct * 100).toInt()}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModerationGuidelinesCard() {
    return Card(
      elevation: 0,
      color: AppTheme.info.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.ownerAccent.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel, color: AppTheme.ownerAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Moderation Policy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.ownerAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildGuidelineItem(
              'Flag reviews containing offensive language or spam to hide them.',
            ),
            _buildGuidelineItem(
              'Highlight detailed positive feedback to pin them at the top of the app.',
            ),
            _buildGuidelineItem(
              'Be polite when responding to negative reviews; offer swift resolutions.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppTheme.ownerAccent, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppTheme.ownerAccent,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mins ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }
}
