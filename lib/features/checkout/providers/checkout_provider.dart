import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/checkout_state.dart';
import '../services/checkout_api.dart';
import '../../profile/models/customer_address.dart';

final checkoutApiProvider = Provider((ref) => CheckoutApi());

class CheckoutNotifier extends Notifier<CheckoutState> {
  final _uuid = const Uuid();
  String _idempotencyKey = '';

  @override
  CheckoutState build() {
    _idempotencyKey = _uuid.v4();
    return CheckoutState(
      // Dummy cart data for the MVP flow
      cart: [
        { 'product_id': 'prod-123', 'quantity': 2, 'unit_price': 150.0, 'name': 'Organic Tomatoes (1kg)' },
        { 'product_id': 'prod-456', 'quantity': 1, 'unit_price': 500.0, 'name': 'Aashirvaad Atta (5kg)' }
      ]
    );
  }

  void setAddress(CustomerAddress address) {
    state = state.copyWith(selectedAddress: address);
  }

  void setDeliverySlot(String slot) {
    state = state.copyWith(deliverySlot: slot);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  /// Resets the idempotency key, allowing a completely fresh checkout attempt
  void resetIdempotencyKey() {
    _idempotencyKey = _uuid.v4();
  }

  Future<Map<String, dynamic>> submitCheckout() async {
    if (state.selectedAddress == null || state.paymentMethod == null) {
      throw Exception('Missing checkout information');
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final payload = {
        'items': state.cart,
        'addressId': state.selectedAddress!.id,
        'paymentMethod': state.paymentMethod,
        'deliverySlot': state.deliverySlot ?? 'ASAP',
        'idempotencyKey': _idempotencyKey,
      };

      final api = ref.read(checkoutApiProvider);
      final response = await api.processCheckout(payload);
      state = state.copyWith(isLoading: false);
      
      // We don't reset idempotency key here. If the network call succeeded but client
      // didn't get it, retrying will safely return the exact same response from backend.
      
      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final checkoutProvider = NotifierProvider<CheckoutNotifier, CheckoutState>(() {
  return CheckoutNotifier();
});
