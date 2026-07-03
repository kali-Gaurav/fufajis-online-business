import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/pricing.dart';

/// Product card component
class ProductCard extends StatelessWidget {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final VoidCallback onAddToCart;
  final VoidCallback? onTap;
  final bool inStock;
  final bool isNew;
  final double? discountPercent;

  const ProductCard({
    super.key,
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.onAddToCart,
    this.onTap,
    this.inStock = true,
    this.isNew = false,
    this.discountPercent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pricing = PricingDisplay(basePrice: price, gstRate: 18.0);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : AppTheme.grey100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Image.network(imageUrl!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.shopping_bag_outlined, color: AppTheme.grey400, size: 40),
            ),

            // CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      pricing.basePriceCompact,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      '+ ${pricing.gstDisplayString}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            // BUTTON
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: inStock ? onAddToCart : null,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18, color: Colors.white),
                  label: Text(
                    inStock ? 'कार्ट में जोड़ें' : 'Stock में नहीं',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: inStock ? AppTheme.primary : AppTheme.grey400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
