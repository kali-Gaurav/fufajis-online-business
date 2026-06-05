import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/payment_method.dart';
import '../../utils/app_theme.dart';
import '../../providers/payment_provider.dart';

class FastCheckoutScreen extends StatefulWidget {
  const FastCheckoutScreen({super.key});

  @override
  State<FastCheckoutScreen> createState() => _FastCheckoutScreenState();
}

class _FastCheckoutScreenState extends State<FastCheckoutScreen> {
  bool _isProcessing = false;
  Address? _selectedAddress;
  PaymentMethod _paymentMethod = PaymentMethod.cod;
  String? _stableOrderId;
  String? _stableOrderNumber;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
    
    // Feature 20: Smart Coupon Optimizer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().autoOptimizeCoupons();
    });
  }

  Future<void> _loadDefaults() async {
    final auth = context.read<AuthProvider>();
    final addresses = await auth.getAddresses();
    if (addresses.isNotEmpty && mounted) {
      setState(() {
        _selectedAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
      });
    }
  }

  Future<void> _handlePlaceOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a delivery address')));
      return;
    }

    setState(() => _isProcessing = true);

    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final orderProvider = context.read<OrderProvider>();

    final userId = auth.currentUser?.id ?? 'user_001';
    final userEmail = auth.currentUser?.email ?? 'customer@fufajionline.com';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _stableOrderId ??= 'ord_${userId}_$timestamp';
    _stableOrderNumber ??= auth.generateOrderNumber();

    final order = OrderModel(
      id: _stableOrderId!,
      orderNumber: _stableOrderNumber!,
      customerId: userId,
      customerName: auth.currentUser?.name ?? 'Customer',
      customerPhone: auth.currentUser?.phoneNumber ?? '',
      shopId: cart.cartItems.first.shopId,
      shopName: cart.cartItems.first.shopName,
      items: cart.cartItems.map((item) => OrderItem(
        id: item.id,
        productId: item.productId,
        productName: item.productName,
        productImage: item.productImage,
        quantity: item.quantity,
        price: item.price,
        unit: item.unit,
        shopId: item.shopId,
        totalPrice: item.totalPrice,
      )).toList(),
      subtotal: cart.subtotal,
      deliveryCharge: cart.deliveryCharge,
      discount: cart.discount,
      tipAmount: cart.tipAmount,
      walletAmountUsed: cart.walletAmountUsed,
      totalAmount: cart.total,
      deliveryAddress: _selectedAddress!,
      paymentMethod: _paymentMethod,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (_paymentMethod == PaymentMethod.upi) {
        final finalizedOrder = await orderProvider.checkoutOnline(
          order: order,
          email: userEmail,
          onPaymentStarted: () => setState(() => _isProcessing = true),
          onPaymentError: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error))),
        );

        if (finalizedOrder != null && mounted) {
           cart.clearCart();
           context.go('/customer/order-confirmation?orderId=${finalizedOrder.id}&orderNumber=${finalizedOrder.orderNumber}');
        }
      } else if (_paymentMethod == PaymentMethod.credit) {
        // Fufaji Credit Path
        final paymentProvider = context.read<PaymentProvider>();
        final success = await paymentProvider.processCreditPayment(
          order.totalAmount,
          auth.currentUser!,
          auth,
        );
        if (success) {
          await orderProvider.createOrder(order.copyWith(status: OrderStatus.confirmed));
          cart.clearCart();
          if (mounted) {
            context.go('/customer/order-confirmation?orderId=${order.id}&orderNumber=${order.orderNumber}');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(paymentProvider.errorMessage ?? 'Credit check failed')),
            );
          }
        }
      } else {
        // COD path
        await orderProvider.createOrder(order.copyWith(status: OrderStatus.confirmed));
        cart.clearCart();
        if (mounted) {
          context.go('/customer/order-confirmation?orderId=${order.id}&orderNumber=${order.orderNumber}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUICK BOOK', style: TextStyle(fontWeight: FontWeight.w900)),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('STEP 2 OF 3', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ],
      ),
      body: _isProcessing 
        ? const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Securing your order...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          const Text(
                            'ORDER SUMMARY',
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                          ),
                          const Spacer(),
                          Text(
                            '₹${cart.total.round()}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      ...cart.cartItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Text('${item.quantity}x ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                            Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 14))),
                            Text('₹${item.totalPrice.round()}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                      const Divider(height: 24),
                      _buildPriceRow('Items Subtotal', '₹${cart.subtotal.round()}'),
                      if (cart.deliveryCharge > 0)
                        _buildPriceRow('Delivery Charge', '₹${cart.deliveryCharge.round()}'),
                      if (cart.discount > 0)
                        _buildPriceRow('Coupon Discount', '-₹${cart.discount.round()}', isDiscount: true),
                      if (cart.tipAmount > 0)
                        _buildPriceRow('Rider Tip', '₹${cart.tipAmount.round()}'),
                      if (cart.walletAmountUsed > 0)
                        _buildPriceRow('Wallet Balance Used', '-₹${cart.walletAmountUsed.round()}', isDiscount: true),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          Text('₹${cart.total.round()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Delivery Section
                const Text('Deliver to', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.push('/customer/addresses'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.grey200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.primary, size: 30),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _selectedAddress == null 
                            ? const Text('Add delivery address', style: TextStyle(color: AppTheme.error))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_selectedAddress!.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(_selectedAddress!.fullAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
                                ],
                              ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.grey400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 24),

                // Feature 24: Rider Tipping
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Rider Tip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (cart.tipAmount > 0) 
                      Text('₹${cart.tipAmount.round()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [10, 20, 50, 100].map((amount) {
                    final isSelected = cart.tipAmount == amount.toDouble();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () => cart.setTipAmount(isSelected ? 0 : amount.toDouble()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.grey200),
                            ),
                            child: Center(
                              child: Text(
                                '₹$amount',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.grey900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Payment Section
                const Text('Payment Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildPaymentOption(PaymentMethod.upi, 'UPI (GPay / PhonePe)', Icons.account_balance_wallet_outlined),
                const SizedBox(height: 8),
                _buildPaymentOption(PaymentMethod.cod, 'Cash on Delivery', Icons.money),
                const SizedBox(height: 8),
                _buildPaymentOption(PaymentMethod.credit, 'Fufaji Credit (Khata)', Icons.menu_book),
                
                const SizedBox(height: 100), // Space for button
              ],
            ),
          ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handlePlaceOrder,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, foregroundColor: Colors.white),
            child: const Text('STEP 3: PLACE ORDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isDiscount ? FontWeight.bold : FontWeight.w600,
              color: isDiscount ? Colors.green : Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(PaymentMethod method, String label, IconData icon) {
    final isSelected = _paymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.grey200),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.grey600),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
            if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
