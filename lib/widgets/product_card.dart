import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product_model.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';

/// A product card widget used across customer-facing screens.
///
/// Shows product image, name, price/discount, rating, and add-to-cart button.
/// Renders an out-of-stock overlay when product.inStock is false.
/// Shows a countdown badge when a lightning deal is active.
class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initTimer();
  }

  void _initTimer() {
    final p = widget.product;
    if (p.isLightningDealActive && p.lightningDealEndTime != null) {
      _remaining = p.lightningDealEndTime!.difference(DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _remaining = p.lightningDealEndTime!.difference(DateTime.now());
          if (_remaining.isNegative) {
            _remaining = Duration.zero;
            _timer?.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final hasDiscount =
        product.originalPrice != null && product.originalPrice! > product.price;
    final discountPct = product.effectiveDiscount.round();
    final isLightning = product.isLightningDealActive;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadows,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Product Image ──
                AspectRatio(
                  aspectRatio: 1.0,
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppTheme.grey100,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.grey100,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: AppTheme.grey400,
                        size: 36,
                      ),
                    ),
                  ),
                ),

                // ── Product Details ──
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey900,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Unit
                      Text(
                        product.unit,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey500,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Prices
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCurrency(product.currentPrice),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.grey900,
                            ),
                          ),
                          if (hasDiscount || isLightning) ...[
                            const SizedBox(width: 4),
                            Text(
                              formatCurrency(product.mrp ?? product.originalPrice!),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.grey500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Rating
                      if (product.reviewCount > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppTheme.warning,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.grey700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '(${product.reviewCount})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.grey500,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 8),

                      // Add to Cart Button
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: product.inStock ? widget.onAddToCart : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: AppTheme.white,
                            disabledBackgroundColor: AppTheme.grey200,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Out of Stock Overlay ──
            if (!product.inStock)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.75),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.grey800.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Text(
                      'Out of Stock',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Discount Badge ──
            if (discountPct > 0 && product.inStock)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$discountPct% OFF',
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // ── Lightning Deal Badge ──
            if (isLightning && _remaining > Duration.zero)
              Positioned(
                top: discountPct > 0 ? 32 : 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt,
                        color: AppTheme.white,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _formatRemaining(_remaining),
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Organic Badge ──
            if (product.isOrganicCertified)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: AppTheme.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
