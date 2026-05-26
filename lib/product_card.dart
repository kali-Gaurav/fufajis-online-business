import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/product_model.dart';
import 'providers/cart_provider.dart';
import 'utils/app_theme.dart';
import 'widgets/common/shimmer_loader.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool compact;

  const ProductCard({
    super.key,
    required this.product,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.getQuantity(product.id);
    final discount = product.effectiveDiscount;

    return GestureDetector(
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
                    child: (product.images.isNotEmpty || product.imageUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: product.images.isNotEmpty ? product.images[0] : product.imageUrl,
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
                            child: const Center(
                              child: Text('📦', style: TextStyle(fontSize: 36)),
                            ),
                          ),
                  ),
                  // Discount / Lightning badge
                  if (product.isLightningDealActive)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.amber, Colors.orangeAccent],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.5),
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
                              '${product.effectiveDiscount.toStringAsFixed(0)}% OFF',
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
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${discount.toStringAsFixed(0)}% OFF',
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
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.eco, size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                product.village.isNotEmpty ? product.village : 'Local',
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
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '₹${product.discountedPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        if (product.mrp != null &&
                            product.mrp! > product.discountedPrice) ...[
                          const SizedBox(width: 4),
                          Text(
                            '₹${product.mrp!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Add to cart / quantity selector
                        qty > 0
                            ? _QuantitySelector(
                                productId: product.id,
                                quantity: qty,
                              )
                            : Row(
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
              color: Colors.amber,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'FASTEST 🚀',
              style: TextStyle(
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
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'QUICK BOOK',
              style: TextStyle(
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
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.eco, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                product.sourceName ?? 'Sourcing Location',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source info
            if (product.village.isNotEmpty || product.origin != null) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    product.village.isNotEmpty
                        ? '${product.village}, ${product.origin ?? ""}'
                        : product.origin ?? 'Local Source',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // Mini-map placeholder (would integrate with Google Maps in production)
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
                        Icon(
                          Icons.map,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '📍 ${product.sourceName ?? "Farm Location"}',
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
                          color: Colors.green,
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
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This product is sourced directly from ${product.sourceName ?? "local farms"}. Scan QR code for full traceability.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[800],
                      ),
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
            child: const Text('Close'),
          ),
          if (product.sourceLocation != null)
            ElevatedButton.icon(
              onPressed: () {
                _openInMaps(product);
                context.pop();
              },
              icon: const Icon(Icons.directions, size: 18),
              label: const Text('Get Directions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      );
    },
  );
}

/// Open location in maps app
void _openInMaps(ProductModel product) async {
  if (product.sourceLocation == null) return;
  
  final lat = product.sourceLocation!.latitude;
  final lng = product.sourceLocation!.longitude;
  final label = product.sourceName ?? 'Product Source';
  
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$label',
  );
  
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    // Fallback to web
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(webUri);
  }
}

class _AddButton extends StatelessWidget {
  final ProductModel product;
  const _AddButton({required this.product});

  @override
  Widget build(BuildContext context) {
    if (!product.inStock) {
      return const Text(
        'Out of Stock',
        style: TextStyle(fontSize: 10, color: Colors.grey),
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
        child: const Text(
          '+ ADD',
          style: TextStyle(
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

  const _QuantitySelector({
    required this.productId,
    required this.quantity,
  });

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
            onTap: () => context.read<CartProvider>().decrementQuantity(productId),
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
            onTap: () => context.read<CartProvider>().incrementQuantity(productId),
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
