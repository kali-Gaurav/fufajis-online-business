import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/product_model.dart';

class ProductModerationScreen extends StatefulWidget {
  const ProductModerationScreen({super.key});

  @override
  State<ProductModerationScreen> createState() => _ProductModerationScreenState();
}

class _ProductModerationScreenState extends State<ProductModerationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchPendingProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Product Moderation Queue', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => adminProvider.fetchPendingProducts(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: adminProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : adminProvider.pendingProducts.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                              SizedBox(height: 16),
                              Text('No products pending approval.', style: TextStyle(fontSize: 16, color: AppTheme.grey600)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: adminProvider.pendingProducts.length,
                          itemBuilder: (context, index) {
                            final product = adminProvider.pendingProducts[index];
                            return _buildProductCard(context, product, adminProvider);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel product, AdminProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Banner
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: product.imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(product.imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                          )
                        : const Icon(Icons.shopping_bag, size: 64, color: AppTheme.grey400),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Info Block
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Shop: ${product.shopName}',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
                Text(
                  'Category: ${product.category}',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => provider.approveProduct(product.shopId, product.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRejectDialog(context, product, provider),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, ProductModel product, AdminProvider provider) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Product'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.rejectProduct(product.shopId, product.id, controller.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
