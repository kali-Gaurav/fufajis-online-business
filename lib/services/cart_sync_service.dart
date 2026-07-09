import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item.dart';
import '../utils/monetary_value.dart';

class CartSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _localCartKey = 'cart_items';
  static const int _maxQuantityPerItem = 20;

  // Load guest cart from local storage
  Future<List<CartItem>> loadLocalCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString(_localCartKey);
      if (cartString != null && cartString.isNotEmpty) {
        final List<dynamic> cartData = jsonDecode(cartString) as List<dynamic>;
        return cartData.map((item) => CartItem.fromMap(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading local cart: $e');
    }
    return [];
  }

  // Load verified user cart from Firestore
  Future<List<CartItem>> loadCloudCart(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).collection('cart').get();
      return snapshot.docs.map((doc) => CartItem.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error loading cloud cart: $e');
      return [];
    }
  }

  // Sync a cart list to Firestore
  Future<void> syncToCloud(String uid, List<CartItem> cartItems) async {
    try {
      final cartRef = _firestore.collection('users').doc(uid).collection('cart');

      // Get existing items to know what to delete
      final snapshot = await cartRef.get();
      final existingIds = snapshot.docs.map((doc) => doc.id).toSet();

      final batch = _firestore.batch();

      for (final item in cartItems) {
        batch.set(cartRef.doc(item.id), item.toMap());
        existingIds.remove(item.id);
      }

      // Delete removed items
      for (final id in existingIds) {
        batch.delete(cartRef.doc(id));
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error syncing cart to cloud: $e');
    }
  }

  // Additive merge of guest + cloud cart, cap at 20
  // FIX #1: Validates inventory availability before merging
  // FIX #2: Fetches current prices from PostgreSQL (not stale cached prices)
  Future<List<CartItem>> mergeCarts(String uid, {required SupabaseClient supabase}) async {
    final localItems = await loadLocalCart();
    final cloudItems = await loadCloudCart(uid);

    if (localItems.isEmpty) return cloudItems;

    final Map<String, CartItem> merged = {
      for (var item in cloudItems) '${item.productId}_${item.selectedVariant}': item,
    };

    for (final localItem in localItems) {
      final key = '${localItem.productId}_${localItem.selectedVariant}';

      try {
        // FIX #2: Fetch current product price from PostgreSQL
        final product = await supabase
          .from("products")
          .select("price, id, status")
          .eq("id", localItem.productId)
          .single();

        if (product['status'] != 'active') {
          // Product not found or inactive — skip this item
          debugPrint('[CartSyncService] Skipping inactive product: ${localItem.productId}');
          continue;
        }

        final currentPrice = (product['price'] as num).toDouble();

        if (merged.containsKey(key)) {
          final cloudItem = merged[key]!;
          final desiredQty = cloudItem.quantity + localItem.quantity;

          // FIX #1: Check available inventory before merging
          final inventory = await supabase
            .rpc("check_available_stock", params: {
              "p_product_id": localItem.productId,
              "p_shop_id": localItem.shopId
            });

          final availableStock = (inventory as Map<String, dynamic>)['available'] as int? ?? 0;
          final newQty = min(desiredQty, availableStock).clamp(1, _maxQuantityPerItem);

          if (newQty < desiredQty) {
            debugPrint('[CartSyncService] Reduced qty for ${localItem.productId}: '
                'wanted=$desiredQty, available=$availableStock, merged=$newQty');
          }

          // Use CURRENT price from PostgreSQL, not stale local price
          merged[key] = cloudItem.copyWith(
            quantity: newQty,
            price: MonetaryValue(currentPrice),
          );
        } else {
          // New item — also check inventory and use current price
          final inventory = await supabase
            .rpc("check_available_stock", params: {
              "p_product_id": localItem.productId,
              "p_shop_id": localItem.shopId
            });

          final availableStock = (inventory as Map<String, dynamic>)['available'] as int? ?? 0;
          final newQty = min(localItem.quantity, availableStock).clamp(1, _maxQuantityPerItem);

          merged[key] = localItem.copyWith(
            quantity: newQty,
            price: MonetaryValue(currentPrice),
          );
        }
      } catch (e) {
        debugPrint('[CartSyncService] Error merging item ${localItem.productId}: $e');
        continue;
      }
    }

    final mergedList = merged.values.toList();

    // Save merged to cloud
    await syncToCloud(uid, mergedList);

    // Also update local storage to match the merged cart
    await saveLocalCart(mergedList);

    return mergedList;
  }

  Future<void> saveLocalCart(List<CartItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = items.map((item) => item.toMap()).toList();
      await prefs.setString(_localCartKey, jsonEncode(cartData));
    } catch (e) {
      debugPrint('Error saving local cart: $e');
    }
  }

  Future<void> clearLocalCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCartKey);
    } catch (e) {
      debugPrint('Error clearing local cart: $e');
    }
  }

  Future<void> clearCloudCart(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).collection('cart').get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing cloud cart: $e');
    }
  }

  // ── Save for Later persistence ──
  static const String _localSaveLaterKey = 'save_for_later_items';

  Future<List<CartItem>> loadLocalSaveForLater() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedString = prefs.getString(_localSaveLaterKey);
      if (savedString != null && savedString.isNotEmpty) {
        final List<dynamic> savedData = jsonDecode(savedString) as List<dynamic>;
        return savedData.map((item) => CartItem.fromMap(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading local save for later: $e');
    }
    return [];
  }

  Future<void> saveLocalSaveForLater(List<CartItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = items.map((item) => item.toMap()).toList();
      await prefs.setString(_localSaveLaterKey, jsonEncode(savedData));
    } catch (e) {
      debugPrint('Error saving local save for later: $e');
    }
  }

  Future<List<CartItem>> loadCloudSaveForLater(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('save_for_later')
          .get();
      return snapshot.docs.map((doc) => CartItem.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error loading cloud save for later: $e');
      return [];
    }
  }

  Future<void> syncSaveForLaterToCloud(String uid, List<CartItem> items) async {
    try {
      final saveLaterRef = _firestore.collection('users').doc(uid).collection('save_for_later');
      final snapshot = await saveLaterRef.get();
      final existingIds = snapshot.docs.map((doc) => doc.id).toSet();
      final batch = _firestore.batch();
      for (final item in items) {
        batch.set(saveLaterRef.doc(item.id), item.toMap());
        existingIds.remove(item.id);
      }
      for (final id in existingIds) {
        batch.delete(saveLaterRef.doc(id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error syncing save for later to cloud: $e');
    }
  }

  /// FIX #2: Atomic, idempotent cart item quantity update via Supabase Edge Function
  /// Sends request version for deduplication; backend checks cart_request_log table
  Future<void> updateItemQuantity(
    String itemId,
    int quantity,
    int requestVersion,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'cart-update-item',
        body: {
          'itemId': itemId,
          'quantity': quantity,
          'requestVersion': requestVersion,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map
          ? response.data['error'] ?? 'Failed to update cart item'
          : 'Failed to update cart item (status: ${response.status})';
        throw Exception(errorMsg.toString());
      }

      // Verify success response
      if (response.data is! Map || response.data['success'] != true) {
        throw Exception('Invalid response from cart-update-item: ${response.data}');
      }

      final isDuplicate = response.data['duplicate'] ?? false;
      debugPrint('[CartSyncService] Updated item $itemId to qty $quantity (v$requestVersion, duplicate=$isDuplicate)');
    } on FunctionsException catch (e) {
      debugPrint('[CartSyncService] Edge Function error updating item $itemId: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[CartSyncService] Error updating item quantity: $e');
      rethrow;
    }
  }
}
