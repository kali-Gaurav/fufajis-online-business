import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../services/recommendation_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/fj_empty_state.dart';
import '../../models/cart_item.dart';
import '../../widgets/trust/fj_trust_banner.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/missing_animations.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  bool _showCouponField = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  void _showRemoveConfirmation(
    BuildContext context,
    CartItem item,
    CartProvider cartProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Cart?'),
        content: Text('Remove ${item.productName} from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cartProvider.removeFromCart(item.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.productName} removed'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () {
                      cartProvider.addToCart(
                        ProductModel(
                          id: item.productId,
                          name: item.productName,
                          description: '',
                          price: item.price,
                          unit: item.unit,
                          imageUrl: item.productImage,
                          categoryId: 'other',
                          shopId: item.shopId,
                          shopName: '',
                          stockQuantity: 100,
                          district: 'Baran',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                        quantity: item.quantity,
                      );
                    },
                  ),
                ),
              );
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      body: cartProvider.cartItems.isEmpty
          ? _buildEmptyCart()
          : _buildCartContent(cartProvider),
    );
  }

  Widget _buildEmptyCart() {
    return FjEmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'Your cart is empty',
      subtitle: 'Browse our store and add items to get started',
      buttonLabel: 'Start Shopping',
      onButtonTap: () => context.go('/customer/home'),
    );
  }

  Widget _buildMinOrderProgress(CartProvider cartProvider) {
    const minOrder = 500.0;
    final progress = (cartProvider.subtotal / minOrder).clamp(0.0, 1.0);
    final remaining = minOrder - cartProvider.subtotal;
    final unlocked = progress >= 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: unlocked ? AppTheme.success.withValues(alpha: 0.08) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: unlocked ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.grey200,
            width: unlocked ? 2 : 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.celebration_rounded : Icons.delivery_dining,
                size: 18,
                color: unlocked ? AppTheme.success : AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  remaining > 0
                      ? 'Add ₹${remaining.round()} more for FREE delivery'
                      : '🎉 FREE delivery unlocked!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: unlocked ? AppTheme.success : AppTheme.grey700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.grey100,
              color: unlocked ? AppTheme.success : AppTheme.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(CartProvider cartProvider) {
    final productProvider = Provider.of<ProductProvider>(context);

    // Map cart items to ProductModels
    final cartProducts = cartProvider.cartItems
        .map((item) {
          return productProvider.getProductById(item.productId);
        })
        .whereType<ProductModel>()
        .toList();

    // Get smart recommendations
    final recommendedProducts = RecommendationService.getRecommendations(
      allProducts: productProvider.products,
      cartProducts: cartProducts,
    );

    return Column(
      children: [
        _buildMinOrderProgress(cartProvider),
        _buildShopWarning(cartProvider),
        // Cart Items & Up-Sell Slider
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = cartProvider.cartItems[index];
                      // Step 16.2: Swipe-to-delete — wrapped in spring entrance
                      return SpringCard(
                        delay: Duration(milliseconds: index * 60),
                        springDistance: 50,
                        child: Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          cartProvider.removeFromCart(item.id);
                          HapticFeedback.lightImpact();
                        },
                        background: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: _buildCartItem(item, cartProvider),
                      ),
                      ); // SpringCard
                    },
                    childCount: cartProvider.cartItems.length,
                  ),
                ),
              ),
              if (recommendedProducts.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 24),
                  sliver: SliverToBoxAdapter(
                    child:
                        _buildUpSellSection(recommendedProducts, cartProvider),
                  ),
                ),
            ],
          ),
        ),
        // Bottom Sheet
        _buildCartBottomSheet(cartProvider),
      ],
    );
  }

  Widget _buildUpSellSection(
      List<ProductModel> recommendedProducts, CartProvider cartProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.stars, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Complete Your Basket',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recommendedProducts.length,
            itemBuilder: (context, index) {
              final product = recommendedProducts[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: AppTheme.grey100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: product.imageUrl,
                            height: 85,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 85,
                              color: AppTheme.grey100,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (context, error, stackTrace) =>
                                Container(
                              height: 85,
                              color: AppTheme.grey100,
                              child: const Icon(Icons.image_not_supported,
                                  size: 30),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${product.discountPercentage?.round() ?? 0}% OFF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Product details
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.grey900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            product.unit,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.grey500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₹${product.price.round()}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  Text(
                                    '₹${product.originalPrice?.round() ?? product.price.round()}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.grey400,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                              // Instant add button
                              GestureDetector(
                                onTap: () {
                                  cartProvider.addToCart(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${product.name} added to cart!'),
                                      duration: const Duration(seconds: 1),
                                      action: SnackBarAction(
                                        label: 'UNDO',
                                        onPressed: () {
                                          cartProvider
                                              .removeFromCart(product.id);
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
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
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItem item, CartProvider cartProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Product Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.productImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.productImage,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppTheme.grey100,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                        ),
                        errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: AppTheme.grey400),
                      )
                    : const Icon(Icons.image, color: AppTheme.grey400),
              ),
              ),
              const SizedBox(width: 12),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.grey900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.selectedVariant != null)
                      Text(
                        item.selectedVariant!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey500,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${item.price.round()}/${item.unit}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        // Quantity Control — P0 FIX: Larger icons 24px
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: item.quantity > 1
                                    ? () => cartProvider.updateQuantity(
                                        item.id, item.quantity - 1)
                                    : null,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => cartProvider.updateQuantity(
                                    item.id, item.quantity + 1),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Remove Button — P0 FIX: Add confirmation for destructive action
              GestureDetector(
                onTap: () => _showRemoveConfirmation(context, item, cartProvider),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.error,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          // Cart item notes (Step 16.5)
          const SizedBox(height: 8),
          TextField(
            onChanged: (val) => cartProvider.updateItemNotes(item.id, val),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Add notes (e.g. "Green bananas only")',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.grey200)),
              prefixIcon: const Icon(Icons.edit_note, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartBottomSheet(CartProvider cartProvider) {
    const minOrder = 500.0;
    final canCheckout = cartProvider.subtotal >= minOrder;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // P0 FIX: Add Trust Layer to Cart
          const FufajiTrustBanner(),
          const SizedBox(height: 16),

          // Coupon Section
          _showCouponField
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        decoration: InputDecoration(
                          hintText: 'Enter coupon code',
                          filled: true,
                          fillColor: AppTheme.grey100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final success =
                            cartProvider.applyCoupon(_couponController.text);
                        if (!success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Invalid coupon code')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Coupon applied!'),
                                backgroundColor: AppTheme.success),
                          );
                        }
                        setState(() => _showCouponField = false);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: () => setState(() => _showCouponField = true),
                  child: const Row(
                    children: [
                      Icon(Icons.discount_outlined,
                          color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'Apply Coupon',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_forward_ios,
                          size: 16, color: AppTheme.grey400),
                    ],
                  ),
                ),
          if (cartProvider.appliedCoupon != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${cartProvider.appliedCoupon!.code} applied (₹${cartProvider.discount.round()})',
                    style: const TextStyle(
                        color: AppTheme.success, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => cartProvider.removeCoupon(),
                    icon: const Icon(Icons.close,
                        size: 18, color: AppTheme.success),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Price Details
          _buildPriceRow('Subtotal', cartProvider.subtotal),
          const SizedBox(height: 8),
          _buildPriceRow(
              'Delivery', cartProvider.deliveryCharge == 0 ? 'FREE' : null,
              isFree: cartProvider.deliveryCharge == 0),
          if (cartProvider.deliveryCharge > 0)
            Text(
              'Free delivery on orders above ₹500',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.success.withValues(alpha: 0.8)),
            ),
          const SizedBox(height: 8),
          if (cartProvider.discount > 0)
            _buildPriceRow('Discount', -cartProvider.discount,
                isDiscount: true),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              MorphNumber(
                value: cartProvider.total.round(),
                prefix: '₹',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Checkout Button — P0 FIX: Disable if min order not met
          if (!canCheckout)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.warning,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Minimum order: ₹500',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ScaleBounce(
            onTap: canCheckout ? () => context.push('/customer/checkout') : null,
            child: ParticlesBurst(
              colors: const [
                Color(0xFFFF6B00),
                Color(0xFFFFD700),
                Color(0xFFFF8C42),
              ],
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: canCheckout ? AppTheme.buttonGradient : const LinearGradient(
                    colors: [AppTheme.grey300, AppTheme.grey400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: canCheckout ? AppTheme.primaryGlowShadows() : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: canCheckout ? Colors.white : AppTheme.grey600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Proceed to Checkout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: canCheckout ? Colors.white : AppTheme.grey600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, dynamic value,
      {bool isFree = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isFree ? AppTheme.success : AppTheme.grey600,
          ),
        ),
        Text(
          value is String
              ? value
              : isDiscount
                  ? '- ₹${value.abs().round()}'
                  : '₹${value.round()}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isFree
                ? AppTheme.success
                : isDiscount
                    ? AppTheme.success
                    : AppTheme.grey900,
          ),
        ),
      ],
    );
  }

  Widget _buildShopWarning(CartProvider cartProvider) {
    final shopIds = cartProvider.cartItems.map((item) => item.shopId).toSet();
    if (shopIds.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.warning.withValues(alpha: 0.15),
      child: const Row(
        children: [
          Icon
          (Icons.warning_amber_rounded, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your cart contains items from multiple shops. '
              'Only items from one shop can be checked out at a time.',
              style: TextStyle(fontSize: 12, color: AppTheme.grey700),
            ),
          ),
        ],
      ),
    );
  }
}
