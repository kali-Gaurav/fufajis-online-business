import '../../profile/models/customer_address.dart';

class CheckoutState {
  final List<dynamic> cart; // Using dynamic for now, should be CartItem
  final CustomerAddress? selectedAddress;
  final String? deliverySlot;
  final String? paymentMethod; // 'RAZORPAY', 'COD'
  final bool isLoading;
  final String? error;

  CheckoutState({
    this.cart = const [],
    this.selectedAddress,
    this.deliverySlot,
    this.paymentMethod,
    this.isLoading = false,
    this.error,
  });

  CheckoutState copyWith({
    List<dynamic>? cart,
    CustomerAddress? selectedAddress,
    String? deliverySlot,
    String? paymentMethod,
    bool? isLoading,
    String? error,
  }) {
    return CheckoutState(
      cart: cart ?? this.cart,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
