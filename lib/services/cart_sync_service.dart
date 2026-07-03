import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';

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
  Future<List<CartItem>> mergeCarts(String uid) async {
    final localItems = await loadLocalCart();
    final cloudItems = await loadCloudCart(uid);

    if (localItems.isEmpty) return cloudItems;

    final Map<String, CartItem> merged = {
      for (var item in cloudItems) '${item.productId}_${item.selectedVariant}': item,
    };

    for (final localItem in localItems) {
      final key = '${localItem.productId}_${localItem.selectedVariant}';
      if (merged.containsKey(key)) {
        // Additive merge, max 20, keep latest price (local)
        final cloudItem = merged[key]!;
        final newQty = (cloudItem.quantity + localItem.quantity).clamp(1, _maxQuantityPerItem);
        merged[key] = localItem.copyWith(quantity: newQty);
      } else {
        merged[key] = localItem;
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
}
