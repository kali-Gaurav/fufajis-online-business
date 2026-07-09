import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../providers/checkout_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/models/customer_address.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _currentStep = 0;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Payment succeeded, the backend webhook will confirm the order.
    // We navigate to success screen.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: response.orderId ?? 'Processing...')),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Failed: ${response.message}'), backgroundColor: Colors.red),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet Selected: ${response.walletName}')),
    );
  }

  Future<void> _submitOrder() async {
    final state = ref.read(checkoutProvider);
    try {
      final response = await ref.read(checkoutProvider.notifier).submitCheckout();
      final paymentInfo = response['payment'];

      if (paymentInfo['provider'] == 'COD') {
        // Direct success
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: paymentInfo['order_id'])),
          );
        }
      } else if (paymentInfo['provider'] == 'RAZORPAY') {
        // Launch Razorpay Checkout
        var options = {
          'key': paymentInfo['key_id'],
          'amount': paymentInfo['amount'],
          'name': 'Fufaji Online',
          'description': 'Order Payment',
          'order_id': paymentInfo['order_id'],
          'prefill': {
            'contact': state.selectedAddress?.phone ?? '',
          },
          'theme': {
            'color': '#3399cc'
          }
        };
        _razorpay.open(options);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutProvider);
    final profileState = ref.watch(profileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: checkoutState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0) {
                  setState(() => _currentStep += 1);
                } else if (_currentStep == 1) {
                  if (checkoutState.selectedAddress == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an address')));
                    return;
                  }
                  setState(() => _currentStep += 1);
                } else if (_currentStep == 2) {
                  setState(() => _currentStep += 1);
                } else if (_currentStep == 3) {
                  if (checkoutState.paymentMethod == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a payment method')));
                    return;
                  }
                  setState(() => _currentStep += 1);
                } else if (_currentStep == 4) {
                  _submitOrder();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep -= 1);
                }
              },
              steps: [
                Step(
                  title: const Text('Cart Review'),
                  content: Column(
                    children: checkoutState.cart.map((item) => ListTile(
                      title: Text(item['name']),
                      subtitle: Text('Qty: ${item['quantity']}'),
                      trailing: Text('₹${item['unit_price'] * item['quantity']}'),
                    )).toList(),
                  ),
                  isActive: _currentStep >= 0,
                ),
                Step(
                  title: const Text('Delivery Address'),
                  content: profileState.when(
                    data: (data) {
                      if (data.addresses.isEmpty) {
                        return const Text('No addresses found. Please add one in Profile.');
                      }
                      return Column(
                        children: data.addresses.map((a) => RadioListTile<CustomerAddress>(
                          title: Text(a.recipientName),
                          subtitle: Text(a.formattedAddress),
                          value: a,
                          groupValue: checkoutState.selectedAddress,
                          onChanged: (CustomerAddress? val) {
                            if (val != null) {
                              ref.read(checkoutProvider.notifier).setAddress(val);
                            }
                          },
                        )).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Error loading addresses: $e'),
                  ),
                  isActive: _currentStep >= 1,
                ),
                Step(
                  title: const Text('Delivery Slot'),
                  content: Column(
                    children: ['ASAP', 'Tomorrow Morning', 'Tomorrow Evening'].map((slot) => RadioListTile<String>(
                      title: Text(slot),
                      value: slot,
                      groupValue: checkoutState.deliverySlot ?? 'ASAP',
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(checkoutProvider.notifier).setDeliverySlot(val);
                        }
                      },
                    )).toList(),
                  ),
                  isActive: _currentStep >= 2,
                ),
                Step(
                  title: const Text('Payment Method'),
                  content: Column(
                    children: ['RAZORPAY', 'COD'].map((method) => RadioListTile<String>(
                      title: Text(method == 'RAZORPAY' ? 'Online Payment (Razorpay)' : 'Cash on Delivery (COD)'),
                      value: method,
                      groupValue: checkoutState.paymentMethod,
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(checkoutProvider.notifier).setPaymentMethod(val);
                        }
                      },
                    )).toList(),
                  ),
                  isActive: _currentStep >= 3,
                ),
                Step(
                  title: const Text('Review & Pay'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Deliver to: ${checkoutState.selectedAddress?.formattedAddress ?? ''}'),
                      Text('Payment: ${checkoutState.paymentMethod}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: checkoutState.isLoading ? null : _submitOrder,
                        child: checkoutState.isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Place Order'),
                      )
                    ],
                  ),
                  isActive: _currentStep >= 4,
                ),
              ],
            ),
    );
  }
}
