import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../utils/app_theme.dart';

/// High-performance infinite-scroll product grid with:
/// - Firestore cursor-based pagination (20 items/page)
/// - Shimmer skeleton loading
/// - Pull-to-refresh
/// - Bounce animation on add-to-cart
/// - Category + search filtering
class InfiniteProductGrid extends StatefulWidget {
  final String? category;
  final String? searchQuery;
  final bool showFeaturedBadge;

  const InfiniteProductGrid({
    super.key,
    this.category,
    this.searchQuery,
    this.showFeaturedBadge = false,
  });

  @override
  State<InfiniteProductGrid> createState() => _InfiniteProductGridState();
}

class _InfiniteProductGridState extends State<InfiniteProductGrid> {
  static const int _pageSize = 20;

  final List<ProductModel> _products = [];
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(InfiniteProductGrid old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category || old.searchQuery != widget.searchQuery) {
      _reset();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _products.clear();
      _lastDoc = null;
      _hasMore = true;
      _error = null;
    });
    _fetchPage();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoading && _hasMore) _fetchPage();
    }
  }

  Future<void> _fetchPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (widget.category != null && widget.category!.isNotEmpty) {
        query = query.where('category', isEqualTo: widget.category);
      }

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();
      List<ProductModel> fetched = snapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id; // inject id into map
        return ProductModel.fromMap(data);
      }).toList();

      // Client-side search filter (Firestore full-text not supported natively)
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        final q = widget.searchQuery!.toLowerCase();
        fetched = fetched.where((p) {
          return p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.tags.any((t) => t.toLowerCase().contains(q));
        }).toList();
      }

      setState(() {
        _products.addAll(fetched);
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load products. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _products.clear();
      _lastDoc = null;
      _hasMore = true;
      _error = null;
    });
    await _fetchPage();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 52, color: AppTheme.grey400),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.grey600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isLoading && _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 52, color: AppTheme.grey300),
            const SizedBox(height: 12),
            Text(
              widget.searchQuery != null
                  ? 'No products found for "${widget.searchQuery}"'
                  : 'No products available yet',
              style: const TextStyle(color: AppTheme.grey500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _onRefresh,
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.55, // Lowered from 0.70 to prevent bottom overflow
        ),
        itemCount: _products.length + (_isLoading ? 4 : 0),
        itemBuilder: (context, index) {
          if (index >= _products.length) {
            return const _ShimmerProductCard();
          }
          return _ProductTile(
            product: _products[index],
            showFeaturedBadge: widget.showFeaturedBadge,
          );
        },
      ),
    );
  }
}

// ─── Product tile with bounce-add animation ───────────────────────────────────
class _ProductTile extends StatefulWidget {
  final ProductModel product;
  final bool showFeaturedBadge;
  const _ProductTile({required this.product, required this.showFeaturedBadge});

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _addToCart() async {
    await _bounce.reverse();
    await _bounce.forward();
    if (!mounted) return;
    context.read<CartProvider>().addItem(widget.product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('${widget.product.name} added to cart'),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.info,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final hasDiscount = p.originalPrice != null && p.originalPrice! > p.price;
    final discountPct = hasDiscount
        ? ((p.originalPrice!.toDouble() - p.price.toDouble()) / p.originalPrice!.toDouble() * 100)
              .round()
        : 0;
    final isOutOfStock = p.stockQuantity <= 0;

    return ScaleTransition(
      scale: _bounce,
      child: GestureDetector(
        onTap: () => context.push('/customer/product/${p.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image ──────────────────────────────────
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: _buildImage(p),
                  ),
                  if (hasDiscount)
                    Positioned(top: 6, left: 6, child: _badge('$discountPct% OFF', AppTheme.error)),
                  if (widget.showFeaturedBadge && p.isFeatured)
                    Positioned(top: 6, right: 6, child: _badge('⭐ BEST', const Color(0xFFFF6F00))),
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.48),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'OUT OF\nSTOCK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // ── Details ────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey900,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.unit.isNotEmpty)
                        Text(p.unit, style: const TextStyle(fontSize: 10, color: AppTheme.grey500)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${p.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                              if (hasDiscount)
                                Text(
                                  '₹${p.originalPrice!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    decoration: TextDecoration.lineThrough,
                                    color: AppTheme.grey400,
                                  ),
                                ),
                            ],
                          ),
                          if (!isOutOfStock)
                            GestureDetector(
                              onTap: _addToCart,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 18),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(ProductModel p) {
    if (p.imageUrl.isNotEmpty) {
      return Image.network(
        p.imageUrl,
        height: 115,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const _ShimmerBox(height: 115),
      );
    }
    return _imageFallback();
  }

  Widget _imageFallback() {
    return Container(
      height: 115,
      width: double.infinity,
      color: AppTheme.grey100,
      child: const Icon(Icons.shopping_bag_outlined, size: 44, color: AppTheme.grey300),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Shimmer skeleton ─────────────────────────────────────────────────────────
class _ShimmerProductCard extends StatelessWidget {
  const _ShimmerProductCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.grey200,
      highlightColor: const Color(0xFFF5F5F5),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 115,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 11, width: 90, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(height: 9, width: 55, color: Colors.white),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(height: 14, width: 44, color: Colors.white),
                      Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  const _ShimmerBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.grey200,
      highlightColor: AppTheme.grey100,
      child: Container(height: height, color: Colors.white),
    );
  }
}
