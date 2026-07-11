import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Firestore Real-Time Sync Service
///
/// Syncs data from Supabase (source of truth) to Firestore (read-only UI layer)
/// Firestore provides real-time listeners for UI updates without constant DB queries
class FirestoreSyncService {
  static final FirestoreSyncService _instance = FirestoreSyncService._();

  factory FirestoreSyncService() => _instance;

  FirestoreSyncService._();

  static FirestoreSyncService get instance => _instance;

  final _firestore = FirebaseFirestore.instance;
  final _supabase = Supabase.instance.client;

  bool _isInitialized = false;

  /// Initialize sync service and start listening to Supabase changes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[FirestoreSync] Initializing sync service...');

      // Start sync streams
      _syncOrders();
      _syncSubscriptions();
      _syncVendorPayouts();
      _syncProductInventory();
      _syncDeliveryTracking();

      _isInitialized = true;
      debugPrint('[FirestoreSync] Sync service initialized');
    } catch (e) {
      debugPrint('[FirestoreSync] Initialization error: $e');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;

  // ─────────────────────────────────────────────────────────
  // ORDERS SYNC
  // ─────────────────────────────────────────────────────────

  void _syncOrders() {
    _supabase
        .from('orders')
        .on(RealtimeListenTypes.all, ColumnFilter('id', 'neq', null))
        .eq('user_id', _supabase.auth.currentUser?.id ?? '')
        .subscribe((payload) {
          _handleOrderChange(payload);
        });
  }

  Future<void> _handleOrderChange(RealtimeMessage message) async {
    try {
      final data = message.newRecord;
      final orderId = data['id'] as String?;

      if (orderId == null) return;

      // Transform Supabase order to Firestore format
      final fsOrder = _transformOrder(data);

      // Sync to Firestore
      await _firestore
          .collection('orders')
          .doc(orderId)
          .set(fsOrder, SetOptions(merge: true));

      debugPrint('[FirestoreSync] Order synced: $orderId');
    } catch (e) {
      debugPrint('[FirestoreSync] Order sync error: $e');
    }
  }

  Map<String, dynamic> _transformOrder(Map<String, dynamic> pgOrder) {
    return {
      'id': pgOrder['id'],
      'order_number': pgOrder['order_number'],
      'customer_id': pgOrder['customer_id'],
      'status': pgOrder['status'],
      'total_amount': pgOrder['total_amount'],
      'items_count': pgOrder['items_count'],
      'created_at': _parseTimestamp(pgOrder['created_at']),
      'scheduled_delivery': _parseTimestamp(pgOrder['scheduled_delivery']),
      'estimated_delivery': pgOrder['estimated_delivery'],
      'delivery_address': pgOrder['delivery_address'],
      'payment_status': pgOrder['payment_status'],
      'delivery_agent_id': pgOrder['delivery_agent_id'],
      'last_updated': FieldValue.serverTimestamp(),
      'sync_source': 'supabase',
    };
  }

  // ─────────────────────────────────────────────────────────
  // SUBSCRIPTIONS SYNC
  // ─────────────────────────────────────────────────────────

  void _syncSubscriptions() {
    _supabase
        .from('subscriptions')
        .on(RealtimeListenTypes.all, ColumnFilter('customer_id', 'eq', _supabase.auth.currentUser?.id ?? ''))
        .subscribe((payload) {
          _handleSubscriptionChange(payload);
        });
  }

  Future<void> _handleSubscriptionChange(RealtimeMessage message) async {
    try {
      final data = message.newRecord;
      final subscriptionId = data['id'] as String?;

      if (subscriptionId == null) return;

      final fsSubscription = _transformSubscription(data);

      await _firestore
          .collection('subscriptions')
          .doc(subscriptionId)
          .set(fsSubscription, SetOptions(merge: true));

      debugPrint('[FirestoreSync] Subscription synced: $subscriptionId');
    } catch (e) {
      debugPrint('[FirestoreSync] Subscription sync error: $e');
    }
  }

  Map<String, dynamic> _transformSubscription(Map<String, dynamic> pgSub) {
    return {
      'id': pgSub['id'],
      'customer_id': pgSub['customer_id'],
      'status': pgSub['status'],
      'frequency': pgSub['frequency'],
      'next_delivery_date': _parseTimestamp(pgSub['next_delivery_date']),
      'total_amount': pgSub['total_amount'],
      'base_amount': pgSub['base_amount'],
      'discount_percentage': pgSub['discount_percentage'],
      'discount_amount': pgSub['discount_amount'],
      'churn_risk': pgSub['churn_risk'],
      'predicted_lifetime_value': pgSub['predicted_lifetime_value'],
      'items_count': (pgSub['items'] as List?)?.length ?? 0,
      'last_updated': FieldValue.serverTimestamp(),
    };
  }

  // ─────────────────────────────────────────────────────────
  // VENDOR PAYOUTS SYNC
  // ─────────────────────────────────────────────────────────

  void _syncVendorPayouts() {
    _supabase
        .from('vendor_payouts')
        .on(RealtimeListenTypes.all, ColumnFilter('status', 'neq', null))
        .subscribe((payload) {
          _handlePayoutChange(payload);
        });
  }

  Future<void> _handlePayoutChange(RealtimeMessage message) async {
    try {
      final data = message.newRecord;
      final payoutId = data['id'] as String?;
      final vendorId = data['vendor_id'] as String?;

      if (payoutId == null || vendorId == null) return;

      final fsPayout = _transformPayout(data);

      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('payouts')
          .doc(payoutId)
          .set(fsPayout, SetOptions(merge: true));

      // Also update vendor's balance
      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .update({
            'balance': data['vendor_balance'],
            'balance_updated': FieldValue.serverTimestamp(),
          });

      debugPrint('[FirestoreSync] Payout synced: $payoutId');
    } catch (e) {
      debugPrint('[FirestoreSync] Payout sync error: $e');
    }
  }

  Map<String, dynamic> _transformPayout(Map<String, dynamic> pgPayout) {
    return {
      'id': pgPayout['id'],
      'vendor_id': pgPayout['vendor_id'],
      'amount': pgPayout['amount'],
      'status': pgPayout['status'],
      'razorpay_payout_id': pgPayout['razorpay_payout_id'],
      'razorpay_settlement_id': pgPayout['razorpay_settlement_id'],
      'created_at': _parseTimestamp(pgPayout['created_at']),
      'requested_at': _parseTimestamp(pgPayout['requested_at']),
      'processed_at': _parseTimestamp(pgPayout['processed_at']),
      'failure_reason': pgPayout['failure_reason'],
      'last_updated': FieldValue.serverTimestamp(),
    };
  }

  // ─────────────────────────────────────────────────────────
  // INVENTORY SYNC
  // ─────────────────────────────────────────────────────────

  void _syncProductInventory() {
    _supabase
        .from('products')
        .on(RealtimeListenTypes.all, ColumnFilter('available_stock', 'neq', null))
        .subscribe((payload) {
          _handleInventoryChange(payload);
        });
  }

  Future<void> _handleInventoryChange(RealtimeMessage message) async {
    try {
      final data = message.newRecord;
      final productId = data['id'] as String?;

      if (productId == null) return;

      final fsInventory = {
        'id': productId,
        'available_stock': data['available_stock'],
        'reserved_stock': data['reserved_stock'],
        'sold_stock': data['sold_stock'],
        'reorder_point': data['reorder_point'],
        'last_stock_check': _parseTimestamp(data['last_stock_check']),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('products')
          .doc(productId)
          .update(fsInventory);

      debugPrint('[FirestoreSync] Inventory synced: $productId');
    } catch (e) {
      debugPrint('[FirestoreSync] Inventory sync error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // DELIVERY TRACKING SYNC
  // ─────────────────────────────────────────────────────────

  void _syncDeliveryTracking() {
    _supabase
        .from('delivery_tracking')
        .on(RealtimeListenTypes.all, ColumnFilter('order_id', 'neq', null))
        .subscribe((payload) {
          _handleDeliveryChange(payload);
        });
  }

  Future<void> _handleDeliveryChange(RealtimeMessage message) async {
    try {
      final data = message.newRecord;
      final orderId = data['order_id'] as String?;

      if (orderId == null) return;

      final fsTracking = _transformDeliveryTracking(data);

      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('tracking')
          .doc('live')
          .set(fsTracking, SetOptions(merge: true));

      debugPrint('[FirestoreSync] Delivery tracking synced: $orderId');
    } catch (e) {
      debugPrint('[FirestoreSync] Delivery tracking sync error: $e');
    }
  }

  Map<String, dynamic> _transformDeliveryTracking(Map<String, dynamic> pgTracking) {
    return {
      'order_id': pgTracking['order_id'],
      'delivery_agent_id': pgTracking['delivery_agent_id'],
      'current_status': pgTracking['current_status'],
      'current_latitude': pgTracking['current_latitude'],
      'current_longitude': pgTracking['current_longitude'],
      'estimated_delivery': pgTracking['estimated_delivery'],
      'last_location_update': _parseTimestamp(pgTracking['updated_at']),
      'distance_remaining_km': pgTracking['distance_remaining_km'],
      'eta_minutes': pgTracking['eta_minutes'],
      'is_delayed': pgTracking['is_delayed'],
      'delay_reason': pgTracking['delay_reason'],
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  // ─────────────────────────────────────────────────────────
  // REAL-TIME STREAM GETTERS
  // ─────────────────────────────────────────────────────────

  /// Watch orders in real-time from Firestore
  Stream<List<Map<String, dynamic>>> watchOrdersRealtime(String userId) {
    return _firestore
        .collection('orders')
        .where('customer_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Watch subscriptions in real-time
  Stream<List<Map<String, dynamic>>> watchSubscriptionsRealtime(String userId) {
    return _firestore
        .collection('subscriptions')
        .where('customer_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Watch delivery tracking in real-time
  Stream<Map<String, dynamic>?> watchDeliveryTrackingRealtime(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .collection('tracking')
        .doc('live')
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  /// Watch vendor payouts in real-time
  Stream<List<Map<String, dynamic>>> watchVendorPayoutsRealtime(String vendorId) {
    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('payouts')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Watch product inventory in real-time
  Stream<Map<String, dynamic>?> watchProductInventoryRealtime(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  // ─────────────────────────────────────────────────────────
  // UTILITY FUNCTIONS
  // ─────────────────────────────────────────────────────────

  Timestamp? _parseTimestamp(dynamic value) {
    if (value is String) {
      try {
        final dateTime = DateTime.parse(value);
        return Timestamp.fromDate(dateTime);
      } catch (e) {
        return null;
      }
    } else if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    return null;
  }

  /// Clear all Firestore cache (when user logs out)
  Future<void> clearCache() async {
    try {
      await _firestore.clearPersistentCache();
      debugPrint('[FirestoreSync] Cache cleared');
    } catch (e) {
      debugPrint('[FirestoreSync] Cache clear error: $e');
    }
  }

  /// Check sync health
  Future<Map<String, dynamic>> getSyncHealth() async {
    try {
      final orders = await _firestore.collection('orders').count().get();
      final subscriptions = await _firestore.collection('subscriptions').count().get();
      final products = await _firestore.collection('products').count().get();

      return {
        'orders': orders.count,
        'subscriptions': subscriptions.count,
        'products': products.count,
        'is_healthy': true,
        'last_check': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'is_healthy': false,
        'error': e.toString(),
        'last_check': DateTime.now().toIso8601String(),
      };
    }
  }
}
