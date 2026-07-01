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
    final userAddress = context.select<LocationProvider, Address?>(
      (p) => p.selectedAddress,
    );
    final branches = context.select<ShopConfigProvider, List<ShopBranchModel>>(
      (p) => p.branches,
    );

    String branchId = 'primary';
    String branchName = 'Primary Store';
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
        branchName = nearest.branchName;
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
              color: Colors.black.withValues(alpha: 0.06),
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
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child:
                        (product.images.isNotEmpty ||
                            product.imageUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: product.images.isNotEmpty
                                ? product.images[0]
                                : product.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                const ShimmerLoader.rectangular(
                                  height: double.infinity,
                                  borderRadius: 0,
                                ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: Text(
                                  '📦',
                                  style: TextStyle(fontSize: 36),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: Text('📦', style: TextStyle(fontSize: 36)),
                            ),
                          ),
                  ),
                  // Discount / Lightning badge / Expiry badge
                  if (isExpiringSoon)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 10,
                              color: Colors.white,
                            ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.warning, AppTheme.warning],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.warning.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.flash_on,
                              size: 10,
                              color: Colors.white,
                            ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.eco,
                                size: 10,
                                color: Colors.white,
                              ),
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
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Step 9.5: Exclusive "Limited Stock" progress bar for Lightning Deals
                  if (product.isLightningDealActive &&
                      product.stockQuantity < 20)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
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
                              value: (product.stockQuantity / 20).clamp(
                                0.0,
                                1.0,
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.3,
                              ),
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
            Expanded(
              flex: compact ? 3 : 3,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.unit,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: stockVal > 0
                                  ? (stockVal < 10
                                        ? AppTheme.warning
                                        : AppTheme.success)
                                  : AppTheme.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              stockVal > 0
                                  ? (stockVal < 10
                                        ? '${l10n.only} $stockVal ${l10n.left} @ $branchName'
                                        : '${l10n.inStock} @ $branchName')
                                  : '${l10n.outOfStock} @ $branchName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: stockVal > 0
                                    ? (stockVal < 10
                                          ? AppTheme.warning
                                          : AppTheme.success)
                                    : AppTheme.error,
                              ),
                            ),
                          ),
                        ),
                        if (product.shelfPhotoUrl != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.teal.shade200,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user,
                                  size: 8,
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${l10n.freshnessVerified} ✅',
                                  style: const TextStyle(
                                    fontSize: 6,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              Text(
                                PricingUtils.formatINRCompact(product.discountedPrice.toDouble()),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.info,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppTheme.info,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '${l10n.fixedPrice} 🤝',
                                  style: const TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.info,
                                  ),
                                ),
                              ),
                              if (product.mrp != null &&
                                  product.mrp! > product.discountedPrice.toDouble())
                                Text(
                                  PricingUtils.formatINRCompact(product.mrp!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 4),
                        // Add to cart / quantity selector
                        qty > 0
                            ? _QuantitySelector(
                                productId: product.id,
                                quantity: qty,
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _AddButton(product: product),
                                  const SizedBox(width: 4),
                                  _BuyNowButton(product: product),
                                ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.warning,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${l10n.fastest} 🚀',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 6,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.info,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l10n.quickBook,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: product.farmerImageUrl != null
                      ? CachedNetworkImageProvider(product.farmerImageUrl!)
                      : null,
                  child: product.farmerImageUrl == null
                      ? const Icon(Icons.person, color: AppTheme.primaryColor)
                      : null,
                ),
                title: Text(
                  product.farmerName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  l10n.farmerPartner,
                  style: const TextStyle(fontSize: 12),
                ),
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
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.5),
                  ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (product.sourceLocation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${product.sourceLocation!.latitude.toStringAsFixed(4)}, ${product.sourceLocation!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
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
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
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
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: AppTheme.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate('sourcingTransparency',
                          arguments: {'source': product.sourceName ?? "local farms"}),
                      style: const TextStyle(fontSize: 12, color: AppTheme.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(l10n.cancel),
          ),
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
      final webUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Map application not available';
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open map: $e'),
          backgroundColor: AppTheme.error,
        ),
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
      return Text(
        l10n.outOfStock,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      );
    }
    return GestureDetector(
      onTap: () => context.read<CartProvider>().addItem(product),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '+ ${l10n.add}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
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
        border: Border.all(color: AppTheme.primaryColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () =>
                context.read<CartProvider>().decrementQuantity(productId),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.remove, size: 14, color: AppTheme.primaryColor),
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.read<CartProvider>().incrementQuantity(productId),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.add, size: 14, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
