import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/supabase_config.dart';
import 'package:go_router/go_router.dart';
import '../../constants/order_status.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/user_model.dart';
import '../../models/delivery_type.dart';
import '../../models/payment_method.dart';
import '../../models/order_model.dart';
import '../../services/weather_service.dart';
import '../../services/upi_payment_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/monetary_value.dart';
import '../../widgets/checkout/checkout_step_indicator.dart';
import '../../widgets/checkout/address_selection_step.dart';
import '../../widgets/checkout/payment_method_step.dart';
import '../../widgets/checkout/order_review_step.dart';
import '../../widgets/delivery_type_selector.dart';
import '../../providers/location_provider.dart';
import '../../providers/shop_config_provider.dart';
import '../../services/shop_config_service.dart';
import '../../services/razorpay_service.dart';
import 'checkout_auth_sheet.dart';
import 'payment_verification_dialog.dart';

import '../../services/billing_service.dart';
import '../../services/notification_retry_service.dart';
import '../../widgets/trust/fj_trust_banner.dart';
import '../../widgets/missing_animations.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Stepper state
  int _currentStep = 0;
  final int _totalSteps = 3;

  // Step 1: Address selection
  Address? _selectedAddress;
  DeliveryType _selectedDeliveryType = DeliveryType.standard;

  // Step 2: Payment method
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cod;

  String? _voiceLandmarkPath;

  DateTime? _scheduledDeliveryDate;
  String? _selectedTimeSlot;

  DateTime _getToday() {
    final nowUtc = DateTime.now().toUtc();
    return nowUtc.add(const Duration(hours: 5, minutes: 30));
  }

  List<DateTime> _getAvailableDates() {
    final today = _getToday();
    return [
      DateTime(today.year, today.month, today.day),
      DateTime(today.year, today.month, today.day).add(const Duration(days: 1)),
      DateTime(today.year, today.month, today.day).add(const Duration(days: 2)),
    ];
  }

  List<String> _getAvailableTimeSlots() {
    return ['9 AM - 12 PM', '12 PM - 3 PM', '3 PM - 6 PM', '6 PM - 9 PM'];
  }

  WeatherAlert? _weatherAlert;
  String? _stableOrderId;
  String? _stableOrderNumber;
  bool _isPlacingOrder = false;

  final List<String> _stepTitles = ['Address', 'Payment', 'Review'];

  @override
  void initState() {
    super.initState();
    _loadWeather();
    UpiPaymentService.init();
  }

  Future<void> _loadWeather() async {
    final alert = await WeatherService.getCurrentWeather();
    if (mounted) {
      setState(() => _weatherAlert = alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        centerTitle: true,
      ),
      body: paymentProvider.isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LiquidProgressBar(value: 0.6, width: 200, height: 12, color: AppTheme.primary),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 20),
                  Text(
                    'Processing Payment...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please do not press back',
                    style: TextStyle(color: AppTheme.grey500, fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Step indicator
                CheckoutStepIndicator(
                  currentStep: _currentStep,
                  totalSteps: _totalSteps,
                  stepTitles: _stepTitles,
                ),
                const Divider(height: 1),

                // Weather warning banner
                if (_weatherAlert != null && _weatherAlert!.hasWarning)
                  _buildWeatherWarningBanner(),

                // Step content with animated crossfade
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slideAnim = Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slideAnim, child: child),
                      );
                    },
                    child: SingleChildScrollView(
                      key: ValueKey(_currentStep),
                      padding: const EdgeInsets.all(16),
                      child: _buildStepContent(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWeatherWarningBanner() {
    final alert = _weatherAlert!;
    final isExtreme = alert.condition == 'Thunderstorm' || alert.condition == 'Tornado';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExtreme
              ? [const Color(0xFFD32F2F), const Color(0xFFFF5252)]
              : [AppTheme.primary, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isExtreme ? Icons.warning_amber_rounded : Icons.cloud,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExtreme ? 'Severe Weather Alert' : 'Weather Advisory',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  alert.warningMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _weatherAlert = null),
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildAddressStep();
      case 1:
        return _buildPaymentStep();
      case 2:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAddressStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Weather warning
        if (_weatherAlert != null && _weatherAlert!.hasWarning) _buildWeatherWarningBanner(),

        // Delivery type selector
        _buildDeliveryTypeSection(),

        _buildScheduledPickerSection(),

        const SizedBox(height: 16),

        // Address selection step
        AddressSelectionStep(
          selectedAddress: _selectedAddress,
          onAddressSelected: (address) {
            setState(() => _selectedAddress = address);
          },
          onVoiceLandmarkRecorded: (path) {
            setState(() => _voiceLandmarkPath = path);
          },
          onContinue: () {
            if (_selectedAddress != null) {
              final locationProvider = Provider.of<LocationProvider>(context, listen: false);
              if (!locationProvider.isAddressWithinDeliveryRadius(_selectedAddress!)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(locationProvider.deliveryZoneMessageFor(_selectedAddress!)),
                    backgroundColor: AppTheme.error,
                  ),
                );
                return;
              }
              setState(() => _currentStep = 1);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryTypeSection() {
    final cartProvider = Provider.of<CartProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: DeliveryTypeSelector(
        selectedType: _selectedDeliveryType,
        subtotal: cartProvider.subtotal,
        onTypeSelected: (type) {
          setState(() => _selectedDeliveryType = type);
        },
      ),
    );
  }

  Widget _buildScheduledPickerSection() {
    if (_selectedDeliveryType != DeliveryType.scheduled) {
      return const SizedBox.shrink();
    }

    final dates = _getAvailableDates();
    final slots = _getAvailableTimeSlots();

    // Default selection if null
    _scheduledDeliveryDate ??= dates.first;
    _selectedTimeSlot ??= slots.first;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Delivery Date & Time Slot',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 12),
          // Date selector row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dates.map((date) {
              final isSelected =
                  _scheduledDeliveryDate != null &&
                  _scheduledDeliveryDate!.year == date.year &&
                  _scheduledDeliveryDate!.month == date.month &&
                  _scheduledDeliveryDate!.day == date.day;

              final label = date.day == _getToday().day
                  ? 'Today'
                  : date.day == _getToday().add(const Duration(days: 1)).day
                  ? 'Tomorrow'
                  : '${date.day} ${_getMonthName(date.month)}';

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _scheduledDeliveryDate = date;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withOpacity(0.08)
                          : AppTheme.grey100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.grey300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.primary : AppTheme.grey700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Time Slot choices
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              final isSelected = _selectedTimeSlot == slot;
              return ChoiceChip(
                label: Text(slot),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedTimeSlot = slot;
                    });
                  }
                },
                selectedColor: AppTheme.primary.withOpacity(0.15),
                backgroundColor: AppTheme.grey100,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.grey800,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.grey300),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  // P0 FIX: Delivery Confidence Card — shows ETA, fee, guarantee
  Widget _buildDeliveryConfidenceCard() {
    final isExpress = _selectedDeliveryType == DeliveryType.express;
    final eta = isExpress ? '10–30 minutes' : '30–60 minutes';
    final cartProvider = Provider.of<CartProvider>(context);
    final deliveryFee = cartProvider.deliveryCharge == 0
        ? 'FREE'
        : '₹${cartProvider.deliveryCharge.round()}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.success.withOpacity(0.05),
            AppTheme.primary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, color: AppTheme.success, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delivery Confidence',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ETA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppTheme.grey600),
                  const SizedBox(width: 8),
                  Text(
                    'ETA',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.grey600),
                  ),
                ],
              ),
              Text(
                eta,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.grey900),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Delivery Fee
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments, size: 16, color: AppTheme.grey600),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Fee',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.grey600),
                  ),
                ],
              ),
              Text(
                deliveryFee,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cartProvider.deliveryCharge == 0 ? AppTheme.success : AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Guarantee
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, size: 16, color: AppTheme.success),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fufaji Guarantee: Fresh on arrival or money back',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
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

  Widget _buildPaymentStep() {
    return PaymentMethodStep(
      selectedMethod: _selectedPaymentMethod,
      onMethodSelected: (method) {
        setState(() => _selectedPaymentMethod = method);
      },
      onContinue: () {
        setState(() => _currentStep = 2);
      },
      onBack: () {
        setState(() => _currentStep = 0);
      },
    );
  }

  Widget _buildReviewStep() {
    if (_selectedAddress == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            const Text('Please select a delivery address'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Go to Address'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // P0 FIX: Add Trust Layer to Checkout
        const FufajiTrustBanner(),
        const SizedBox(height: 16),

        // P0 FIX: Add Delivery Confidence Card
        _buildDeliveryConfidenceCard(),
        const SizedBox(height: 16),

        OrderReviewStep(
          deliveryAddress: _selectedAddress!,
          paymentMethod: _selectedPaymentMethod,
          deliveryType: _selectedDeliveryType,
          scheduledDeliveryDate: _scheduledDeliveryDate,
          timeSlot: _selectedTimeSlot,
          onPlaceOrder: () => _placeOrder(),
          onBack: () {
            setState(() => _currentStep = 1);
          },
        ),
        const SizedBox(height: 16),
        _buildAIRecommendationsSection(),
      ],
    );
  }

  Widget _buildAIRecommendationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200, width: 1),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.teal, size: 18),
              SizedBox(width: 8),
              Text(
                'Fufaji\'s Smart Grocery Assistant',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Based on your cart items, did you forget to add "Fresh Coriander Leaves" or "Lemon"? Most families buy these together!',
            style: TextStyle(fontSize: 11, color: AppTheme.grey700),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (_isPlacingOrder) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => CheckoutAuthSheet(
          onSuccess: () {
            // After auth success, wait a frame and retry placing order
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _placeOrder();
            });
          },
        ),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (_selectedAddress == null) {
      setState(() => _isPlacingOrder = false);
      return;
    }

    try {
      final userId = user?.id ?? 'user_001';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _stableOrderId ??= 'ord_${userId}_$timestamp';
      _stableOrderNumber ??= 'ORD$timestamp';

      try {
        final doc = await SupabaseConfig.client
            .from('orders')
            .select('id')
            .eq('id', _stableOrderId!)
            .maybeSingle();
        if (doc != null) {
          cartProvider.clearCart();
          if (mounted) {
            context.go(
              '/customer/order-confirmation?orderId=$_stableOrderId&orderNumber=$_stableOrderNumber',
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error recovering order state: $e');
      }

      if (!mounted) return;
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final configProvider = Provider.of<ShopConfigProvider>(context, listen: false);

      final distanceKm =
          locationProvider.distanceFromShopInMeters(
            latitude: _selectedAddress!.latitude,
            longitude: _selectedAddress!.longitude,
          ) /
          1000.0;

      final branches = configProvider.branches;
      final nearestBranch = ShopConfigService().getNearestBranch(
        _selectedAddress!.latitude,
        _selectedAddress!.longitude,
        branches,
      );

      final billing = BillingService.calculateBill(
        items: cartProvider.cartItems
            .map(
              (item) => OrderItem(
                id: item.id,
                productId: item.productId,
                productName: item.productName,
                productImage: item.productImage,
                unit: item.unit,
                quantity: item.quantity,
                price: item.price,
                originalPrice: item.originalPrice,
                discountPercentage: item.discountPercentage,
                totalPrice: item.totalPrice,
                shopId: item.shopId,
                shopName: item.shopName,
              ),
            )
            .toList(),
        deliveryType: _selectedDeliveryType,
        config: configProvider.shopConfig!,
        branch: nearestBranch,
        distanceKm: distanceKm,
        couponDiscount: cartProvider.discount,
      );

      final order = OrderModel(
        id: _stableOrderId!,
        orderNumber: _stableOrderNumber!,
        customerId: userId,
        customerName: user?.name ?? 'Customer',
        customerPhone: user?.phoneNumber ?? '',
        items: billing.items,
        subtotal: MonetaryValue(billing.subtotal),
        deliveryCharge: MonetaryValue(billing.deliveryCharge),
        tax: MonetaryValue(billing.tax),
        // FIX (Module 6, P1-6.3): persist which coupon was used and how much
        // it discounted — previously orders never recorded this, making
        // coupon redemption untrackable and usage limits unenforceable.
        discount: MonetaryValue(cartProvider.discount),
        couponCode: cartProvider.appliedCoupon?.code,
        couponDiscount: cartProvider.appliedCoupon != null
            ? MonetaryValue(cartProvider.discount)
            : null,
        walletAmountUsed: MonetaryValue(cartProvider.walletAmountUsed),
        totalAmount: MonetaryValue(billing.grandTotal),
        paymentMethod: _selectedPaymentMethod,
        selectedPaymentMethod: _selectedPaymentMethod,
        deliveryType: _selectedDeliveryType,
        deliveryAddress: _selectedAddress!,
        voiceLandmarkUrl: _voiceLandmarkPath,
        scheduledDeliveryDate: _selectedDeliveryType == DeliveryType.scheduled
            ? _scheduledDeliveryDate
            : null,
        timeSlot: _selectedDeliveryType == DeliveryType.scheduled ? _selectedTimeSlot : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_selectedPaymentMethod == PaymentMethod.cod) {
        // Generate a 4-digit delivery verification OTP
        final otp = (1000 + Random().nextInt(9000)).toString();
        final codOrder = order.copyWith(otp: otp, paymentStatus: 'pending');
        await orderProvider.createOrder(codOrder);
        // NOTE: COD cashback is awarded on delivery confirmation (not here)
        // to prevent abuse. The delivery_detail_screen triggers cashback
        // when the rider marks the order as delivered.
        cartProvider.clearCart();
        if (mounted) {
          context.go(
            '/customer/order-confirmation?orderId=${codOrder.id}&orderNumber=${codOrder.orderNumber}',
          );
        }
      } else if (_selectedPaymentMethod == PaymentMethod.credit) {
        final success = await paymentProvider.processCreditPayment(
          order.totalAmount.toDouble(),
          user!,
          authProvider,
        );
        if (success) {
          await orderProvider.createOrder(order);
          cartProvider.clearCart();
          if (mounted) {
            context.go(
              '/customer/order-confirmation?orderId=${order.id}&orderNumber=${order.orderNumber}',
            );
          }
        } else {
          if (mounted) {
            setState(() => _isPlacingOrder = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(paymentProvider.errorMessage ?? 'Credit check failed')),
            );
          }
        }
      } else if (_selectedPaymentMethod == PaymentMethod.razorpay) {
        // 1. Create the pending order locally first
        final pendingOrder = order.copyWith(status: OrderStatus.pending, paymentStatus: 'pending');
        await orderProvider.createOrder(pendingOrder);

        // 2. Launch Razorpay flow
        final rzpService = RazorpayService();
        rzpService.initialize(
          onSuccess: (response) async {
            rzpService.dispose();
            if (mounted) {
              setState(() => _isPlacingOrder = false);
              // 3. Show dialog to poll for webhook verification
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => PaymentVerificationDialog(
                  orderId: pendingOrder.id,
                  orderNumber: pendingOrder.orderNumber,
                ),
              );
            }
          },
          onFailure: (response) async {
            rzpService.dispose();
            if (mounted) {
              setState(() => _isPlacingOrder = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response.userFriendlyMessage),
                  backgroundColor: AppTheme.error,
                ),
              );
            }
          },
          onExternalWallet: (response) {
            // External wallet selected – create pending order and confirm later
          },
        );
        rzpService.createOrder(
          amount: order.totalAmount.toDouble(),
          orderId: pendingOrder.id,
          customerId: user?.id ?? '',
          customerPhone: user?.phoneNumber ?? '',
          customerName: user?.name ?? 'Customer',
          customerEmail: user?.email ?? 'customer@fufajionline.com',
        );
        // Return here; callbacks above will handle navigation
        return;
      } else if (_selectedPaymentMethod == PaymentMethod.upi) {
        final upiUri = UpiPaymentService.generateUpiUri(
          orderId: order.orderNumber,
          amount: order.totalAmount.toDouble(),
          note: 'Fufaji Store Order ${order.orderNumber}',
        );
        final launched = await UpiPaymentService.launchUpiIntent(upiUri);
        if (launched) {
          final pendingOrder = order.copyWith(status: OrderStatus.pending);
          await orderProvider.createOrder(pendingOrder);
          cartProvider.clearCart();
          if (mounted) {
            context.go(
              '/customer/order-confirmation?orderId=${pendingOrder.id}&orderNumber=${pendingOrder.orderNumber}',
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch UPI app. Please try another method.')),
            );
          }
        }
      } else if (_selectedPaymentMethod == PaymentMethod.wallet) {
        if (walletProvider.walletBalance < order.totalAmount.toDouble()) {
          setState(() => _isPlacingOrder = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Insufficient wallet balance')));
          return;
        }
        // FIX (Module 7 P0): route through the canonical OrderService.createOrder
        // path instead of WalletProvider.payWithWalletAndCreateOrder, which created
        // orders without ever deducting product stock. OrderService.createOrder's
        // transaction debits the wallet (walletAmountUsed) AND deducts stock
        // atomically, so setting walletAmountUsed to the full total here gets both
        // for free via the same path every other payment method already uses.
        final walletOrder = order.copyWith(
          status: OrderStatus.confirmed,
          paymentStatus: 'wallet_paid',
          walletAmountUsed: order.totalAmount,
        );
        final createdOrder = await orderProvider.createOrder(walletOrder);
        if (createdOrder != null) {
          // Cashback on wallet payment is awarded after delivery (not here)
          cartProvider.clearCart();
          if (mounted) {
            context.go(
              '/customer/order-confirmation?orderId=${createdOrder.id}&orderNumber=${createdOrder.orderNumber}',
            );
          }
        } else {
          try {
            await NotificationRetryService().triggerAdminAlert(
              type: 'payment_failure',
              severity: 'high',
              title: 'Wallet Payment Failed',
              description:
                  'Wallet payment for user ${user?.id ?? "unknown"} of ₹${order.totalAmount.toStringAsFixed(0)} failed during transaction.',
            );
          } catch (e) {
            debugPrint('Error logging wallet failure alert: $e');
          }
          if (mounted) {
            setState(() => _isPlacingOrder = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order creation failed. Please try again.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }
}
