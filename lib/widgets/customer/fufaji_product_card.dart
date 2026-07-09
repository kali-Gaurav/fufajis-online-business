// ============================================================================
//  Fufaji's Online — Premium Product Card
//  Design System Foundation: Reusable product UI component
//
//  NOTE: This file re-exports from the canonical ProductCard in /lib/product_card.dart
//  All subcomponents are defined here for organization but use canonical ProductCard
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../models/product_model.dart';

// Re-export the canonical ProductCard class
export '../../product_card.dart' show ProductCard;

// Availability Status enum (kept here for backward compatibility)
enum ProductAvailability { available, lowStock, outOfStock }

ProductAvailability _resolveAvailability(ProductModel product) {
  if (!product.isAvailable || product.availableStock <= 0) {
    return ProductAvailability.outOfStock;
  }
  if (product.availableStock <= product.minimumStock) {
    return ProductAvailability.lowStock;
  }
  return ProductAvailability.available;
}

// ---------------------------------------------------------------------------
//  AvailabilityBadge
// ---------------------------------------------------------------------------
class AvailabilityBadge extends StatelessWidget {
  final ProductAvailability availability;
  const AvailabilityBadge({super.key, required this.availability});

  @override
  Widget build(BuildContext context) {
    if (availability == ProductAvailability.available) return const SizedBox.shrink();

    final isOutOfStock = availability == ProductAvailability.outOfStock;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOutOfStock
            ? AppColors.error.withValues(alpha: 0.9)
            : AppColors.warning.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOutOfStock ? 'Out of Stock' : 'Low Stock',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  DiscountPill
// ---------------------------------------------------------------------------
class DiscountPill extends StatelessWidget {
  final double percent;
  const DiscountPill({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${percent.round()}% off',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  ProductImage with shimmer + hero
// ---------------------------------------------------------------------------
class ProductImageWidget extends StatelessWidget {
  final String imageUrl;
  final String productId;
  final double height;
  final bool isOutOfStock;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    required this.productId,
    this.height = 140,
    this.isOutOfStock = false,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'product-$productId',
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Stack(
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: height,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return _ProductImageSkeleton(height: height);
                      },
                      errorBuilder: (ctx, _, __) => _ProductImageFallback(height: height),
                    )
                  : _ProductImageFallback(height: height),
            ),
            // Dimmed overlay for out-of-stock
            if (isOutOfStock)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductImageSkeleton extends StatefulWidget {
  final double height;
  const _ProductImageSkeleton({required this.height});
  @override
  State<_ProductImageSkeleton> createState() => _ProductImageSkeletonState();
}

class _ProductImageSkeletonState extends State<_ProductImageSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        height: widget.height,
        width: double.infinity,
        color: Color.lerp(AppColors.shimmerBase, AppColors.shimmerHighlight, _controller.value),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  final double height;
  const _ProductImageFallback({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppColors.sand,
      child: const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.softOrange),
    );
  }
}

// ---------------------------------------------------------------------------
//  QuantityControl  (- 1 +)
// ---------------------------------------------------------------------------
class QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool enabled;

  const QuantityControl({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.primaryGlowShadows(intensity: 0.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: enabled ? onDecrement : null,
            semanticsLabel: 'Decrease quantity',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: enabled ? onIncrement : null,
            semanticsLabel: 'Increase quantity',
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String semanticsLabel;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.selectionClick();
            onTap!();
          }
        },
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Add Button (when quantity == 0)
// ---------------------------------------------------------------------------
class _AddButton extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Add to cart',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onAdd();
        },
        child: Container(
          height: 36,
          width: 72,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.primaryGlowShadows(intensity: 0.35),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Add',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Main FufajiProductCard Widget
// ---------------------------------------------------------------------------
class FufajiProductCard extends StatefulWidget {
  final ProductModel product;
  final int cartQuantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onTap;
  /// Called when user selects a variant (unitOption). If null, inline variant
  /// pill row is hidden.
  final void Function(ProductUnitOption variant)? onVariantSelected;
  final ProductUnitOption? selectedVariant;

  const FufajiProductCard({
    super.key,
    required this.product,
    this.cartQuantity = 0,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    this.onTap,
    this.onVariantSelected,
    this.selectedVariant,
  });

  @override
  State<FufajiProductCard> createState() => _FufajiProductCardState();
}

class _FufajiProductCardState extends State<FufajiProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _scaleController;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _scaleController.reverse();
  void _onTapUp(_) => _scaleController.forward();
  void _onTapCancel() => _scaleController.forward();

  @override
  Widget build(BuildContext context) {
    final availability = _resolveAvailability(widget.product);
    final isOutOfStock = availability == ProductAvailability.outOfStock;
    final discount = widget.product.effectiveDiscount;
    final mrp = widget.product.mrp;
    final hasVariants = widget.product.unitOptions.isNotEmpty;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: Semantics(
          label:
              '${widget.product.name}, ₹${widget.product.currentPrice.toDouble().toStringAsFixed(0)}, $availability',
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.elevatedCardShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image with badges ──────────────────────────────────────
                Stack(
                  children: [
                    ProductImageWidget(
                      imageUrl: widget.product.imageUrl,
                      productId: widget.product.id,
                      height: 130,
                      isOutOfStock: isOutOfStock,
                    ),
                    // Discount pill (top-left)
                    if (discount > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: DiscountPill(percent: discount),
                      ),
                    // Organic badge (top-right)
                    if (widget.product.isOrganicCertified)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '🌿 Organic',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    // Availability badge (bottom-left)
                    if (availability != ProductAvailability.available)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: AvailabilityBadge(availability: availability),
                      ),
                  ],
                ),

                // ── Info section ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand (if available)
                      if (widget.product.brand != null && widget.product.brand!.isNotEmpty)
                        Text(
                          widget.product.brand!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.6,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      // Product name
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Unit / weight
                      Text(
                        widget.product.unit,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ── Variant pills (inline) ───────────────────────
                      if (hasVariants && widget.onVariantSelected != null)
                        _VariantPillRow(
                          options: widget.product.unitOptions,
                          selected: widget.selectedVariant,
                          onSelect: widget.onVariantSelected!,
                        ),

                      const SizedBox(height: 6),

                      // ── Price row + action ───────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Price section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${widget.product.currentPrice.toDouble().toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (mrp != null && mrp > widget.product.currentPrice.toDouble())
                                Text(
                                  '₹${mrp.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),

                          // Action button
                          if (!isOutOfStock)
                            widget.cartQuantity > 0
                                ? QuantityControl(
                                    quantity: widget.cartQuantity,
                                    onIncrement: widget.onIncrement,
                                    onDecrement: widget.onDecrement,
                                  )
                                : _AddButton(onAdd: widget.onAdd)
                          else
                            const SizedBox.shrink(),
                        ],
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  _VariantPillRow — inline horizontal scroll of variant pills
// ---------------------------------------------------------------------------
class _VariantPillRow extends StatelessWidget {
  final List<ProductUnitOption> options;
  final ProductUnitOption? selected;
  final void Function(ProductUnitOption) onSelect;

  const _VariantPillRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (ctx, i) {
          final opt = options[i];
          final isSelected = selected?.id == opt.id;
          final isUnavailable = opt.stockQuantity <= 0;

          return Semantics(
            label: '${opt.name}${isUnavailable ? ', out of stock' : ''}',
            button: true,
            selected: isSelected,
            child: GestureDetector(
              onTap: isUnavailable ? null : () => onSelect(opt),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : isUnavailable
                          ? AppColors.grey100
                          : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isUnavailable
                              ? AppColors.grey300
                              : AppColors.primary.withValues(alpha: 0.3),
                        ),
                ),
                child: Text(
                  opt.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : isUnavailable
                            ? AppColors.textDisabled
                            : AppColors.primary,
                    decoration: isUnavailable ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  ProductCardSkeleton — shimmer placeholder
// ---------------------------------------------------------------------------
class ProductCardSkeleton extends StatefulWidget {
  const ProductCardSkeleton({super.key});

  @override
  State<ProductCardSkeleton> createState() => _ProductCardSkeletonState();
}

class _ProductCardSkeletonState extends State<ProductCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _block(double w, double h, {double radius = 8}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.shimmerBase,
            AppColors.shimmerHighlight,
            _controller.value,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _block(double.infinity, 130, radius: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(80, 10),
                const SizedBox(height: 6),
                _block(double.infinity, 13),
                const SizedBox(height: 4),
                _block(60, 10),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _block(50, 18),
                    _block(70, 32, radius: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
