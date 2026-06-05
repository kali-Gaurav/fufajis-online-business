import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

/// Service for Idea 27: Smart Kitchen Integration
///
/// Analyzes purchase history to predict when a customer will run out of staples
/// and suggests replenishment.
class SmartKitchenService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final SmartKitchenService _instance = SmartKitchenService._internal();
  factory SmartKitchenService() => _instance;
  SmartKitchenService._internal();

  /// Analyzes user's delivered orders to find products bought 3+ times
  /// and calculates their average replenishment interval.
  Future<List<StaplePrediction>> predictReplenishmentNeeds(String userId) async {
    try {
      // 1. Fetch last 50 delivered orders
      final snapshot = await _db
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'OrderStatus.delivered')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) return [];

      final orders = snapshot.docs.map((doc) => OrderModel.fromMap(doc.data())).toList();
      
      // 2. Map occurrences and purchase dates per product
      final Map<String, List<DateTime>> productPurchaseDates = {};
      final Map<String, OrderItem> productDetails = {};

      for (var order in orders) {
        for (var item in order.items) {
          productPurchaseDates.putIfAbsent(item.productId, () => []);
          productPurchaseDates[item.productId]!.add(order.createdAt);
          productDetails.putIfAbsent(item.productId, () => item);
        }
      }

      final List<StaplePrediction> predictions = [];

      // 3. Calculate intervals for "Staples" (bought 3+ times)
      productPurchaseDates.forEach((productId, dates) {
        if (dates.length >= 3) {
          // Dates are in descending order (latest first)
          final latestDate = dates.first;
          
          double totalDays = 0;
          int intervalCount = 0;

          for (int i = 0; i < dates.length - 1; i++) {
            final diff = dates[i].difference(dates[i + 1]).inDays;
            if (diff > 0) {
              totalDays += diff;
              intervalCount++;
            }
          }

          if (intervalCount > 0) {
            final avgIntervalDays = totalDays / intervalCount;
            final nextPredictedDate = latestDate.add(Duration(days: avgIntervalDays.round()));
            
            final daysRemaining = nextPredictedDate.difference(DateTime.now()).inDays;
            final isRunningLow = daysRemaining <= 2;

            final item = productDetails[productId]!;

            predictions.add(StaplePrediction(
              productId: productId,
              productName: item.productName,
              productImage: item.productImage,
              avgIntervalDays: avgIntervalDays,
              lastPurchasedAt: latestDate,
              nextPredictedDate: nextPredictedDate,
              daysRemaining: daysRemaining,
              isRunningLow: isRunningLow,
              purchaseCount: dates.length,
            ));
          }
        }
      });

      // Sort by urgency (days remaining)
      predictions.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
      
      return predictions;
    } catch (e) {
      debugPrint('[SmartKitchenService] Error predicting needs: $e');
      return [];
    }
  }

  /// Sync prediction results to a dedicated subcollection for easy querying/notifications
  Future<void> refreshUserKitchenData(String userId) async {
    try {
      final predictions = await predictReplenishmentNeeds(userId);
      final batch = _db.batch();
      
      final kitchenRef = _db.collection('users').doc(userId).collection('smart_kitchen');
      
      // Clear old (optional, or just overwrite)
      final existing = await kitchenRef.get();
      for (var doc in existing.docs) {
        batch.delete(doc.reference);
      }

      for (var p in predictions) {
        batch.set(kitchenRef.doc(p.productId), p.toMap());
      }

      await batch.commit();
    } catch (e) {
      debugPrint('[SmartKitchenService] Error syncing kitchen data: $e');
    }
  }
}

class StaplePrediction {
  final String productId;
  final String productName;
  final String? productImage;
  final double avgIntervalDays;
  final DateTime lastPurchasedAt;
  final DateTime nextPredictedDate;
  final int daysRemaining;
  final bool isRunningLow;
  final int purchaseCount;

  StaplePrediction({
    required this.productId,
    required this.productName,
    this.productImage,
    required this.avgIntervalDays,
    required this.lastPurchasedAt,
    required this.nextPredictedDate,
    required this.daysRemaining,
    required this.isRunningLow,
    required this.purchaseCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'avgIntervalDays': avgIntervalDays,
      'lastPurchasedAt': lastPurchasedAt,
      'nextPredictedDate': nextPredictedDate,
      'daysRemaining': daysRemaining,
      'isRunningLow': isRunningLow,
      'purchaseCount': purchaseCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory StaplePrediction.fromMap(Map<String, dynamic> map) {
    return StaplePrediction(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'],
      avgIntervalDays: (map['avgIntervalDays'] ?? 0.0).toDouble(),
      lastPurchasedAt: (map['lastPurchasedAt'] as Timestamp).toDate(),
      nextPredictedDate: (map['nextPredictedDate'] as Timestamp).toDate(),
      daysRemaining: map['daysRemaining'] ?? 0,
      isRunningLow: map['isRunningLow'] ?? false,
      purchaseCount: map['purchaseCount'] ?? 0,
    );
  }
}
