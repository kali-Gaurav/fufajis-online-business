import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/product_model.dart';
import '../../models/product_review_model.dart';
import '../../services/product_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/qna_section.dart';
import '../../widgets/group_buy_widget.dart';
import '../../widgets/farm_map_widget.dart';
import '../../widgets/price_trust_widgets.dart';
import '../../widgets/animated_widgets.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  int _quantity = 1;
  bool _isLoading = true;
  ProductModel? _product;
  ProductUnitOption? _selectedUnitOption;
  final ProductService _productService = ProductService();
  StreamSubscription<List<ProductReviewModel>>? _reviewsSubscription;
  List<ProductReviewModel> _reviews = [];

  // Image carousel state
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;

  // Cart feedback
  final GlobalKey<ParticlesBurstState> _addToCartKey = GlobalKey();
  bool _addedToCart = false;

  // Quantity step animation
  late AnimationController _qtyController;
  late Animation<double> _qtyAnim;

  @override
  void initState() {
    super.initState();
    _loadProduct();
    _qtyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _qtyAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _qtyController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _reviewsSubscription?.cancel();
    _imagePageController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _loadProduct() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final prod = productProvider.getProductById(widget.productId);
    if (prod != null) {
      _product = prod;
      productProvider.addToRecentlyViewed(prod.id);
      if (prod.unitOptions.isNotEmpty) {
        _selectedUnitOption = prod.unitOptions.first;
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
    _listenToReviews();
  }

  void _listenToReviews() {
    _reviewsSubscription?.cancel();
    _reviewsSubscription = _productService
        .getProductReviewsStream(widget.productId)
        .listen(
          (reviews) {
            if (mounted) setState(() => _reviews = reviews);
          },
          onError: (_) {
            if (mounted) setState(() => _reviews = []);
          },
        );
  }

  void _bumpQty() {
    _qtyController.forward(from: 0).then((_) => _qtyController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
        body: const SingleChildScrollView(
          child: Column(
            children: [
              ShimmerBox(width: double.infinity, height: 320, radius: 0),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 260, height: 22),
                    SizedBox(height: 10),
                    ShimmerBox(width: 140, height: 16),
                    SizedBox(height: 16),
                    ShimmerBox(width: 100, height: 28),
                    SizedBox(height: 24),
                    ShimmerBox(width: double.infinity, height: 100, radius: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_product == null) return _buildNotFound();

    final productProvider = Provider.of<ProductProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final variantKey = _selectedUnitOption?.name;
    final cartQuantity =
        cartProvider.getQuantityForVariant(widget.productId, variantKey);
    final isInCart = cartQuantity > 0;
    final isFavorite = productProvider.isInWishlist(widget.productId);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isFavorite, productProvider, isDark),
      body: _buildProductContent(cartProvider, isInCart, cartQuantity, isDark),
      bottomNavigationBar:
          _buildBottomBar(cartProvider, isInCart, cartQuantity),
    );
  }

  PreferredSizeWidget _buildAppBar(
    bool isFavorite,
    ProductProvider productProvider,
    bool isDark,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.grey900, size: 20),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () {
            final shareText =
                'Check out ${_product!.name} on Fufaji\'s Online!\n'
                'Price: ₹${(_product!.isLightningDealActive ? _product!.lightningDealPrice : _product!.price.toDouble())?.round()}\n'
                'Link: https://fufajis.online/product/${widget.productId}';
            Share.share(shareText);
          },
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.share_rounded,
                color: AppTheme.grey900, size: 18),
          ),
        ),
        GestureDetector(
          onTap: () => productProvider.toggleWishlist(widget.productId),
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
              ],
            ),
            child: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFavorite ? AppTheme.error : AppTheme.grey900,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotFound() {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2, size: 80, color: AppTheme.grey400),
            const SizedBox(height: 16),
            const Text('Product not found', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductContent(
    CartProvider cartProvider,
    bool isInCart,
    int quantity,
    bool isDark,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailLightningBanner(product: _product!),
          _buildProductImages(isDark),
          const SizedBox(height: 16),
          SpringCard(
            delay: const Duration(milliseconds: 60),
            child: _buildProductInfo(isDark),
          ),
          const SizedBox(height: 10),
          SpringCard(
            delay: const Duration(milliseconds: 110),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HonestPriceBadges(
                hasNoDiscount: _product!.originalPrice == null ||
                    _product!.originalPrice == _product!.price,
                isLocallySourced:
                    _product!.shopName.toLowerCase().contains('fufaji'),
                priceStableFor60Days: false,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SpringCard(
            delay: const Duration(milliseconds: 160),
            child: PriceHistoryWidget(
              productId: widget.productId,
              currentPrice: _product!.price.toDouble(),
            ),
          ),
          const SizedBox(height: 16),
          if (_product!.unitOptions.isNotEmpty) ...[
            SpringCard(
              delay: const Duration(milliseconds: 200),
              child: _buildUnitOptionsSelector(isDark),
            ),
            const SizedBox(height: 16),
          ],
          SpringCard(
            delay: const Duration(milliseconds: 240),
            child: _buildQuantitySelector(isDark),
          ),
          const SizedBox(height: 16),
          SpringCard(
            delay: const Duration(milliseconds: 280),
            child: GroupBuyWidget(product: _product!),
          ),
          const SizedBox(height: 16),
          SpringCard(
            delay: const Duration(milliseconds: 320),
            child: FarmMapWidget(product: _product!),
          ),
          const SizedBox(height: 16),
          SpringCard(
            delay: const Duration(milliseconds: 360),
            child: _buildDeliveryInfo(),
          ),
          const SizedBox(height: 16),
          if (_product!.specifications.isNotEmpty)
            SpringCard(
              delay: const Duration(milliseconds: 400),
              child: _buildSpecifications(isDark),
            ),
          const SizedBox(height: 16),
          SpringCard(
            delay: const Duration(milliseconds: 440),
            child: _buildReviewsSection(isDark),
          ),
          const SizedBox(height: 16),
          SpringCard(
            delay: const Duration(milliseconds: 480),
            child: QnaSection(productId: widget.productId),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildProductImages(bool isDark) {
    final images = _product!.images.isNotEmpty
        ? _product!.images
        : [_product!.imageUrl];

    return Stack(
      children: [
        Container(
          height: 300,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: PageView.builder(
            controller: _imagePageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) {
              final imgUrl = images[index].toString();
              return imgUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.image_not_supported,
                            size: 80, color: AppTheme.grey300),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.image, size: 80, color: AppTheme.grey300),
                    );
            },
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final isActive = i == _currentImageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildProductInfo(bool isDark) {
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final double displayPrice = _selectedUnitOption != null
        ? _selectedUnitOption!.price.toDouble()
        : (_product!.isLightningDealActive
            ? (_product!.lightningDealPrice ?? 0.0)
            : _product!.price.toDouble());
    final double? originalPrice = _selectedUnitOption != null
        ? _selectedUnitOption!.originalPrice
        : _product!.originalPrice?.toDouble();
    final String unit = _selectedUnitOption != null
        ? _selectedUnitOption!.name
        : _product!.unit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _product!.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _product!.shopName,
            style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${displayPrice.round()}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              if (originalPrice != null && originalPrice > displayPrice) ...[
                const SizedBox(width: 12),
                Text(
                  '₹${originalPrice.round()}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(((originalPrice - displayPrice) / originalPrice) * 100).round()}% OFF',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (_product!.normalizedPricePerKg != null)
            Text(
              '(₹${_product!.normalizedPricePerKg!.toStringAsFixed(0)} / kg equivalent)',
              style: const TextStyle(
                color: AppTheme.grey500,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          Text(
            'Price per $unit',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOptionsSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Select Option',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : AppTheme.grey900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _product!.unitOptions.length,
            itemBuilder: (context, index) {
              final opt = _product!.unitOptions[index];
              final isSel = _selectedUnitOption?.id == opt.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedUnitOption = opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppTheme.primary.withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
                    border: Border.all(
                      color: isSel ? AppTheme.primary : AppTheme.grey300,
                      width: isSel ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      opt.name,
                      style: TextStyle(
                        color: isSel
                            ? AppTheme.primary
                            : (isDark ? Colors.white : Colors.black),
                        fontWeight:
                            isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Quantity',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : AppTheme.grey900,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _quantity > 1
                ? () {
                    _bumpQty();
                    setState(() => _quantity--);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _quantity > 1
                    ? AppTheme.primary.withValues(alpha: 0.1)
                    : AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.remove,
                color: _quantity > 1 ? AppTheme.primary : AppTheme.grey400,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ScaleTransition(
            scale: _qtyAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_quantity',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              _bumpQty();
              setState(() => _quantity++);
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: AppTheme.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Express Delivery Available',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 2),
              Text(
                'Delivered within 2–4 hours',
                style: TextStyle(color: AppTheme.grey600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecifications(bool isDark) {
    if (_product!.specifications.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Specifications',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.white : AppTheme.grey900,
              ),
            ),
          ),
          const Divider(height: 1),
          ..._product!.specifications.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    e.value.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

  Widget _buildReviewsSection(bool isDark) {
    final avg = _reviews.isEmpty
        ? 0.0
        : _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            _reviews.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Customer Reviews',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppTheme.grey900,
                ),
              ),
              const Spacer(),
              if (_reviews.isNotEmpty)
                Text(
                  '${_reviews.length} reviews',
                  style: const TextStyle(
                    color: AppTheme.grey500,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < avg.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'out of 5',
                      style: TextStyle(color: AppTheme.grey500, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._reviews.take(2).map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            r.userName.isNotEmpty
                                ? r.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          r.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < r.rating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (r.comment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        r.comment,
                        style: const TextStyle(
                          color: AppTheme.grey700,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ScaleBounce(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final name =
                          Uri.encodeComponent(_product?.name ?? '');
                      context.push(
                          '/customer/add-review/${widget.productId}?name=$name');
                    },
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: const Text('Write a Review'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(CartProvider cart, bool isInCart, int qty) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ParticlesBurst(key: _addToCartKey),
                ScaleBounce(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 52,
                    decoration: BoxDecoration(
                      color: _addedToCart
                          ? AppTheme.success.withValues(alpha: 0.12)
                          : Colors.white,
                      border: Border.all(
                        color:
                            _addedToCart ? AppTheme.success : AppTheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _addedToCart
                            ? null
                            : () {
                                cart.addToCart(_product!,
                                    quantity: _quantity,
                                    selectedUnit: _selectedUnitOption);
                                _addToCartKey.currentState?.trigger();
                                setState(() => _addedToCart = true);
                                Future.delayed(const Duration(seconds: 2), () {
                                  if (mounted) {
                                    setState(() => _addedToCart = false);
                                  }
                                });
                              },
                        child: Center(
                          child: Text(
                            _addedToCart ? 'ADDED! ✓' : 'ADD TO CART',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _addedToCart
                                  ? AppTheme.success
                                  : AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ScaleBounce(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary,
                      AppTheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      cart.addToCart(_product!,
                          quantity: _quantity,
                          selectedUnit: _selectedUnitOption);
                      context.push('/customer/checkout');
                    },
                    child: const Center(
                      child: Text(
                        'BUY NOW',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailLightningBanner extends StatefulWidget {
  final ProductModel product;
  const DetailLightningBanner({super.key, required this.product});

  @override
  State<DetailLightningBanner> createState() => _DetailLightningBannerState();
}

class _DetailLightningBannerState extends State<DetailLightningBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.product.isLightningDealActive) return const SizedBox.shrink();
    final remaining =
        widget.product.lightningDealEndTime?.difference(DateTime.now()) ??
            Duration.zero;
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE53E3E), Color(0xFFDD6B20)],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: Colors.yellow, size: 20),
          const SizedBox(width: 8),
          const Text(
            'LIGHTNING DEAL',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$h:$m:$s',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
