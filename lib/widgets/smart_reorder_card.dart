import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../constants/order_status.dart';
import '../utils/app_theme.dart';

class SmartReorderCard extends StatelessWidget {
  const SmartReorderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final cartProvider = context.read<CartProvider>();
    final productProvider = context.read<ProductProvider>();

    if (orderProvider.orders.isEmpty) return const SizedBox.shrink();

    // Suggest reordering the last successful order
    final lastOrder = orderProvider.orders.firstWhere(
      (o) => o.status == OrderStatus.delivered,
      orElse: () => orderProvider.orders.first,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.05), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bhaiya, Same Order!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.grey900,
                        ),
                      ),
                      Text(
                        'Add your weekly items in one tap',
                        style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...lastOrder.items.take(4).map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.grey200),
                    ),
                    child: Text(
                      '${item.productName} (${item.quantity}${item.unit})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  );
                }),
                if (lastOrder.items.length > 4)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '+${lastOrder.items.length - 4} more',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  for (final item in lastOrder.items) {
                    final product = productProvider.products.firstWhere(
                      (p) => p.id == item.productId,
                      orElse: () => productProvider.products.first, // Fallback
                    );
                    cartProvider.addToCart(product, quantity: item.quantity);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${lastOrder.items.length} items cart mein add kar diye gaye!'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: 'Cart Dekho',
                        textColor: Colors.white,
                        onPressed: () => Navigator.of(context).pushNamed('/cart'),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: const Text('Add All to Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
