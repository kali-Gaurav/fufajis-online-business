import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/cart_item.dart';
import '../models/user_model.dart';
import '../models/delivery_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown during checkout
class CheckoutException implements Exception {
  final String message;
  CheckoutException(this.message);

  @override
  String toString() => 'CheckoutException: $message';
}

/// Handles inventory reservation and order creation at checkout
class CheckoutService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Reserve inventory atomically and create order
  /// Throws CheckoutException on any failure
  Future<OrderModel> reserveInventoryAndCreateOrder({
    required String customerId,
    required List<CartItem> items,
    required Address deliveryAddress,
    required DeliveryType deliveryType,
    String? couponCode,
    required double walletAmount,
  }) async {
    if (items.isEmpty) {
      throw CheckoutException('Cart is empty');
    }

    try {
      debugPrint('[CheckoutService] Starting checkout for user: $customerId');
      debugPrint('[CheckoutService] Items: ${items.map((i) => '${i.productId}x${i.quantity}').join(', ')}');

      // Call Supabase Edge Function to reserve inventory atomically
      final response = await _supabase.functions.invoke(
        'checkout-reserve-inventory',
        body: {
          'customerId': customerId,
          'items': items.map((i) => {
            'productId': i.productId,
            'quantity': i.quantity,
            'price': i.price.toDouble(),
            'unit': i.unit,
          }).toList(),
          'deliveryAddress': {
            'address': deliveryAddress.address,
            'latitude': deliveryAddress.latitude,
            'longitude': deliveryAddress.longitude,
            'zone': deliveryAddress.zone,
            'phone': deliveryAddress.phone,
          },
          'deliveryType': deliveryType.toString().split('.').last,
          'couponCode': couponCode,
          'walletAmount': walletAmount,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map
          ? response.data['error'] ?? 'Checkout failed'
          : 'Checkout failed';
        throw CheckoutException(errorMsg.toString());
      }

      // Verify success flag
      if (response.data is! Map || response.data['success'] != true) {
        throw CheckoutException('Checkout API returned success status but invalid data');
      }

      debugPrint('[CheckoutService] Checkout succeeded');

      // Parse order from response
      if (response.data['order'] != null) {
        final orderData = response.data['order'] as Map<String, dynamic>;
        return OrderModel.fromJson(orderData);
      }

      // Fallback: if order data not in response, at least orderId should be present
      final orderId = response.data['orderId'];
      if (orderId != null) {
        debugPrint('[CheckoutService] Order created with ID: $orderId, but full data unavailable. Fetching...');
        final orderStatus = await getOrderStatus(orderId as String);
        if (orderStatus != null) {
          return OrderModel.fromJson(orderStatus);
        }
        throw CheckoutException('Created order but could not retrieve it');
      }

      throw CheckoutException('Invalid response from checkout: no order data or orderId');
    } on FunctionsException catch (e) {
      debugPrint('[CheckoutService] Supabase error: ${e.message}');
      throw CheckoutException('Checkout failed: ${e.message}');
    } catch (e) {
      debugPrint('[CheckoutService] Unexpected error: $e');
      throw CheckoutException('Checkout failed: $e');
    }
  }

  /// Check if an order exists and its status
  Future<Map<String, dynamic>?> getOrderStatus(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('id, status, payment_status')
          .eq('id', orderId)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('[CheckoutService] Error fetching order status: $e');
      return null;
    }
  }
}
