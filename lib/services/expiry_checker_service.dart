import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import 'notification_service.dart';
import 'analytics_service.dart';

/// Expiry Checker Service for Auto-Expiry Date Tracking & Dynamic Markdown
/// Automatically discounts products nearing expiry to clear stock
class ExpiryCheckerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Configuration
  static const int _defaultExpiryWarningDays = 3; // Warn before this many days
  static const int _defaultExpiryCriticalDays = 1; // Critical discount before this
  static const double _maxDiscountRate = 0.5; // Maximum 50% discount
  static const int _discountIntervalHours = 6; // Discount increase interval

  // Collection references
  CollectionReference _productsCollection(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('products');

  CollectionReference _expiryLogsCollection(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('expiry_logs');

  CollectionReference _discountHistoryCollection(String productId) =>
      _firestore.collection('products').doc(productId).collection('discount_history');

  /// Check all products for expiry and apply dynamic discounts
  Future<List<Map<String, dynamic>>> checkAndApplyDiscounts(String shopId) async {
    final now = DateTime.now();
    final appliedDiscounts = <Map<String, dynamic>>[];

    try {
      // Get all products with expiry dates
      final snapshot = await _productsCollection(shopId)
          .where('expiryDate', isNotEqualTo: null)
          .get();

      for (final doc in snapshot.docs) {
        final product = ProductModel.fromMap(doc.data() as Map<String, dynamic>);
        final expiryDate = product.expiryDate;

        if (expiryDate == null) continue;

        // Skip if already discounted to max
        if (product.discountPercentage != null && 
            product.discountPercentage! >= _maxDiscountRate * 100) {
          continue;
        }

        // Calculate days until expiry
        final daysUntilExpiry = expiryDate.difference(now).inDays;
        final hoursUntilExpiry = expiryDate.difference(now).inHours;

        // Skip if more than warning period away
        if (daysUntilExpiry > _defaultExpiryWarningDays) continue;

        // Calculate discount based on time remaining
        final discountPercentage = _calculateDynamicDiscount(
          daysUntilExpiry,
          hoursUntilExpiry,
          product.discountPercentage ?? 0,
        );

        if (discountPercentage > (product.discountPercentage ?? 0)) {
          // Apply new discount
          await _applyDiscount(doc.id, product, discountPercentage, now);

          appliedDiscounts.add({
            'productId': product.id,
            'productName': product.name,
            'previousDiscount': product.discountPercentage ?? 0,
            'newDiscount': discountPercentage,
            'newPrice': _calculateDiscountedPrice(product.price, discountPercentage),
            'expiryDate': expiryDate,
            'hoursUntilExpiry': hoursUntilExpiry,
          });

          // Log the discount change
          await _logDiscountChange(product.id, {
            'previousDiscount': product.discountPercentage ?? 0,
            'newDiscount': discountPercentage,
            'reason': 'expiry_dynamic',
            'hoursUntilExpiry': hoursUntilExpiry,
            'createdAt': Timestamp.now(),
          });
        }
      }

      // Track analytics
      if (appliedDiscounts.isNotEmpty) {
        _analyticsService.trackEvent('expiry_discounts_applied', {
          'shopId': shopId,
          'count': appliedDiscounts.length,
          'products': appliedDiscounts.map((d) => d['productName']).join(','),
        });
      }

      return appliedDiscounts;
    } catch (e) {
      print('Error checking expiry discounts: $e');
      return [];
    }
  }

  /// Calculate dynamic discount based on time remaining
  double _calculateDynamicDiscount(
    int daysUntilExpiry,
    int hoursUntilExpiry,
    double currentDiscount,
  ) {
    // Base discount increases as expiry approaches
    double baseDiscount;

    if (hoursUntilExpiry <= 24) {
      // Less than 24 hours: 40-50% discount
      baseDiscount = 40.0 + (24 - hoursUntilExpiry) / 24 * 10;
    } else if (daysUntilExpiry <= 1) {
      // 1-2 days: 30-40% discount
      baseDiscount = 30.0 + (2 - daysUntilExpiry) * 10;
    } else if (daysUntilExpiry <= 2) {
      // 2-3 days: 20-30% discount
      baseDiscount = 20.0 + (3 - daysUntilExpiry) * 10;
    } else {
      // 3+ days: 10-20% discount
      baseDiscount = 10.0 + (_defaultExpiryWarningDays - daysUntilExpiry) * 5;
    }

    // Ensure discount doesn't decrease (only increases)
    return max(baseDiscount, currentDiscount);
  }

  /// Calculate discounted price
  double _calculateDiscountedPrice(double originalPrice, double discountPercentage) {
    return originalPrice * (1 - discountPercentage / 100);
  }

  /// Apply discount to product
  Future<void> _applyDiscount(
    String productId,
    ProductModel product,
    double discountPercentage,
    DateTime now,
  ) async {
    final newPrice = _calculateDiscountedPrice(product.price, discountPercentage);

    await _firestore.collection('products').doc(productId).update({
      'discountPercentage': discountPercentage,
      'originalPrice': product.price,
      'price': newPrice,
      'isOnSale': discountPercentage > 0,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Log discount changes
  Future<void> _logDiscountChange(String productId, Map<String, dynamic> change) async {
    await _discountHistoryCollection(productId).add(change);
  }

  /// Get products expiring soon
  Future<List<ProductModel>> getExpiringProducts(
    String shopId, {
    int daysAhead = 7,
  }) async {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: daysAhead));

    try {
      final snapshot = await _productsCollection(shopId)
          .where('expiryDate', isGreaterThan: Timestamp.fromDate(now))
          .where('expiryDate', isLessThan: Timestamp.fromDate(futureDate))
          .orderBy('expiryDate', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting expiring products: $e');
      return [];
    }
  }

  /// Get expired products
  Future<List<ProductModel>> getExpiredProducts(String shopId) async {
    final now = DateTime.now();

    try {
      final snapshot = await _productsCollection(shopId)
          .where('expiryDate', isLessThan: Timestamp.fromDate(now))
          .get();

      return snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting expired products: $e');
      return [];
    }
  }

  /// Mark product as expired and unavailable
  Future<void> markAsExpired(String shopId, String productId) async {
    await _firestore.collection('products').doc(productId).update({
      'isAvailable': false,
      'status': 'expired',
      'updatedAt': Timestamp.now(),
    });

    // Log the expiry
    await _expiryLogsCollection(shopId).add({
      'productId': productId,
      'action': 'marked_expired',
      'timestamp': Timestamp.now(),
    });
  }

  /// Remove expired products from sale
  Future<void> removeExpiredProducts(String shopId) async {
    final expiredProducts = await getExpiredProducts(shopId);

    for (final product in expiredProducts) {
      await markAsExpired(shopId, product.id);
    }

    if (expiredProducts.isNotEmpty) {
      _analyticsService.trackEvent('expired_products_removed', {
        'shopId': shopId,
        'count': expiredProducts.length,
      });
    }
  }

  /// Set expiry date for a product
  Future<void> setExpiryDate(
    String productId,
    DateTime expiryDate,
    String shopId,
  ) async {
    await _firestore.collection('products').doc(productId).update({
      'expiryDate': Timestamp.fromDate(expiryDate),
      'updatedAt': Timestamp.now(),
    });

    // Log the change
    await _expiryLogsCollection(shopId).add({
      'productId': productId,
      'action': 'expiry_date_set',
      'expiryDate': Timestamp.fromDate(expiryDate),
      'timestamp': Timestamp.now(),
    });
  }

  /// Get expiry analytics for a shop
  Future<Map<String, dynamic>> getExpiryAnalytics(String shopId) async {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    try {
      // Get counts
      final expiringSoonSnapshot = await _productsCollection(shopId)
          .where('expiryDate', isGreaterThan: Timestamp.fromDate(now))
          .where('expiryDate', isLessThan: Timestamp.fromDate(weekFromNow))
          .get();

      final expiredSnapshot = await _productsCollection(shopId)
          .where('expiryDate', isLessThan: Timestamp.fromDate(now))
          .get();

      // Calculate potential waste value
      double potentialWasteValue = 0;
      for (final doc in expiredSnapshot.docs) {
        final product = ProductModel.fromMap(doc.data() as Map<String, dynamic>);
        potentialWasteValue += product.price * product.stockQuantity;
      }

      // Calculate saved value from dynamic discounts
      final discountSnapshot = await _firestore
          .collectionGroup('discount_history')
          .where('reason', isEqualTo: 'expiry_dynamic')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(now.subtract(const Duration(days: 7))))
          .get();

      double savedFromDiscounts = 0;
      for (final doc in discountSnapshot.docs) {
        final data = doc.data();
        savedFromDiscounts += (data['newDiscount'] - data['previousDiscount']);
      }

      return {
        'expiringSoonCount': expiringSoonSnapshot.docs.length,
        'expiredCount': expiredSnapshot.docs.length,
        'potentialWasteValue': potentialWasteValue.round(),
        'savedFromDiscounts': savedFromDiscounts.round(),
        'weekFromNow': weekFromNow,
        'generatedAt': now,
      };
    } catch (e) {
      print('Error getting expiry analytics: $e');
      return {
        'expiringSoonCount': 0,
        'expiredCount': 0,
        'potentialWasteValue': 0,
        'savedFromDiscounts': 0,
      };
    }
  }

  /// Send expiry warnings to shop owner
  Future<void> sendExpiryWarnings(String shopId) async {
    try {
      final expiringProducts = await getExpiringProducts(shopId, daysAhead: 3);

      if (expiringProducts.isEmpty) return;

      // Get shop owner
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      final ownerId = shopDoc.data()?['ownerId'];

      if (ownerId == null) return;

      // Group by urgency
      final critical = expiringProducts.where((p) {
        final hours = p.expiryDate!.difference(DateTime.now()).inHours;
        return hours <= 24;
      }).toList();

      final warning = expiringProducts.where((p) {
        final hours = p.expiryDate!.difference(DateTime.now()).inHours;
        return hours > 24 && hours <= 72;
      }).toList();

      // Send critical alert
      if (critical.isNotEmpty) {
        final names = critical.map((p) => p.name).join(', ');
        await _notificationService.sendNotificationToUser(
          userId: ownerId,
          title: '🚨 Expiring Soon!',
          body: '$names expiring within 24 hours! Dynamic discounts applied.',
          data: {
            'type': 'expiry_critical',
            'shopId': shopId,
            'count': critical.length.toString(),
          },
        );
      }

      // Send warning
      if (warning.isNotEmpty) {
        await _notificationService.sendNotificationToUser(
          userId: ownerId,
          title: '⚠️ Products Expiring Soon',
          body: '${warning.length} products expiring in the next 3 days.',
          data: {
            'type': 'expiry_warning',
            'shopId': shopId,
            'count': warning.length.toString(),
          },
        );
      }
    } catch (e) {
      print('Error sending expiry warnings: $e');
    }
  }

  /// Get discount history for a product
  Stream<List<Map<String, dynamic>>> getDiscountHistory(String productId) {
    return _discountHistoryCollection(productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Manual discount override
  Future<void> overrideDiscount(
    String productId,
    double discountPercentage,
    String reason,
    String shopId,
  ) async {
    final productDoc = await _firestore.collection('products').doc(productId).get();
    final product = ProductModel.fromMap(productDoc.data() as Map<String, dynamic>);

    final previousDiscount = product.discountPercentage ?? 0;
    final newPrice = _calculateDiscountedPrice(product.price, discountPercentage);

    await _firestore.collection('products').doc(productId).update({
      'discountPercentage': discountPercentage,
      'price': newPrice,
      'isOnSale': discountPercentage > 0,
      'updatedAt': Timestamp.now(),
    });

    // Log the override
    await _expiryLogsCollection(shopId).add({
      'productId': productId,
      'action': 'manual_override',
      'previousDiscount': previousDiscount,
      'newDiscount': discountPercentage,
      'reason': reason,
      'timestamp': Timestamp.now(),
    });
  }

  /// Reset discount to original price
  Future<void> resetDiscount(String productId, String shopId) async {
    final productDoc = await _firestore.collection('products').doc(productId).get();
    final product = ProductModel.fromMap(productDoc.data() as Map<String, dynamic>);

    await _firestore.collection('products').doc(productId).update({
      'discountPercentage': null,
      'price': product.originalPrice ?? product.price,
      'isOnSale': false,
      'updatedAt': Timestamp.now(),
    });

    // Log the reset
    await _expiryLogsCollection(shopId).add({
      'productId': productId,
      'action': 'discount_reset',
      'previousDiscount': product.discountPercentage,
      'timestamp': Timestamp.now(),
    });
  }
}
