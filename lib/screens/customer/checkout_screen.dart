import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
import '../../widgets/checkout/checkout_step_indicator.dart';
import '../../widgets/checkout/address_selection_step.dart';
import '../../widgets/checkout/payment_method_step.dart';
import '../../widgets/checkout/order_review_step.dart';
import '../../widgets/checkout/order_confirmation_step.dart';
import '../../widgets/delivery_type_selector.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Stepper state
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1: Address selection
  Address? _selectedAddress;
  DeliveryType _selectedDeliveryType = DeliveryType.standard;

  // Step 2: Payment method
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cod;
  
  String? _voiceLandmarkPath;

  // Step 4: Confirmation
  OrderModel? _confirmedOrder;

  WeatherAlert? _weatherAlert;

  final List<String> _stepTitles = ['Address', 'Payment', 'Review', 'Confirm'];

  @override
  void initState() {
    super.initState();
    _loadWeather();
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
        title: Text(_currentStep < 3 ? 'Checkout' : 'Order Confirmed'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
      ),
      body: paymentProvider.isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing Payment...'),
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

                // Step content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildStepContent(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWeatherWarningBanner() {
    final alert = _weatherAlert!;
    final isExtreme =
        alert.condition == 'Thunderstorm' || alert.condition == 'Tornado';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExtreme
              ? [const Color(0xFFD32F2F), const Color(0xFFFF5252)]
              : [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
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
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
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
      case 3:
        return _buildConfirmationStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAddressStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Weather warning
        if (_weatherAlert != null && _weatherAlert!.hasWarning)
          _buildWeatherWarningBanner(),

        // Delivery type selector
        _buildDeliveryTypeSection(),

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
            color: AppTheme.black.withValues(alpha: 0.05),
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

    return OrderReviewStep(
      deliveryAddress: _selectedAddress!,
      paymentMethod: _selectedPaymentMethod,
      deliveryType: _selectedDeliveryType,
      onPlaceOrder: () => _placeOrder(),
      onBack: () {
        setState(() => _currentStep = 1);
      },
    );
  }

  Widget _buildConfirmationStep() {
    if (_confirmedOrder == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return OrderConfirmationStep(
      order: _confirmedOrder!,
      onTrackOrder: () {
        context.go('/customer/orders');
      },
      onContinueShopping: () {
        context.go('/customer/home');
      },
    );
  }

  Future<void> _placeOrder() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (_selectedAddress == null) return;

    try {
      // 1. Create order initial document
      final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      final order = OrderModel(
        id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
        orderNumber: orderNumber,
        customerId: user?.id ?? 'user_001',
        customerName: user?.name ?? 'Customer',
        customerPhone: user?.phoneNumber ?? '',
        items: cartProvider.cartItems
            .map((item) => OrderItem(
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
                ))
            .toList(),
        subtotal: cartProvider.subtotal,
        deliveryCharge:
            _selectedDeliveryType == DeliveryType.express ? 50.0 : 0.0,
        totalAmount: cartProvider.total +
            (_selectedDeliveryType == DeliveryType.express ? 50.0 : 0.0),
        paymentMethod: _selectedPaymentMethod,
        deliveryType: _selectedDeliveryType,
        deliveryAddress: _selectedAddress!,
        voiceLandmarkUrl: _voiceLandmarkPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 2. Handle Payment logic
      if (_selectedPaymentMethod == PaymentMethod.cod) {
        await orderProvider.createOrder(order);

        // Add cashback if any
        await walletProvider.addCashback(
            user?.id ?? 'user_001', order.totalAmount, order.id);

        setState(() {
          _confirmedOrder = order;
          _currentStep = 3;
        });
        cartProvider.clearCart();
      } else if (_selectedPaymentMethod == PaymentMethod.credit) {
        final success = await paymentProvider.processCreditPayment(
            order.totalAmount, user!, authProvider);
        if (success) {
          await orderProvider.createOrder(order);
          setState(() {
            _confirmedOrder = order;
            _currentStep = 3;
          });
          cartProvider.clearCart();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(paymentProvider.errorMessage ?? 'Credit check failed')));
        }
      } else if (_selectedPaymentMethod == PaymentMethod.razorpay) {
        // Init Razorpay callbacks
        paymentProvider.onPaymentSuccess = (response) async {
          final paidOrder = order.copyWith(
              paymentId: response.paymentId, status: OrderStatus.confirmed);
          await orderProvider.createOrder(paidOrder);
          setState(() {
            _confirmedOrder = paidOrder;
            _currentStep = 3;
          });
          cartProvider.clearCart();
        };

        paymentProvider.startRazorpayPayment(
          amount: order.totalAmount,
          orderId: order.id,
          user: user!,
        );
      } else if (_selectedPaymentMethod == PaymentMethod.upi) {
        final upiUri = UpiPaymentService.generateUpiUri(
          orderId: order.orderNumber,
          amount: order.totalAmount,
          note: 'Fufaji Store Order ${order.orderNumber}',
        );
        
        final launched = await UpiPaymentService.launchUpiIntent(upiUri);
        
        if (launched) {
          // SECURE UPDATE: Instead of immediate success, we wait for backend verification.
          // We show a loading/verifying state.
          setState(() {
            _currentStep = 3; // Move to confirmation step
            _confirmedOrder = order.copyWith(status: OrderStatus.pending); // Mark as pending
          });
          
          cartProvider.clearCart();
          
          // The OrderConfirmationStep will now handle the "Verifying..." UI 
          // based on the order status being 'pending' instead of 'confirmed'.
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch UPI app. Please try another method.')),
          );
        }
      } else if (_selectedPaymentMethod == PaymentMethod.wallet) {
        if (walletProvider.walletBalance < order.totalAmount) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Insufficient wallet balance')));
          return;
        }

        final success = await walletProvider.payWithWallet(
            userId: user!.id,
            orderAmount: order.totalAmount,
            orderId: order.id);

        if (success) {
          final paidOrder = order.copyWith(status: OrderStatus.confirmed);
          await orderProvider.createOrder(paidOrder);

          // Add cashback if any
          await walletProvider.addCashback(
              user.id, order.totalAmount, order.id);

          setState(() {
            _confirmedOrder = paidOrder;
            _currentStep = 3;
          });
          cartProvider.clearCart();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Failed to process wallet payment')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Checkout error: $e')));
    }
  }
}
