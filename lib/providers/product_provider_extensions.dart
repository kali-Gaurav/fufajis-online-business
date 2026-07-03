/// ProductProvider Extensions for Phase 11-14 Features
/// This file contains extension methods for WhatsApp Sync, Inventory Alerts,
/// Expiry Tracking, and Dynamic Pricing integration
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import 'product_provider.dart';

/// Extension methods for ProductProvider to support Phase 11-14 features
extension ProductProviderPhase11To14 on ProductProvider {
  // ============ PHASE 11: WhatsApp Sync Methods ============

  /// Get WhatsApp sync status
  Future<Map<String, dynamic>> getWhatsAppSyncStatus() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final doc = await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('settings')
          .doc('whatsapp_sync')
          .get();

      if (!doc.exists) {
        return {'enabled': false, 'lastSyncTime': null, 'itemsCount': 0, 'recentItems': []};
      }

      final data = doc.data() ?? {};
      return {
        'enabled': data['enabled'] ?? false,
        'lastSyncTime': data['lastSyncTime']?.toDate(),
        'itemsCount': data['itemsCount'] ?? 0,
        'recentItems': data['recentItems'] ?? [],
      };
    } catch (e) {
      print('Error getting WhatsApp sync status: $e');
      rethrow;
    }
  }

  /// Update WhatsApp sync status
  Future<void> updateWhatsAppSyncStatus(bool enabled) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('settings')
          .doc('whatsapp_sync')
          .set({
            'enabled': enabled,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating WhatsApp sync status: $e');
      rethrow;
    }
  }

  /// Test WhatsApp sync
  Future<void> testWhatsAppSync() async {
    try {
      // Send test message to WhatsApp
      // This would typically call a Firebase Function
      print('Testing WhatsApp sync...');
    } catch (e) {
      print('Error testing WhatsApp sync: $e');
      rethrow;
    }
  }

  /// Record WhatsApp sync event
  Future<void> recordWhatsAppSync(List<ProductModel> items) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('settings')
          .doc('whatsapp_sync')
          .set({
            'lastSyncTime': FieldValue.serverTimestamp(),
            'itemsCount': FieldValue.increment(items.length),
            'recentItems': items.map((p) => p.id).toList(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error recording WhatsApp sync: $e');
      rethrow;
    }
  }

  // ============ PHASE 12: Inventory Alert Methods ============

  /// Get low stock alerts
  Future<List<dynamic>> getLowStockAlerts() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('inventory_alerts')
          .where('dismissed', isEqualTo: false)
          .orderBy('severity')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting low stock alerts: $e');
      return [];
    }
  }

  /// Dismiss inventory alert
  Future<void> dismissInventoryAlert(String alertId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('inventory_alerts')
          .doc(alertId)
          .update({'dismissed': true, 'dismissedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error dismissing alert: $e');
      rethrow;
    }
  }

  /// Record sale for inventory tracking
  Future<void> recordSale(String productId, int quantity) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('products').doc(productId).collection('sales_history').add({
        'quantity': quantity,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update product stock
      await firestore.collection('products').doc(productId).update({
        'stockQuantity': FieldValue.increment(-quantity),
      });
    } catch (e) {
      print('Error recording sale: $e');
      rethrow;
    }
  }

  /// Get inventory health score
  Future<Map<String, dynamic>> getInventoryHealthScore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('products')
          .get();

      if (snapshot.docs.isEmpty) {
        return {'score': 0, 'healthyProducts': 0, 'totalProducts': 0};
      }

      int healthyCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final daysUntilStockout = (data['daysUntilStockout'] as num?) ?? 0;
        if (daysUntilStockout > 7) {
          healthyCount++;
        }
      }

      final score = (healthyCount / snapshot.docs.length * 100).toInt();
      return {
        'score': score,
        'healthyProducts': healthyCount,
        'totalProducts': snapshot.docs.length,
      };
    } catch (e) {
      print('Error getting inventory health score: $e');
      return {'score': 0, 'healthyProducts': 0, 'totalProducts': 0};
    }
  }

  // ============ PHASE 13: Expiry Tracking Methods ============

  /// Get expiring products
  Future<List<ProductModel>> getExpiringProducts() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final thirtyDaysLater = now.add(const Duration(days: 30));

      final snapshot = await firestore
          .collection('products')
          .where('expiryDate', isGreaterThan: Timestamp.fromDate(now))
          .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysLater))
          .get();

      return snapshot.docs.map((doc) => ProductModel.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting expiring products: $e');
      return [];
    }
  }

  /// Get expired products
  Future<List<ProductModel>> getExpiredProducts() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      final snapshot = await firestore
          .collection('products')
          .where('expiryDate', isLessThan: Timestamp.fromDate(now))
          .get();

      return snapshot.docs.map((doc) => ProductModel.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting expired products: $e');
      return [];
    }
  }

  /// Update expiry date
  Future<void> updateExpiryDate(String productId, DateTime newDate) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('products').doc(productId).update({
        'expiryDate': Timestamp.fromDate(newDate),
      });
    } catch (e) {
      print('Error updating expiry date: $e');
      rethrow;
    }
  }

  /// Mark product as sold
  Future<void> markProductAsSold(String productId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('products').doc(productId).update({
        'stockQuantity': 0,
        'isAvailable': false,
        'soldOutAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking product as sold: $e');
      rethrow;
    }
  }

  // ============ PHASE 14: Dynamic Pricing Methods ============

  /// Get pricing rules
  Future<Map<String, dynamic>> getPricingRules() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final doc = await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('settings')
          .doc('pricing_rules')
          .get();

      if (!doc.exists) {
        return {
          'strategy': 'Match',
          'margin': 10.0,
          'beatAmount': 5.0,
          'premiumPercentage': 10.0,
          'costPercentage': 20.0,
        };
      }

      return doc.data() ?? {};
    } catch (e) {
      print('Error getting pricing rules: $e');
      rethrow;
    }
  }

  /// Update pricing strategy
  Future<void> updatePricingStrategy(Map<String, dynamic> rules) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('settings')
          .doc('pricing_rules')
          .set(rules, SetOptions(merge: true));
    } catch (e) {
      print('Error updating pricing strategy: $e');
      rethrow;
    }
  }

  /// Get pending price changes
  Future<List<Map<String, dynamic>>> getPendingPriceChanges() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('price_changes')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting pending price changes: $e');
      return [];
    }
  }

  /// Approve price change
  Future<void> approvePriceChange(String changeId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('price_changes')
          .doc(changeId)
          .update({'status': 'approved', 'approvedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error approving price change: $e');
      rethrow;
    }
  }

  /// Reject price change
  Future<void> rejectPriceChange(String changeId, String reason) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('shops')
          .doc(currentShopId ?? 'shop_001')
          .collection('price_changes')
          .doc(changeId)
          .update({
            'status': 'rejected',
            'rejectionReason': reason,
            'rejectedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error rejecting price change: $e');
      rethrow;
    }
  }
}
