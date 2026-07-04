/// 🎨 ProductCard Widget
/// Beautiful, accessible product card for Fufaji Store
/// Features: English/Hindi support, price breakdown, stock status, ratings

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_spacing.dart';
import '../models/product.dart';
import '../utils/pricing_utils.dart';

class ProductCard extends StatelessWidget {
  /// Product data to display
  final Product product;

  /// Callback when user taps "Add to Cart"
  final VoidCallback onAddToCart;

  /// Callback when user taps "View Details"
  final VoidCallback onViewDetails;

  /// Callback when user taps "Share"
  final VoidCallback onShare;

  /// Display language ('en' or 'hi')
  final String language;

  const ProductCard({
    Key? key,
    required this.product,
    required this.onAddToCart,
    required this.onViewDetails,
    required this.onShare,
    this.language = 'en',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSpacing.elevation2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.cardMargin,
        vertical: AppSpacing.cardMargin,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// Product Image with Discount Badge
            _buildImageSection(),

            /// Product Info
            Padding(
              padding: EdgeInsets.all(AppSpacing.productCardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Product Name
                  _buildProductName(),
                  SizedBox(height: AppSpacing.gapMedium),

                  /// Rating and Weight
                  _buildMetadata(),
                  SizedBox(height: AppSpacing.gapLarge),

                  /// Price Breakdown
                  _buildPriceSection(),
                  SizedBox(height: AppSpacing.gapMedium),

                  /// Stock Badge
                  _buildStockBadge(),
                  SizedBox(height: AppSpacing.gapLarge),

                  /// Add to Cart Button
                  _buildAddToCartButton(),
                  SizedBox(height: AppSpacing.gapMedium),

                  /// Secondary Actions
                  _buildSecondaryActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        Container(
          height: AppSpacing.productCardImageHeight,
          color: AppColors.surfaceMedium,
          child: Image.network(
            product.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(Icons.image, size: 48),
          ),
        ),
        if (product.hasDiscount)
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.discountBadge,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Text(
                '${product.discountPercentInt}% OFF',
                style: AppTypography.discountBadge,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.nameEn, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.productNameEn),
        if (product.nameHi.isNotEmpty)
          Text(product.nameHi, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.productNameHi),
      ],
    );
  }

  Widget _buildMetadata() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('⭐ ${product.rating.toStringAsFixed(1)} (${product.reviewCount})', style: AppTypography.productRating),
        Text(product.weight, style: AppTypography.productWeight),
      ],
    );
  }

  Widget _buildPriceSection() {
    final breakdown = PricingUtils.getPriceBreakdown(product.basePrice, product.discountPercent, product.gstRate);

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Base', style: AppTypography.labelMedium),
              Text(PricingUtils.formatINR(product.basePrice), style: AppTypography.originalPrice),
            ],
          ),
          if (product.hasDiscount) ...[
            SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount (${product.discountPercent.toStringAsFixed(1)}%)', style: AppTypography.labelMedium),
                Text('-${PricingUtils.formatINR(breakdown.discountAmount)}',
                    style: AppTypography.labelMedium.withColor(AppColors.danger)),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('After Discount', style: AppTypography.labelMedium),
                Text(PricingUtils.formatINR(breakdown.priceAfterDiscount), style: AppTypography.priceMedium),
              ],
            ),
          ],
          SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GST (18%)', style: AppTypography.labelMedium),
              Text('+${PricingUtils.formatINR(breakdown.gstAmount)}',
                  style: AppTypography.labelMedium.withColor(AppColors.warning)),
            ],
          ),
          Divider(height: AppSpacing.xl, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTypography.h5),
              Text(PricingUtils.formatINR(breakdown.finalPrice), style: AppTypography.priceLarge),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge() {
    final badgeColor = product.isInStock ? AppColors.success : AppColors.danger;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(product.stockStatus, style: AppTypography.stockBadge.copyWith(color: badgeColor)),
    );
  }

  Widget _buildAddToCartButton() {
    return Material(
      child: InkWell(
        onTap: product.isInStock ? onAddToCart : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonHorizontalPadding,
            vertical: AppSpacing.buttonVerticalPaddingMedium,
          ),
          decoration: BoxDecoration(
            color: product.isInStock ? AppColors.accent : AppColors.textDisabled,
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          ),
          child: Text('Add to Cart', textAlign: TextAlign.center,
              style: AppTypography.buttonMedium.copyWith(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSecondaryButton('Details', Icons.info_outline, onViewDetails),
        _buildSecondaryButton('Share', Icons.share_outlined, onShare),
        _buildSecondaryButton('Wishlist', Icons.favorite_outline, () {}),
      ],
    );
  }

  Widget _buildSecondaryButton(String label, IconData icon, VoidCallback onTap) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Column(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: AppSpacing.iconMedium),
              SizedBox(height: AppSpacing.xs),
              Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
