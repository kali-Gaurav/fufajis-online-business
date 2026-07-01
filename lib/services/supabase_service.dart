import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Service for Supabase database operations
class SupabaseService {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Check if the service is available for use
  bool get isAvailable => SupabaseConfig.isAvailable;

  // ==================== AUTH ====================

  /// Phone login with OTP
  Future<void> phoneLogin(String phone) async {
    try {
      await _client.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: true,
      );
    } catch (e) {
      throw Exception('Phone login failed: $e');
    }
  }

  /// Email login
  Future<void> emailLogin(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Email login failed: $e');
    }
  }

  /// Sign up new user
  Future<void> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  /// Get current session
  Session? getSession() {
    return _client.auth.currentSession;
  }

  // ==================== USERS ====================

  /// Create user profile
  Future<Map<String, dynamic>> createUserProfile({
    required String userId,
    required String phone,
    String? email,
    String? name,
    String role = 'customer',
    String? avatarUrl,
  }) async {
    try {
      final response = await _client
          .from('users')
          .insert({
            'id': userId,
            'phone': phone,
            'email': email,
            'name': name,
            'role': role,
            'avatar_url': avatarUrl,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      if (e.toString().contains('no rows')) {
        return null;
      }
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client
          .from('users')
          .update(data)
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // ==================== ORDERS ====================

  /// Create order
  Future<Map<String, dynamic>> createOrder({
    required String customerId,
    required String shopId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double total,
    double deliveryCharge = 0,
    double discount = 0,
    String? paymentMethod,
    String? deliveryAddress,
    String? deliveryType,
  }) async {
    try {
      final response = await _client
          .from('orders')
          .insert({
            'order_number':
                'ORD-${DateTime.now().millisecondsSinceEpoch}',
            'customer_id': customerId,
            'shop_id': shopId,
            'items': items,
            'subtotal': subtotal,
            'delivery_charge': deliveryCharge,
            'discount': discount,
            'total_amount': total,
            'payment_method': paymentMethod,
            'payment_status': 'pending',
            'status': 'pending',
            'delivery_address': deliveryAddress,
            'delivery_type': deliveryType ?? 'standard',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Get order
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('id', orderId)
          .single();
      return response;
    } catch (e) {
      if (e.toString().contains('no rows')) {
        return null;
      }
      throw Exception('Failed to fetch order: $e');
    }
  }

  /// Get customer orders
  Future<List<Map<String, dynamic>>> getCustomerOrders(String customerId) async {
    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  /// Update order
  Future<void> updateOrder(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client
          .from('orders')
          .update(data)
          .eq('id', orderId);
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  /// Cancel order
  Future<void> cancelOrder(String orderId) async {
    try {
      await updateOrder(orderId, {'status': 'cancelled'});
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  // ==================== PRODUCTS ====================

  /// Add product
  Future<void> addProduct(Map<String, dynamic> product) async {
    try {
      await _client.from('products').insert(product);
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  /// Update product
  Future<void> updateProduct(String firestoreId, Map<String, dynamic> data) async {
    try {
      await _client
          .from('products')
          .update(data)
          .eq('firestore_id', firestoreId);
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete product
  Future<void> deleteProduct(String firestoreId) async {
    try {
      await _client
          .from('products')
          .delete()
          .eq('firestore_id', firestoreId);
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  /// Get all products for shop
  Future<List<Map<String, dynamic>>> getShopProducts(String shopId) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('shop_id', shopId)
          .eq('in_stock', true);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Get product by ID
  Future<Map<String, dynamic>?> getProduct(String productId) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('id', productId)
          .single();
      return response;
    } catch (e) {
      if (e.toString().contains('no rows')) {
        return null;
      }
      throw Exception('Failed to fetch product: $e');
    }
  }

  // ==================== PAYMENTS ====================

  /// Create payment record
  Future<Map<String, dynamic>> createPayment({
    required String paymentId,
    required String orderId,
    required String customerId,
    required double amount,
    String status = 'pending',
  }) async {
    try {
      final response = await _client
          .from('payments')
          .insert({
            'id': paymentId,
            'order_id': orderId,
            'customer_id': customerId,
            'amount': amount,
            'status': status,
            'verified': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create payment: $e');
    }
  }

  /// Update payment status
  Future<void> updatePaymentStatus(
    String paymentId,
    String status,
  ) async {
    try {
      await _client
          .from('payments')
          .update({'status': status})
          .eq('id', paymentId);
    } catch (e) {
      throw Exception('Failed to update payment: $e');
    }
  }

  /// Verify payment
  Future<void> verifyPayment(
    String paymentId,
    String signature,
  ) async {
    try {
      await _client
          .from('payments')
          .update({
            'verified': true,
            'signature': signature,
            'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId);
    } catch (e) {
      throw Exception('Failed to verify payment: $e');
    }
  }

  // ==================== DELIVERY ====================

  /// Create delivery task
  Future<Map<String, dynamic>> createDeliveryTask({
    required String orderId,
    required String customerId,
    required String riderId,
    required String pickupAddress,
    required String deliveryAddress,
  }) async {
    try {
      final response = await _client
          .from('delivery_tasks')
          .insert({
            'order_id': orderId,
            'customer_id': customerId,
            'rider_id': riderId,
            'status': 'assigned',
            'pickup_address': pickupAddress,
            'delivery_address': deliveryAddress,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create delivery task: $e');
    }
  }

  /// Update delivery status
  Future<void> updateDeliveryStatus(
    String deliveryId,
    String status,
  ) async {
    try {
      final data = {'status': status};
      if (status == 'delivered') {
        data['end_time'] = DateTime.now().toIso8601String();
      } else if (status == 'picked_up') {
        data['start_time'] = DateTime.now().toIso8601String();
      }
      await _client
          .from('delivery_tasks')
          .update(data)
          .eq('id', deliveryId);
    } catch (e) {
      throw Exception('Failed to update delivery: $e');
    }
  }

  // ==================== LOYALTY ====================

  /// Get loyalty balance
  Future<Map<String, dynamic>?> getLoyaltyBalance(String userId) async {
    try {
      final response = await _client
          .from('loyalty')
          .select()
          .eq('user_id', userId)
          .single();
      return response;
    } catch (e) {
      if (e.toString().contains('no rows')) {
        return null;
      }
      throw Exception('Failed to fetch loyalty balance: $e');
    }
  }

  Future<void> addLoyaltyPoints(
    String userId,
    int points,
    String type,
    String? orderReference,
  ) async {
    try {
      final current = await getLoyaltyBalance(userId);
      final currentBalance = current != null ? (current['balance'] as int? ?? 0) : 0;
      final currentLifetime = current != null ? (current['lifetime'] as int? ?? 0) : 0;

      if (current == null) {
        await _client.from('loyalty').insert({
          'user_id': userId,
          'balance': points,
          'lifetime': points,
        });
      } else {
        await _client
            .from('loyalty')
            .update({
              'balance': currentBalance + points,
              'lifetime': currentLifetime + points,
            })
            .eq('user_id', userId);
      }

      // Record transaction
      await _client
          .from('loyalty_transactions')
          .insert({
            'user_id': userId,
            'type': type,
            'amount': points,
            'order_reference': orderReference,
            'timestamp': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      throw Exception('Failed to add loyalty points: $e');
    }
  }

  // ==================== CHATS ====================

  /// Get or create chat
  Future<Map<String, dynamic>> getOrCreateChat(
    String userId1,
    String userId2,
  ) async {
    try {
      final participants = [userId1, userId2]..sort();

      final existing = await _client
          .from('chats')
          .select()
          .contains('participants', participants);

      if (existing.isNotEmpty) {
        return existing.first;
      }

      final response = await _client
          .from('chats')
          .insert({
            'participants': participants,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to get/create chat: $e');
    }
  }

  /// Send message
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    try {
      final response = await _client
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': senderId,
            'text': text,
            'timestamp': DateTime.now().toIso8601String(),
            'read': false,
          })
          .select()
          .single();

      // Update last message in chat
      await _client
          .from('chats')
          .update({
            'last_message': text,
            'last_message_time': DateTime.now().toIso8601String(),
          })
          .eq('id', chatId);

      return response;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Get chat messages
  Future<List<Map<String, dynamic>>> getChatMessages(String chatId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('timestamp', ascending: true);
      return response;
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

  // ==================== REAL-TIME SUBSCRIPTIONS ====================

  /// Stream orders for customer
  Stream<List<Map<String, dynamic>>> streamCustomerOrders(
    String customerId,
  ) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .asBroadcastStream();
  }

  /// Stream order status
  Stream<Map<String, dynamic>?> streamOrderStatus(String orderId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((data) => data.isEmpty ? null : data.first)
        .asBroadcastStream();
  }

  /// Stream delivery status
  Stream<Map<String, dynamic>?> streamDeliveryStatus(String deliveryId) {
    return _client
        .from('delivery_tasks')
        .stream(primaryKey: ['id'])
        .eq('id', deliveryId)
        .map((data) => data.isEmpty ? null : data.first)
        .asBroadcastStream();
  }

  /// Stream chat messages
  Stream<List<Map<String, dynamic>>> streamChatMessages(String chatId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('timestamp', ascending: true)
        .asBroadcastStream();
  }

  // ==================== INVENTORY ====================

  /// Get inventory for product
  Future<Map<String, dynamic>?> getInventory(String productId) async {
    try {
      final response = await _client
          .from('inventory')
          .select()
          .eq('product_id', productId)
          .single();
      return response;
    } catch (e) {
      if (e.toString().contains('no rows')) {
        return null;
      }
      throw Exception('Failed to fetch inventory: $e');
    }
  }

  /// Reserve stock
  Future<void> reserveStock(String productId, int quantity) async {
    try {
      final current = await getInventory(productId);
      if (current == null) throw Exception('Inventory record not found for product: $productId');
      final reserved = (current['reserved'] as num? ?? 0).toInt();

      await _client
          .from('inventory')
          .update({
            'reserved': reserved + quantity,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('product_id', productId);
    } catch (e) {
      throw Exception('Failed to reserve stock: $e');
    }
  }

  /// Deduct stock
  Future<void> deductStock(String productId, int quantity) async {
    try {
      final current = await getInventory(productId);
      if (current == null) throw Exception('Inventory record not found for product: $productId');
      final currentQty = (current['quantity'] as num? ?? 0).toInt();
      final reserved = (current['reserved'] as num? ?? 0).toInt();

      await _client
          .from('inventory')
          .update({
            'quantity': currentQty - quantity,
            'reserved': reserved - quantity,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('product_id', productId);
    } catch (e) {
      throw Exception('Failed to deduct stock: $e');
    }
  }

  /// Release reserved stock
  Future<void> releaseReservedStock(String productId, int quantity) async {
    try {
      final current = await getInventory(productId);
      if (current == null) throw Exception('Inventory record not found for product: $productId');
      final reserved = (current['reserved'] as num? ?? 0).toInt();

      await _client
          .from('inventory')
          .update({
            'reserved': reserved - quantity,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('product_id', productId);
    } catch (e) {
      throw Exception('Failed to release reserved stock: $e');
    }
  }

  // ==================== RETURNS ====================

  /// Create return request
  Future<Map<String, dynamic>> createReturn({
    required String orderId,
    required String customerId,
    required String shopId,
    required String reason,
  }) async {
    try {
      final response = await _client
          .from('returns')
          .insert({
            'order_id': orderId,
            'customer_id': customerId,
            'shop_id': shopId,
            'reason': reason,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create return: $e');
    }
  }

  /// Update return status
  Future<void> updateReturnStatus(
    String returnId,
    String status,
    double? refundAmount,
  ) async {
    try {
      final Map<String, dynamic> data = {'status': status};
      if (refundAmount != null) {
        data['refund_amount'] = refundAmount;
      }
      if (status == 'refunded' || status == 'rejected') {
        data['resolved_at'] = DateTime.now().toIso8601String();
      }
      await _client
          .from('returns')
          .update(data)
          .eq('id', returnId);
    } catch (e) {
      throw Exception('Failed to update return: $e');
    }
  }
}
