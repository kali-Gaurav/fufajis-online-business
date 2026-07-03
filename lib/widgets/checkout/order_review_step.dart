import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/shop_config_provider.dart';
import '../../models/user_model.dart';
import '../../models/delivery_type.dart';
import '../../models/payment_method.dart';
import '../../services/delivery_charge_calculator.dart';
import '../../services/shop_config_service.dart';
import '../../utils/app_theme.dart';

/// Step 3: Order Review Widget
class OrderReviewStep extends StatefulWidget {
  final Address deliveryAddress;
  final PaymentMethod paymentMethod;
  final DeliveryType deliveryType;
  final DateTime? scheduledDeliveryDate;
  final String? timeSlot;
  final VoidCallback onPlaceOrder;
  final VoidCallback onBack;

  const OrderReviewStep({
    super.key,
    required this.deliveryAddress,
    required this.paymentMethod,
    required this.deliveryType,
    this.scheduledDeliveryDate,
    this.timeSlot,
    required this.onPlaceOrder,
    required this.onBack,
  });

  @override
  State<OrderReviewStep> createState() => _OrderReviewStepState();
}

class _OrderReviewStepState extends State<OrderReviewStep> {
  bool _useWallet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      setState(() {
        _useWallet = cartProvider.walletAmountUsed > 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final configProvider = Provider.of<ShopConfigProvider>(context, listen: false);

    final distanceKm =
        locationProvider.distanceFromShopInMeters(
          latitude: widget.deliveryAddress.latitude,
          longitude: widget.deliveryAddress.longitude,
        ) /
        1000.0;

    final branches = configProvider.branches;
    final nearestBranch = ShopConfigService().getNearestBranch(
      widget.deliveryAddress.latitude,
      widget.deliveryAddress.longitude,
      branches,
    );

    final deliveryFee = DeliveryChargeCalculator.calculateDeliveryCharge(
      widget.deliveryType,
      cartProvider.subtotal,
      distanceKm: distanceKm,
      config: configProvider.shopConfig,
      branch: nearestBranch,
    );

    final tax = cartProvider.subtotal * 0.05; // 5% tax
    final walletUsed = _useWallet ? cartProvider.walletAmountUsed : 0;
    final total =
        (cartProvider.subtotal -
                cartProvider.discount +
                deliveryFee +
                cartProvider.tipAmount +
                tax -
                walletUsed)
            .clamp(0.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              color: AppTheme.primary,
            ),
            const Expanded(
              child: Text(
                'Review Order',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Delivery Address Card
        _buildAddressCard(),
        const SizedBox(height: 12),

        // Delivery Type Card
        _buildDeliveryTypeCard(deliveryFee),
        const SizedBox(height: 12),

        // Order Items Card
        _buildItemsCard(cartProvider),
        const SizedBox(height: 12),

        // Payment Method Card
        _buildPaymentMethodCard(),
        const SizedBox(height: 12),

        // Wallet Toggle
        _buildWalletSection(orderProvider, cartProvider),
        const SizedBox(height: 12),

        // Price Summary Card
        _buildPriceSummary(cartProvider, deliveryFee, total),
        const SizedBox(height: 24),

        // Place Order Button
        ElevatedButton(
          onPressed: widget.onPlaceOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            'Place Order - ₹${total.round()}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.deliveryAddress.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          Text(
            widget.deliveryAddress.fullAddress,
            style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
          ),
          if (widget.deliveryAddress.landmark.isNotEmpty)
            Text(
              'Landmark: ${widget.deliveryAddress.landmark}',
              style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
            ),
          Text(
            'Pincode: ${widget.deliveryAddress.pincode}',
            style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTypeCard(double charge) {
    final formattedDate = DeliveryChargeCalculator.getFormattedDeliveryDate(widget.deliveryType);

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Delivery Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.deliveryType.displayName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Text(
                charge == 0 ? 'FREE' : '₹${charge.round()}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: charge == 0 ? AppTheme.success : AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, color: AppTheme.grey500, size: 14),
              const SizedBox(width: 4),
              Text(
                widget.deliveryType == DeliveryType.scheduled &&
                        widget.scheduledDeliveryDate != null
                    ? 'Scheduled: ${_formatDate(widget.scheduledDeliveryDate!)} (${widget.timeSlot ?? "Anytime"})'
                    : 'Estimated delivery: $formattedDate',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildItemsCard(CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Items (${cartProvider.totalItems})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Edit Cart', style: TextStyle(color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...cartProvider.cartItems.take(3).map((item) => _buildItemRow(item)),
          if (cartProvider.cartItems.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${cartProvider.cartItems.length - 3} more items',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic cartItem) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: cartItem.productImage.isNotEmpty
                ? Image.network(cartItem.productImage, fit: BoxFit.cover)
                : const Icon(Icons.image, color: AppTheme.grey400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.productName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${cartItem.quantity} × ₹${cartItem.price.round()}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          Text(
            '₹${cartItem.totalPrice.round()}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    final methodName = widget.paymentMethod.toString().split('.').last;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          const Icon(Icons.payment, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Payment',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const Spacer(),
          Text(
            methodName.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSection(OrderProvider orderProvider, CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: SwitchListTile(
        value: _useWallet,
        onChanged: (value) {
          setState(() {
            _useWallet = value;
            if (_useWallet) {
              final double orderTotalBeforeWallet =
                  cartProvider.subtotal +
                  cartProvider.deliveryCharge +
                  cartProvider.tipAmount -
                  cartProvider.discount;
              final double maxWalletUse = orderTotalBeforeWallet * 0.5;
              final double amountToUse = orderProvider.walletBalance < maxWalletUse
                  ? orderProvider.walletBalance
                  : maxWalletUse;
              cartProvider.setWalletAmount(amountToUse, orderProvider.walletBalance);
            } else {
              cartProvider.setWalletAmount(0.0, orderProvider.walletBalance);
            }
          });
        },
        title: const Text('Use Wallet Balance'),
        subtitle: Text('Available: ₹${orderProvider.walletBalance.round()}'),
        activeThumbColor: AppTheme.primary,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPriceSummary(CartProvider cartProvider, double deliveryFee, double total) {
    final tax = cartProvider.subtotal * 0.05; // 5% tax
    final walletUsed = _useWallet ? cartProvider.walletAmountUsed : 0;

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Subtotal', cartProvider.subtotal),
          const SizedBox(height: 8),
          _buildSummaryRow('Delivery', deliveryFee, isFree: deliveryFee == 0),
          const SizedBox(height: 8),
          _buildSummaryRow('Tax (5%)', tax),
          if (cartProvider.discount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow('Discount', -cartProvider.discount, isDiscount: true),
          ],
          if (walletUsed > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow('Wallet Used', -walletUsed.toDouble(), isDiscount: true),
          ],
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
              Text(
                '₹${total.round()}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isFree = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: isFree ? AppTheme.success : AppTheme.grey600),
        ),
        Text(
          isDiscount
              ? '- ₹${value.abs().round()}'
              : isFree
              ? 'FREE'
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
}
