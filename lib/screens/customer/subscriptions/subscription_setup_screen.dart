import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../models/product_model.dart';
import '../../../models/subscription_model.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/subscription_service.dart';
import '../../../utils/app_theme.dart';

class SubscriptionSetupScreen extends StatefulWidget {
  const SubscriptionSetupScreen({super.key});

  @override
  State<SubscriptionSetupScreen> createState() => _SubscriptionSetupScreenState();
}

class _SubscriptionSetupScreenState extends State<SubscriptionSetupScreen> {
  final Map<String, int> _selectedItems = {}; // productId -> quantity

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscribe to Products'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: productProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : productProvider.products.isEmpty
                    ? const Center(
                        child: Text('No products available for subscription'),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: productProvider.products.length,
                        itemBuilder: (context, index) {
                          final product = productProvider.products[index];
                          final isSelected = _selectedItems.containsKey(product.id);
                          final quantity = _selectedItems[product.id] ?? 0;

                          return _buildProductCard(product, isSelected, quantity);
                        },
                      ),
          ),
          if (_selectedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_selectedItems.length} item(s) selected',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.grey600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _proceedToCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Proceed to Checkout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product, bool isSelected, int quantity) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedItems.remove(product.id);
          } else {
            _selectedItems[product.id] = 1;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.grey200,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? AppTheme.primary.withOpacity(0.05) : AppTheme.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.grey100,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      )
                    : Container(
                        color: AppTheme.grey100,
                        child: const Icon(Icons.inventory_2),
                      ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Qty: $quantity',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  Future<void> _proceedToCheckout() async {
    // Convert selected items to SubscriptionItem
    final items = _selectedItems.entries.map((entry) {
      final productId = entry.key;
      final quantity = entry.value;
      final product = Provider.of<ProductProvider>(context, listen: false)
          .products
          .firstWhere((p) => p.id == productId);

      return SubscriptionItem(
        productId: productId,
        quantity: quantity,
        unitPrice: product.price.toDouble(),
      );
    }).toList();

    // Navigate to checkout with items and wait for result
    final result = await context.push(
      '/customer/subscription-checkout',
      extra: items,
    );

    // If subscription was created, reload subscriptions and pop
    if (result != null && mounted) {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        await subscriptionProvider.fetchSubscriptions(authProvider.currentUser!.id);
      }
      if (mounted) {
        context.pop();
      }
    }
  }
}
