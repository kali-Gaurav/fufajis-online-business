import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'models/product_model.dart';
import 'models/shop_branch_model.dart';
import 'models/user_model.dart';
import 'widgets/animated_widgets.dart';
import 'providers/cart_provider.dart';
import 'providers/location_provider.dart';
import 'providers/shop_config_provider.dart';
import 'services/shop_config_service.dart';
import 'utils/app_theme.dart';
import 'utils/pricing.dart';
import 'widgets/common/shimmer_loader.dart';
import 'l10n/app_localizations.dart';

// ============================================
// Product Category Emoji Mapping
// ============================================
String _getEmojiForCategory(String category) {
  final categoryLower = category.toLowerCase();

  // Grocery & Staples
  if (categoryLower.contains('rice') || categoryLower.contains('atta') || categoryLower.contains('flour')) return '🌾';
  if (categoryLower.contains('oil') || categoryLower.contains('ghee')) return '🫗';
  if (categoryLower.contains('sugar') || categoryLower.contains('salt')) return '🥄';
  if (categoryLower.contains('spice') || categoryLower.contains('masala')) return '🌶️';

  // Vegetables & Fruits
  if (categoryLower.contains('vegetable') || categoryLower.contains('sabzi')) return '🥬';
  if (categoryLower.contains('fruit') || categoryLower.contains('apple') || categoryLower.contains('banana')) return '🍎';
  if (categoryLower.contains('potato') || categoryLower.contains('onion')) return '🥔';
  if (categoryLower.contains('tomato')) return '🍅';

  // Dairy & Milk Products
  if (categoryLower.contains('milk') || categoryLower.contains('doodh')) return '🥛';
  if (categoryLower.contains('butter') || categoryLower.contains('paneer')) return '🧈';
  if (categoryLower.contains('yogurt') || categoryLower.contains('curd')) return '🍦';
  if (categoryLower.contains('cheese')) return '🧀';

  // Bakery & Bread
  if (categoryLower.contains('bread') || categoryLower.contains('pav')) return '🍞';
  if (categoryLower.contains('cake') || categoryLower.contains('pastry')) return '🎂';
  if (categoryLower.contains('biscuit') || categoryLower.contains('cookie')) return '🍪';

  // Meat & Proteins
  if (categoryLower.contains('chicken') || categoryLower.contains('meat')) return '🍗';
  if (categoryLower.contains('fish') || categoryLower.contains('seafood')) return '🐟';
  if (categoryLower.contains('egg')) return '🥚';

  // Beverages
  if (categoryLower.contains('coffee') || categoryLower.contains('tea')) return '☕';
  if (categoryLower.contains('juice') || categoryLower.contains('drink')) return '🧃';
  if (categoryLower.contains('water')) return '💧';

  // Snacks & Ready-to-Eat
  if (categoryLower.contains('snack') || categoryLower.contains('chips')) return '🥨';
  if (categoryLower.contains('noodle') || categoryLower.contains('maggi')) return '🍜';
  if (categoryLower.contains('candy') || categoryLower.contains('chocolate')) return '🍫';

  // Household & Personal Care
  if (categoryLower.contains('soap') || categoryLower.contains('wash')) return '🧼';
  if (categoryLower.contains('shampoo') || categoryLower.contains('conditioner')) return '🧴';
  if (categoryLower.contains('detergent') || categoryLower.contains('cleaning')) return '🧽';

  // Default emoji for unknown categories
  return '📦';
}

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool compact;

  const ProductCard({super.key, required this.product, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // Optimized: Only listen to quantity changes for this specific product (Weakness 10 fix)
    final qty = context.select<CartProvider, int>((p) => p.getQuantity(product.id));
    final discount = product.effectiveDiscount;
    final l10n = AppLocalizations.of(context)!;

    // Optimized: Only listen to selectedAddress and branches changes to reduce rebuild churn (Weakness 10 fix)
    final userAddress = context.select<LocationProvider, Address?>((p) => p.selectedAddress);
    final branches = context.select<ShopConfigProvider, List<ShopBranchModel>>((p) => p.branches);

    String branchId = 'primary';
    // Harden: Ensure coordinates are valid and branches is not empty (Weakness 11 & 37/Address validation fixes)
    if (userAddress != null &&
        userAddress.latitude != 0.0 &&
        userAddress.longitude != 0.0 &&
        branches.isNotEmpty) {
      final nearest = ShopConfigService().getNearestBranch(
        userAddress.latitude,
        userAddress.longitude,
        branches,
      );
      if (nearest != null) {
        branchId = nearest.id;
      }
    }

    final stockVal = product.branchStock[branchId] ?? product.stockQuantity;

    final bool isExpiringSoon =
        product.expiryDate != null &&
        product.expiryDate!.difference(DateTime.now()).inDays <= 3 &&
        !product.isExpired;

    return ScaleBounce(
      scaleFactor: 0.96,
      onTap: () => context.push('/customer/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── IMAGE ─────────────────────────────────────────────────
            Expanded(
              flex: compact ? 3 : 4,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: (product.images.isNotEmpty || product.imageUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: product.images.isNotEmpty
                                ? product.images[0]
                                : product.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ShimmerLoader.rectangular(
                              height: double.infinity,
                              borderRadius: 0,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: Text('📦', style: TextStyle(fontSize: 36)),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: const Center(child: Text('📦', style: TextStyle(fontSize: 36))),
                          ),
                  ),
                  // Discount / Lightning badge / Expiry badge
                  if (isExpiringSoon)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 10, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(
                              '${l10n.translate("expiringSoon")} - ${discount > 0 ? discount.toStringAsFixed(0) : "20"}% ${l10n.translate("off")}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (product.isLightningDealActive)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.warning, AppTheme.warning],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.warning.withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on, size: 10, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(
                              '${product.effectiveDiscount.toStringAsFixed(0)}% ${l10n.translate("off")}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (discount > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${discount.toStringAsFixed(0)}% ${l10n.translate("off")}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  // Local badge
                  if (product.isLocal)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: product.sourceLocation != null
                            ? () => _showSourceLocationDialog(context, product)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.eco, size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                product.village.isNotEmpty
                                    ? product.village
                                    : l10n.translate('localSource'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (product.sourceLocation != null) ...[
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.map,
                                  size: 10,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Step 9.5: Exclusive "Limited Stock" progress bar for Lightning Deals
                  if (product.isLightningDealActive && product.stockQuantity < 20)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${l10n.only} ${product.stockQuantity} ${l10n.left}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (product.stockQuantity / 20).clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withOpacity(0.3),
                              color: AppTheme.error,
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ─── INFO ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name with emoji category icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getEmojiForCategory(product.categoryId),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.unit,
                                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Stock & Freshness Status
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: stockVal > 0
                                  ? (stockVal < 10 ? AppTheme.warning : AppTheme.success)
                                  : AppTheme.error,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: (stockVal > 0 ? (stockVal < 10 ? AppTheme.warning : AppTheme.success) : AppTheme.error).withOpacity(0.3),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: Text(
                              stockVal > 0
                                  ? (stockVal < 10
                                        ? '⚠️ ${l10n.only} $stockVal ${l10n.left}'
                                        : '✅ ${l10n.inStock}')
                                  : '❌ ${l10n.outOfStock}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (product.shelfPhotoUrl != null || product.isLocal) ...[
                          const SizedBox(width: 6),
                          if (product.isLocal)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade300, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🌱', style: TextStyle(fontSize: 10)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Local',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (product.shelfPhotoUrl != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.shade300, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('✨', style: TextStyle(fontSize: 10)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Fresh',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Price & Value Indicators
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            // Current Price (Large, Bold)
                            Text(
                              PricingUtils.formatINRCompact(product.discountedPrice.toDouble()),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Original Price (Strikethrough if exists)
                            if (product.mrp != null && product.mrp! > product.discountedPrice.toDouble())
                              Text(
                                PricingUtils.formatINRCompact(product.mrp!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Value Badges
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (discount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.error, Colors.red.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.error.withOpacity(0.3), blurRadius: 4)
                                  ],
                                ),
                                child: Text(
                                  '💰 ${discount.toStringAsFixed(0)}% OFF',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (product.isLightningDealActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.warning, Colors.orange.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.warning.withOpacity(0.3), blurRadius: 4)
                                  ],
                                ),
                                child: const Text(
                                  '⚡ LIGHTNING DEAL',
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.success, width: 0.8),
                              ),
                              child: Text(
                                '🤝 Fixed Price',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Add to cart / quantity selector
                        qty > 0
                            ? _QuantitySelector(productId: product.id, quantity: qty)
                            : Row(
                                children: [
                                  Expanded(child: _AddButton(product: product)),
                                  const SizedBox(width: 4),
                                  Expanded(child: _BuyNowButton(product: product)),
                                ],
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

class _BuyNowButton extends StatelessWidget {
  final ProductModel product;
  const _BuyNowButton({required this.product});

  @override
  Widget build(BuildContext context) {
    if (!product.inStock) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () {
        context.read<CartProvider>().addItem(product);
        context.push('/customer/checkout');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.info, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppTheme.info.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🚀',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              '${l10n.fastest}\n${l10n.quickBook}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Show source location dialog with mini-map
void _showSourceLocationDialog(BuildContext context, ProductModel product) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.eco, color: AppTheme.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                product.sourceName ?? l10n.sourcingLocation,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Farmer Profile (Step 11.3)
            if (product.farmerName != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  backgroundImage: product.farmerImageUrl != null
                      ? CachedNetworkImageProvider(product.farmerImageUrl!)
                      : null,
                  child: product.farmerImageUrl == null
                      ? const Icon(Icons.person, color: AppTheme.primaryColor)
                      : null,
                ),
                title: Text(
                  product.farmerName!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(l10n.farmerPartner, style: const TextStyle(fontSize: 12)),
              ),

            // Sourcing Info
            if (product.village.isNotEmpty || product.origin != null) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    product.village.isNotEmpty
                        ? '${product.village}, ${product.origin ?? ""}'
                        : product.origin ?? l10n.localSource,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Organic Badge (Step 11.5)
            if (product.isOrganicCertified)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.success.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, color: AppTheme.success, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      l10n.certifiedOrganic,
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

            // Sourcing Date (Step 11.4)
            if (product.harvestDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.harvestedOn(DateFormat.yMMMd().format(product.harvestDate!)),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.grey600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Mini-map placeholder
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Stack(
                children: [
                  // Placeholder map background
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          '📍 ${product.sourceName ?? l10n.sourcingLocation}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (product.sourceLocation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${product.sourceLocation!.latitude.toStringAsFixed(4)}, ${product.sourceLocation!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Location pin
                  if (product.sourceLocation != null)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Transparency info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: AppTheme.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate(
                        'sourcingTransparency',
                        arguments: {'source': product.sourceName ?? "local farms"},
                      ),
                      style: const TextStyle(fontSize: 12, color: AppTheme.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: Text(l10n.cancel)),
          if (product.sourceLocation != null)
            ElevatedButton.icon(
              onPressed: () {
                _openInMaps(context, product);
                context.pop();
              },
              icon: const Icon(Icons.directions, size: 18),
              label: Text(l10n.getDirections),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      );
    },
  );
}

/// Open location in maps app
void _openInMaps(BuildContext context, ProductModel product) async {
  if (product.sourceLocation == null) return;

  final lat = product.sourceLocation!.latitude;
  final lng = product.sourceLocation!.longitude;
  final label = product.sourceName ?? 'Product Source';

  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$label',
  );

  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web
      final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Map application not available';
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open map: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

class _AddButton extends StatelessWidget {
  final ProductModel product;
  const _AddButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!product.inStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('❌', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              l10n.outOfStock,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => context.read<CartProvider>().addItem(product),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              l10n.add,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final String productId;
  final int quantity;

  const _QuantitySelector({required this.productId, required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withOpacity(0.1), AppTheme.primary.withOpacity(0.05)],
        ),
        border: Border.all(color: AppTheme.primaryColor, width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => context.read<CartProvider>().decrementQuantity(productId),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.remove_circle, size: 16, color: AppTheme.primaryColor),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<CartProvider>().incrementQuantity(productId),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.add_circle, size: 16, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
