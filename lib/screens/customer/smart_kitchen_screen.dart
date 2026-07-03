import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../services/smart_kitchen_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class SmartKitchenScreen extends StatefulWidget {
  const SmartKitchenScreen({super.key});

  @override
  State<SmartKitchenScreen> createState() => _SmartKitchenScreenState();
}

class _SmartKitchenScreenState extends State<SmartKitchenScreen> {
  final SmartKitchenService _kitchenService = SmartKitchenService();
  List<StaplePrediction> _staples = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await _kitchenService.predictReplenishmentNeeds(user.id);
      setState(() {
        _staples = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading kitchen data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _addStapleToCart(StaplePrediction staple) async {
    final productProvider = context.read<ProductProvider>();
    final product = productProvider.getProductById(staple.productId);

    if (product != null) {
      context.read<CartProvider>().addItem(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart!'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product not found in current inventory.')));
    }
  }

  void _addAllLowToCart() {
    final productProvider = context.read<ProductProvider>();
    final cart = context.read<CartProvider>();
    int addedCount = 0;

    for (var staple in _staples) {
      if (staple.isRunningLow) {
        final product = productProvider.getProductById(staple.productId);
        if (product != null) {
          cart.addItem(product);
          addedCount++;
        }
      }
    }

    if (addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $addedCount items to cart!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Smart Kitchen', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _staples.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildUrgentHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _staples.length,
                    itemBuilder: (context, index) {
                      final staple = _staples[index];
                      return _buildStapleCard(staple);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.kitchen_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Your Smart Kitchen is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Once you buy items multiple times, Fufaji will start predicting when you\'ll run out!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentHeader() {
    final lowCount = _staples.where((s) => s.isRunningLow).length;
    if (lowCount == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppTheme.warning.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You are running low on $lowCount staples!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: _addAllLowToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Refill All'),
          ),
        ],
      ),
    );
  }

  Widget _buildStapleCard(StaplePrediction staple) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: staple.productImage != null
                  ? CachedNetworkImage(
                      imageUrl: staple.productImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[100],
                      child: const Icon(Icons.inventory_2),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staple.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        staple.isRunningLow ? Icons.timer : Icons.calendar_today,
                        size: 14,
                        color: staple.isRunningLow ? AppTheme.error : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        staple.isRunningLow
                            ? 'Running low! (${staple.daysRemaining} days left)'
                            : 'Next refill around ${DateFormat('dd MMM').format(staple.nextPredictedDate)}',
                        style: TextStyle(
                          color: staple.isRunningLow ? AppTheme.error : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: staple.isRunningLow ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Purchased ${staple.purchaseCount} times • Every ${staple.avgIntervalDays.round()} days',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _addStapleToCart(staple),
              icon: const Icon(Icons.add_shopping_cart),
              color: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
