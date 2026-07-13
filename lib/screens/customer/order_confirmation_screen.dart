import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../models/delivery_type.dart';
import '../../models/payment_method.dart';
import '../../providers/order_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/notification_service.dart';
import '../../services/sms_service.dart';
import '../../utils/app_theme.dart';
import '../../config/app_config.dart';
import '../../constants/order_status.dart';
import '../../services/delivery_charge_calculator.dart';
import '../../services/invoice_service.dart';
import '../../widgets/common/fj_button.dart';
import '../../widgets/common/fj_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/payment_success_animation.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/missing_animations.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String? orderId;
  final String? orderNumber;

  const OrderConfirmationScreen({super.key, this.orderId, this.orderNumber});

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with TickerProviderStateMixin {
  OrderModel? _order;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  final GlobalKey<ParticlesBurstState> _burstKey = GlobalKey();
  final GlobalKey<ConfettiShowerState> _confettiKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _confettiController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _loadOrder();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      OrderModel? order;

      // Try to get order by ID first, then by order number
      if (widget.orderId != null) {
        order = await orderProvider.getOrderById(widget.orderId!);
      } else if (widget.orderNumber != null) {
        // Search in existing orders
        order = orderProvider.orders.firstWhere(
          (o) => o.orderNumber == widget.orderNumber,
          orElse: () => orderProvider.currentOrder!,
        );
      } else {
        // Use current order from provider
        order = orderProvider.currentOrder;
      }

      if (order != null) {
        setState(() {
          _order = order;
          _isLoading = false;
        });

        // Trigger celebration animations
        _scaleController.forward();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _burstKey.currentState?.trigger();
            _confettiKey.currentState?.play();
          }
        });

        // Clear cart and send notification
        _finalizeOrder();
      } else {
        setState(() {
          _errorMessage = 'Order not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load order: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _finalizeOrder() {
    if (!mounted) return;

    // Clear cart
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.clearCart();

    // Send confirmation notification
    final notificationService = NotificationService();
    if (_order != null) {
      notificationService.triggerLocalOrderStatusNotification(_order!.orderNumber, 'Order Placed');

      // Send SMS confirmation
      _sendOrderConfirmationSMS();
    }
  }

  /// Send order confirmation SMS to customer
  ///
  /// [Requirements 4.9]: Send confirmation SMS/notification
  Future<void> _sendOrderConfirmationSMS() async {
    if (_order == null) return;

    try {
      final smsService = SMSService();
      final deliveryDate = DeliveryChargeCalculator.getFormattedDeliveryDate(_order!.deliveryType);

      // Validate phone number
      if (!SMSService.isValidPhoneNumber(_order!.customerPhone)) {
        debugPrint('Invalid phone number format: ${_order!.customerPhone}');
        return;
      }

      // Send SMS
      final success = await smsService.sendOrderConfirmationSMS(
        phoneNumber: _order!.customerPhone,
        orderNumber: _order!.orderNumber,
        estimatedDeliveryDate: deliveryDate,
        totalAmount: _order!.totalAmount.toDouble(),
      );

      if (success) {
        debugPrint('Order confirmation SMS sent successfully');
      } else {
        debugPrint('Failed to send order confirmation SMS');
      }
    } catch (e) {
      debugPrint('Error sending order confirmation SMS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_errorMessage != null) {
      return Center(
        child: FjErrorState(error: _errorMessage!, onRetry: _loadOrder),
      );
    }

    if (_order == null) {
      return const FjEmptyState(
        icon: Icons.search_off,
        title: 'Order Not Found',
        subtitle: "We couldn't find the order you're looking for.",
        actionLabel: 'Go to Home',
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Celebration animation header
              _buildCelebrationHeader(),

              // Wave divider between header and content
              const WaveDivider(color: AppTheme.primary, height: 20),

              // Order details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Payment success animation (for online paid orders)
                    _buildPaymentSuccessSection(),

                    // Success message — springs in
                    SpringCard(
                      delay: const Duration(milliseconds: 100),
                      child: _buildSuccessMessage(),
                    ),
                    const SizedBox(height: 20),

                    // COD delivery OTP
                    SpringCard(delay: const Duration(milliseconds: 160), child: _buildCodOtpCard()),

                    // Order number and status
                    SpringCard(
                      delay: const Duration(milliseconds: 220),
                      child: _buildOrderInfoCard(),
                    ),
                    const SizedBox(height: 12),

                    // Estimated delivery
                    SpringCard(
                      delay: const Duration(milliseconds: 280),
                      child: _buildDeliveryInfoCard(),
                    ),
                    const SizedBox(height: 12),

                    // Order summary
                    SpringCard(
                      delay: const Duration(milliseconds: 340),
                      child: _buildOrderSummaryCard(),
                    ),
                    const SizedBox(height: 12),

                    // Payment info
                    SpringCard(
                      delay: const Duration(milliseconds: 400),
                      child: _buildPaymentInfoCard(),
                    ),
                    const SizedBox(height: 12),

                    // Delivery address
                    SpringCard(
                      delay: const Duration(milliseconds: 460),
                      child: _buildDeliveryAddressCard(),
                    ),
                    const SizedBox(height: 12),

                    // Order status timeline
                    SpringCard(
                      delay: const Duration(milliseconds: 520),
                      child: _buildOrderStatusTimeline(),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    SpringCard(
                      delay: const Duration(milliseconds: 580),
                      child: _buildActionButtons(),
                    ),
                    const SizedBox(height: 16),

                    // Help section
                    SpringCard(
                      delay: const Duration(milliseconds: 640),
                      child: _buildHelpSection(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Confetti overlay
        _buildConfettiOverlay(),
      ],
    );
  }

  // ── COD OTP card ────────────────────────────────────────────────────────
  Widget _buildCodOtpCard() {
    final otp = _order!.otp;
    if (_order!.paymentMethod != PaymentMethod.cod || otp == null || otp.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warning.withOpacity(0.15),
            AppTheme.warning.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline, color: AppTheme.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Delivery Verification OTP',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this 4-digit OTP with the delivery agent upon receiving your order.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: otp.split('').map((digit) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 52,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warning.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  digit,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: otp));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('OTP copied to clipboard')));
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy OTP'),
            ),
          ),
        ],
      ),
    );
  }

  // ── PaymentSuccessAnimation (for paid orders) ────────────────────────────
  Widget _buildPaymentSuccessSection() {
    if (_order == null) return const SizedBox.shrink();
    final isPaid = _order!.paymentStatus == 'paid' || _order!.paymentMethod != PaymentMethod.cod;
    if (!isPaid) return const SizedBox.shrink();
    final delivery = DeliveryChargeCalculator.getFormattedDeliveryDate(_order!.deliveryType);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PaymentSuccessAnimation(
        orderNumber: _order!.orderNumber,
        estimatedDelivery: delivery,
        onViewOrder: () {},
        onContinueShopping: _navigateToHome,
      ),
    );
  }

  // ── WhatsApp share ───────────────────────────────────────────────────────
  Future<void> _shareViaWhatsApp() async {
    if (_order == null) return;
    final items = _order!.items.map((i) => '• ${i.productName} x${i.quantity}').join('\n');
    final message = Uri.encodeComponent(
      "Hi! I just placed an order on Fufaji's Online 🛒\n"
      'Order #: ${_order!.orderNumber}\n'
      'Items:\n$items\n'
      'Total: ₹${_order!.totalAmount.round()}\n'
      'Track: https://fufajionline.com/track/${_order!.orderNumber}',
    );
    final url = Uri.parse('https://wa.me/?text=$message');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('WhatsApp not installed')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e')));
      }
    }
  }

  Widget _buildCelebrationHeader() {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.primary.withOpacity(0.12), Colors.white],
              ),
            ),
          ),
          // Ambient floating bubbles
          const FloatingBubbles(color: AppTheme.primary, count: 8),
          // Animated success icon with particle burst
          Center(
            child: ParticlesBurst(
              key: _burstKey,
              radius: 100,
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(child: AnimatedCheck(size: 90, color: AppTheme.success)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfettiOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ConfettiShower(
          key: _confettiKey,
          count: 70,
          autoPlay: false,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return const Column(
      children: [
        Text(
          'Order Placed Successfully!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Thank you for your order',
          style: TextStyle(fontSize: 14, color: AppTheme.grey600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOrderInfoCard() {
    return FjCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Order #${_order!.orderNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _order!.status.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _order!.status.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _order!.status.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    final formattedDate = DeliveryChargeCalculator.getFormattedDeliveryDate(_order!.deliveryType);

    return FjCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                DeliveryTypeOption.getIcon(_order!.deliveryType),
                color: DeliveryTypeOption.getColor(_order!.deliveryType),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                DeliveryTypeOption.fromType(_order!.deliveryType).name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, color: AppTheme.grey500, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Estimated Delivery: ',
                style: TextStyle(fontSize: 13, color: AppTheme.grey600),
              ),
              Expanded(
                child: Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.local_shipping, color: AppTheme.grey500, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Delivery Charge: ',
                style: TextStyle(fontSize: 13, color: AppTheme.grey600),
              ),
              Text(
                _order!.deliveryCharge.toDouble() == 0
                    ? 'FREE'
                    : '₹${_order!.deliveryCharge.round()}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _order!.deliveryCharge.toDouble() == 0
                      ? AppTheme.success
                      : AppTheme.grey900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return FjCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              const Spacer(),
              Text(
                '${_order!.items.length} items',
                style: const TextStyle(fontSize: 13, color: AppTheme.grey500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._order!.items.map((item) => _buildOrderItemRow(item)),
          const Divider(height: 24),
          _buildPriceRow('Subtotal', _order!.subtotal.toDouble()),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Delivery',
            _order!.deliveryCharge.toDouble(),
            isFree: _order!.deliveryCharge.toDouble() == 0,
          ),
          if (_order!.discount.toDouble() > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow('Discount', -_order!.discount.toDouble(), isDiscount: true),
          ],
          if (_order!.walletAmountUsed.toDouble() > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow('Wallet Used', -_order!.walletAmountUsed.toDouble(), isDiscount: true),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Paid',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Text(
                '₹${_order!.totalAmount.round()}',
                style: const TextStyle(
                  fontSize: 18,
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

  Widget _buildOrderItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.productImage.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.productImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image, color: AppTheme.grey400),
                    ),
                  )
                : const Icon(Icons.image, color: AppTheme.grey400),
          ),
          const SizedBox(width: 12),
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
                if (item.selectedVariant != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.selectedVariant!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Qty: ${item.quantity} × ₹${item.price.round()}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          Text(
            '₹${item.totalPrice.round()}',
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

  Widget _buildPriceRow(
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
          style: TextStyle(fontSize: 13, color: isFree ? AppTheme.success : AppTheme.grey600),
        ),
        Text(
          isDiscount
              ? '- ₹${value.abs().round()}'
              : isFree
              ? 'FREE'
              : '₹${value.round()}',
          style: TextStyle(
            fontSize: 13,
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

  Widget _buildPaymentInfoCard() {
    final paymentMethodName = PaymentMethodOption.getDisplayName(_order!.paymentMethod);
    final paymentMethodOption = PaymentMethodOption.fromMethod(_order!.paymentMethod);

    return FjCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(paymentMethodOption.icon, color: paymentMethodOption.iconColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                paymentMethodName,
                style: const TextStyle(fontSize: 14, color: AppTheme.grey700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: paymentMethodOption.iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _order!.paymentMethod == PaymentMethod.cod ? 'COD' : 'PAID',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: paymentMethodOption.iconColor,
                  ),
                ),
              ),
            ],
          ),
          if (_order!.paymentId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Transaction ID: ',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                ),
                Expanded(
                  child: Text(
                    _order!.paymentId!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_order!.cashbackEarned.toDouble() > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings, color: AppTheme.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'You earned ₹${_order!.cashbackEarned.round()} cashback!',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard() {
    final address = _order!.deliveryAddress;

    return FjCard(
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  address.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.fullAddress,
                      style: const TextStyle(fontSize: 13, color: AppTheme.grey700),
                    ),
                    if (address.landmark.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Landmark: ${address.landmark}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                      ),
                    ],
                    Text(
                      'Pincode: ${address.pincode}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (address.deliveryInstructions != null && address.deliveryInstructions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: AppTheme.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address.deliveryInstructions!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderStatusTimeline() {
    final orderedStatuses = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.processing,
      OrderStatus.packed,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ];

    return FjCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Order Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Order placed step
          _buildTimelineStep(
            icon: Icons.check_circle,
            title: 'Order Placed',
            subtitle: _order?.createdAt != null ? _formatDateTime(_order!.createdAt) : 'Confirmed',
            isCompleted: true,
            isFirst: true,
          ),
          // Show subsequent statuses based on current order status
          ..._buildSubsequentStatusSteps(orderedStatuses),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isFirst,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted ? AppTheme.success.withOpacity(0.1) : AppTheme.grey200,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isCompleted ? AppTheme.success : AppTheme.grey400, size: 18),
            ),
            if (!isFirst)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? AppTheme.success : AppTheme.grey200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? AppTheme.grey900 : AppTheme.grey500,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.grey500)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSubsequentStatusSteps(List<OrderStatus> orderedStatuses) {
    final List<Widget> steps = [];
    final currentStatus = _order?.status ?? OrderStatus.pending;
    final statusHistory = _order?.statusHistory ?? [];

    // Find the index of current status in the ordered list
    final currentIndex = orderedStatuses.indexOf(currentStatus);

    for (int i = 1; i < orderedStatuses.length; i++) {
      final status = orderedStatuses[i];
      final isCompleted = i <= currentIndex;

      // Get timestamp from status history if available
      String subtitle = '';
      final historyEntry = statusHistory.firstWhere(
        (entry) => entry.status == status,
        orElse: () => StatusHistoryEntry(status: status, timestamp: DateTime.now()),
      );
      subtitle = _formatDateTime(historyEntry.timestamp);

      steps.add(
        _buildTimelineStep(
          icon: status.icon,
          title: status.displayName,
          subtitle: subtitle,
          isCompleted: isCompleted,
          isFirst: false,
        ),
      );
    }

    return steps;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateDay == today) {
      return 'Today, ${_formatTime(dateTime)}';
    } else if (dateDay.difference(today).inDays == -1) {
      return 'Yesterday, ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day} ${_getMonthName(dateTime)}, ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _getMonthName(DateTime dateTime) {
    switch (dateTime.month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        FjButton(
          label: 'Track Order',
          onPressed: _navigateToTrackOrder,
          icon: Icons.local_shipping,
          width: double.infinity,
        ),
        const SizedBox(height: 12),

        // Share via WhatsApp
        FjButton(
          label: 'Share via WhatsApp',
          onPressed: _shareViaWhatsApp,
          icon: Icons.share,
          width: double.infinity,
          type: FjButtonType.primary,
          // color: const Color(0xFF25D366), // Needs FjButton override support
        ),
        const SizedBox(height: 12),

        FjButton(
          label: 'Continue Shopping',
          onPressed: _navigateToHome,
          icon: Icons.shopping_bag_outlined,
          width: double.infinity,
          type: FjButtonType.outline,
        ),
      ],
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.grey100, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.headset_mic, color: AppTheme.grey600, size: 20),
              SizedBox(width: 8),
              Text(
                'Need Help?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHelpButton(Icons.chat, 'Chat', _onChatTap),
              _buildHelpButton(Icons.phone, 'Call', _onCallTap),
              _buildHelpButton(Icons.receipt, 'Invoice', _onInvoiceTap),
              _buildHelpButton(Icons.cancel, 'Cancel', _onCancelTap),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.grey600)),
        ],
      ),
    );
  }

  void _navigateToTrackOrder() {
    if (_order != null) {
      context.go('/customer/orders/${_order!.id}/tracking');
    }
  }

  void _navigateToHome() {
    context.go('/customer/home');
  }

  void _onChatTap() {
    if (_order != null) {
      context.push('/customer/support-chat/${_order!.id}');
    } else {
      context.push('/customer/support');
    }
  }

  Future<void> _onCallTap() async {
    final phone = AppConfig.shopPhone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$phone');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Call us at \${AppConfig.shopPhone}')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Call us at \${AppConfig.shopPhone}')));
      }
    }
  }

  void _onInvoiceTap() {
    if (_order != null) {
      InvoiceService().generateAndPrintInvoice(_order!);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order data not available')));
    }
  }

  void _onCancelTap() {
    if (_order != null && _order!.canCancel) {
      _showCancelOrderDialog();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('This order cannot be cancelled')));
    }
  }

  void _showCancelOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 28),
            SizedBox(width: 12),
            Text('Cancel Order?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Order')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
              final success = await orderProvider.cancelOrder(_order!.id, 'Cancelled by customer');
              if (success && context.mounted) {
                context.go('/customer/home');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }
}

/// Custom confetti painter for celebration animation
class ConfettiPainter extends CustomPainter {
  final double animationValue;

  ConfettiPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Generate confetti particles
    final random = DateTime.now().millisecond;
    for (int i = 0; i < 50; i++) {
      final x = (random * (i + 1) % size.width) * animationValue;
      final y = (random * (i + 2) % size.height) * animationValue;
      final color = [
        AppTheme.error,
        AppTheme.success,
        AppTheme.info,
        Colors.yellow,
        Colors.purple,
        AppTheme.warning,
      ][i % 6];

      paint.color = color.withOpacity(1 - animationValue);
      final rect = Rect.fromLTWH(x, y, 8, 8);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Bottom sheet for rating the shopping experience (shown after first order).
class _RateExperienceSheet extends StatefulWidget {
  final String orderId;
  const _RateExperienceSheet({required this.orderId});

  @override
  State<_RateExperienceSheet> createState() => _RateExperienceSheetState();
}

class _RateExperienceSheetState extends State<_RateExperienceSheet> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'How was your experience?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'd love to hear your feedback on your first order!",
            style: TextStyle(fontSize: 13, color: AppTheme.grey600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: star <= _rating ? AppTheme.warning : AppTheme.grey300,
                  size: 40,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rating == 0 ? null : () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip', style: TextStyle(color: AppTheme.grey600)),
          ),
        ],
      ),
    );
  }
}
