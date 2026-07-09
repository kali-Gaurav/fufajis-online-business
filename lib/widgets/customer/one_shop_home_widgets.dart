// ============================================================================
//  Fufaji's Online — One-Shop Home Widgets (Agent 3: Home Composition)
//
//  This file provides the new premium section widgets for the Home Screen.
//  The HomeScreen composes these; this file does NOT build any product widgets.
//
//  Ownership: Agent 3 (Home Composition)
//  Rule: Compose existing widgets only. Do NOT edit fufaji_product_card.dart.
//
//  Widgets exported:
//  ✅ OneShopBannerCarousel
//  ✅ OwnerRecommendationSection (horizontal rail of FufajiProductCard)
//  ✅ WhatsAppOrderWidget
//  ✅ HomeOfflineBanner
//  ✅ HomeSkeletonLoader (shimmer for full home sections)
//  ✅ HomeSectionHeader (reusable title + "See All")
//  ✅ FeaturedCategoryGrid
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../screens/customer/search_screen.dart';
import 'fufaji_product_card.dart';

// ---------------------------------------------------------------------------
//  HomeSectionHeader
// ---------------------------------------------------------------------------
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? seeAllRoute;
  final VoidCallback? onSeeAll;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.seeAllRoute,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
          if (seeAllRoute != null || onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll ?? () => context.push(seeAllRoute!),
              child: const Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  OneShopBannerCarousel
// ---------------------------------------------------------------------------
class BannerItem {
  final String imageUrl;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final String? route;

  const BannerItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.backgroundColor = AppColors.primary,
    this.route,
  });
}

class OneShopBannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;
  final double height;

  const OneShopBannerCarousel({
    super.key,
    required this.banners,
    this.height = 160,
  });

  @override
  State<OneShopBannerCarousel> createState() => _OneShopBannerCarouselState();
}

class _OneShopBannerCarouselState extends State<OneShopBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final next = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (ctx, i) => _BannerCard(banner: widget.banners[i]),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _currentPage ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _currentPage ? AppColors.primary : AppColors.grey300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerItem banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${banner.title}. ${banner.subtitle}',
      button: banner.route != null,
      child: GestureDetector(
        onTap: banner.route != null ? () => context.push(banner.route!) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                banner.backgroundColor,
                Color.lerp(banner.backgroundColor, Colors.black, 0.25) ?? banner.backgroundColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: banner.backgroundColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background image (if provided)
              if (banner.imageUrl.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              // Gradient overlay for text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
              ),
              // Text content
              Positioned(
                left: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      banner.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // "Shop Now" chip
              if (banner.route != null)
                Positioned(
                  right: 16,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Shop Now →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  WhatsAppOrderWidget
// ---------------------------------------------------------------------------
class WhatsAppOrderWidget extends StatelessWidget {
  final String whatsappNumber;
  final String message;

  const WhatsAppOrderWidget({
    super.key,
    this.whatsappNumber = '919999999999', // replace with real number
    this.message = 'Hi Fufaji! I would like to place an order.',
  });

  Future<void> _openWhatsApp(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$whatsappNumber?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp. Please check installation.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Order on WhatsApp',
      button: true,
      child: GestureDetector(
        onTap: () => _openWhatsApp(context),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF25D366).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order on WhatsApp',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Chat with Fufaji directly • Fast & personal',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  HomeOfflineBanner
// ---------------------------------------------------------------------------
class HomeOfflineBanner extends StatelessWidget {
  const HomeOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: const [
          Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are offline. Showing cached content.',
              style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  OwnerRecommendationSection — horizontal scrolling product rail
// ---------------------------------------------------------------------------
class OwnerRecommendationSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<ProductModel> products;

  const OwnerRecommendationSection({
    super.key,
    required this.title,
    required this.products,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: title, subtitle: subtitle),
        SizedBox(
          height: 260,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final product = products[i];
              return SizedBox(
                width: 160,
                child: _RecommendationCardWrapper(product: product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendationCardWrapper extends StatefulWidget {
  final ProductModel product;
  const _RecommendationCardWrapper({required this.product});

  @override
  State<_RecommendationCardWrapper> createState() => _RecommendationCardWrapperState();
}

class _RecommendationCardWrapperState extends State<_RecommendationCardWrapper> {
  ProductUnitOption? _selectedVariant;

  int _getQty(CartProvider cp) {
    try {
      return cp.cartItems
          .firstWhere((i) =>
              i.productId == widget.product.id &&
              (i.selectedVariant ?? 'default') == (_selectedVariant?.id ?? 'default'))
          .quantity;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (ctx, cart, _) {
        final qty = _getQty(cart);
        return FufajiProductCard(
          product: widget.product,
          cartQuantity: qty,
          selectedVariant: _selectedVariant,
          onTap: () => context.push('/customer/product/${widget.product.id}'),
          onVariantSelected: widget.product.unitOptions.isNotEmpty
              ? (v) => setState(() => _selectedVariant = v)
              : null,
          onAdd: () => cart.addToCart(widget.product, selectedUnit: _selectedVariant),
          onIncrement: () {
            try {
              cart.incrementQuantity(widget.product.id, selectedVariant: _selectedVariant?.id);
            } catch (_) {
              cart.addToCart(widget.product, selectedUnit: _selectedVariant);
            }
          },
          onDecrement: () {
            try {
              cart.decrementQuantity(widget.product.id, selectedVariant: _selectedVariant?.id);
            } catch (_) {}
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  FeaturedCategoryGrid
// ---------------------------------------------------------------------------
class FeaturedCategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;

  const FeaturedCategoryGrid({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length.clamp(0, 10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          final bgColor = AppColors.categoryColors[cat.id] ?? AppColors.primary;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/customer/category/${cat.id}');
            },
            child: Semantics(
              label: cat.localizedName(locale),
              button: true,
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: bgColor.withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Text(cat.icon, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cat.localizedName(locale),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  HomeSkeletonLoader (full-page shimmer while content loads)
// ---------------------------------------------------------------------------
class HomeSkeletonLoader extends StatefulWidget {
  const HomeSkeletonLoader({super.key});

  @override
  State<HomeSkeletonLoader> createState() => _HomeSkeletonLoaderState();
}

class _HomeSkeletonLoaderState extends State<HomeSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, {double radius = 8}) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.shimmerBase, AppColors.shimmerHighlight, _ctrl.value),
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _box(double.infinity, 160, radius: 18),
          ),
          const SizedBox(height: 20),

          // Category grid skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (_) => _box(52, 52, radius: 26)),
            ),
          ),
          const SizedBox(height: 20),

          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _box(160, 20),
          ),
          const SizedBox(height: 12),

          // Product rail skeleton
          SizedBox(
            height: 240,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => SizedBox(
                width: 150,
                child: Column(
                  children: [
                    _box(150, 140, radius: 14),
                    const SizedBox(height: 8),
                    _box(120, 12),
                    const SizedBox(height: 6),
                    _box(80, 10),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [_box(50, 18), _box(60, 30, radius: 15)],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // WhatsApp widget skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _box(double.infinity, 68, radius: 16),
          ),
        ],
      ),
    );
  }
}
