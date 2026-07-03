import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import 'notification_service.dart';
import 'analytics_service.dart';

/// Inventory Alert Service for Smart Low-Stock Predictions
/// Uses moving average forecasting to predict stockouts and send notifications
class InventoryAlertService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Configuration
  static const int _defaultForecastDays = 7; // days

  // Collection references
  CollectionReference _productsCollection(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('products');

  CollectionReference _salesHistoryCollection(String productId) =>
      _firestore.collection('products').doc(productId).collection('sales_history');

  CollectionReference _alertsCollection(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('inventory_alerts');

  /// Calculate sales velocity for a product
  /// Returns average daily sales based on historical data
  Future<double> calculateSalesVelocity(String productId, {int days = 30}) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      // Get sales history
      final snapshot = await _salesHistoryCollection(
        productId,
      ).where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate)).get();

      if (snapshot.docs.isEmpty) {
        // Fallback: Query from actual completed orders in '/orders'
        final ordersSnapshot = await _firestore
            .collection('orders')
            .where('status', isEqualTo: 'delivered')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();
        int totalUnits = 0;
        for (var doc in ordersSnapshot.docs) {
          final items = (doc.data()['items'] as List?) ?? [];
          for (var item in items) {
            if (item['productId'] == productId) {
              totalUnits += (item['quantity'] as num?)?.toInt() ?? 0;
            }
          }
        }
        return totalUnits / days;
      }

      // Calculate total units sold
      int totalUnits = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        totalUnits += (data?['quantity'] as int?) ?? 0;
      }

      // Return average daily sales
      return totalUnits / days;
    } catch (e) {
      print('Error calculating sales velocity: $e');
      return 0.0;
    }
  }

  /// Calculate sales velocity with trend analysis
  /// Returns velocity and trend direction (increasing/decreasing/stable)
  Future<Map<String, dynamic>> calculateSalesVelocityWithTrend(
    String productId, {
    int days = 30,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      final midDate = now.subtract(Duration(days: days ~/ 2));

      // Get first half sales
      var firstHalfSnapshot = await _salesHistoryCollection(productId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThan: Timestamp.fromDate(midDate))
          .get();

      // Get second half sales
      var secondHalfSnapshot = await _salesHistoryCollection(
        productId,
      ).where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(midDate)).get();

      int firstHalfUnits = 0;
      int secondHalfUnits = 0;
      int totalDataPoints = firstHalfSnapshot.docs.length + secondHalfSnapshot.docs.length;

      if (totalDataPoints == 0) {
        // Fallback: Query from actual completed orders in '/orders'
        final firstHalfOrders = await _firestore
            .collection('orders')
            .where('status', isEqualTo: 'delivered')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('createdAt', isLessThan: Timestamp.fromDate(midDate))
            .get();

        final secondHalfOrders = await _firestore
            .collection('orders')
            .where('status', isEqualTo: 'delivered')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(midDate))
            .get();

        for (var doc in firstHalfOrders.docs) {
          final items = (doc.data()['items'] as List?) ?? [];
          for (var item in items) {
            if (item['productId'] == productId) {
              firstHalfUnits += (item['quantity'] as num?)?.toInt() ?? 0;
            }
          }
        }

        for (var doc in secondHalfOrders.docs) {
          final items = (doc.data()['items'] as List?) ?? [];
          for (var item in items) {
            if (item['productId'] == productId) {
              secondHalfUnits += (item['quantity'] as num?)?.toInt() ?? 0;
            }
          }
        }
        totalDataPoints = firstHalfOrders.docs.length + secondHalfOrders.docs.length;
      } else {
        for (final doc in firstHalfSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          firstHalfUnits += (data?['quantity'] as int?) ?? 0;
        }

        for (final doc in secondHalfSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          secondHalfUnits += (data?['quantity'] as int?) ?? 0;
        }
      }

      final double firstHalfVelocity = firstHalfUnits / (days / 2);
      final double secondHalfVelocity = secondHalfUnits / (days / 2);

      // Calculate trend
      String trend = 'stable';
      double trendPercentage = 0;

      if (secondHalfVelocity > firstHalfVelocity * 1.1) {
        trend = 'increasing';
        trendPercentage = firstHalfVelocity > 0
            ? ((secondHalfVelocity - firstHalfVelocity) / firstHalfVelocity) * 100
            : 100.0;
      } else if (secondHalfVelocity < firstHalfVelocity * 0.9) {
        trend = 'decreasing';
        trendPercentage = firstHalfVelocity > 0
            ? ((firstHalfVelocity - secondHalfVelocity) / firstHalfVelocity) * 100
            : 0.0;
      }

      return {
        'velocity': secondHalfVelocity,
        'trend': trend,
        'trendPercentage': trendPercentage.round(),
        'confidence': _calculateConfidence(totalDataPoints),
      };
    } catch (e) {
      print('Error calculating sales velocity with trend: $e');
      return {'velocity': 0.0, 'trend': 'stable', 'trendPercentage': 0, 'confidence': 0.0};
    }
  }

  /// Predict stockout days (wrapper for predictDaysUntilStockout for naming parity)
  Future<int> predictStockout(String productId, int currentStock) async {
    return predictDaysUntilStockout(productId, currentStock);
  }

  /// Get restock suggestions for items predicted to run out within 3 days
  Future<List<Map<String, dynamic>>> getRestockSuggestions(String shopId) async {
    final alerts = await checkLowStock(shopId);
    return alerts.where((alert) => (alert['daysUntilStockout'] as int) <= 3).toList();
  }

  /// Calculate confidence level based on data points
  double _calculateConfidence(int dataPoints) {
    if (dataPoints >= 100) return 1.0;
    if (dataPoints >= 50) return 0.9;
    if (dataPoints >= 20) return 0.7;
    if (dataPoints >= 10) return 0.5;
    return 0.3;
  }

  /// Predict days until stockout
  Future<int> predictDaysUntilStockout(
    String productId,
    int currentStock, {
    Map<String, dynamic>? precalculatedVelocity,
  }) async {
    final velocityData = precalculatedVelocity ?? await calculateSalesVelocityWithTrend(productId);
    final velocity = velocityData['velocity'] as double;

    if (velocity <= 0) {
      return 999; // No sales data, assume infinite stock
    }

    // Calculate days until stockout
    final daysUntilStockout = (currentStock / velocity).floor();

    // Apply trend adjustment
    final trend = velocityData['trend'] as String;
    if (trend == 'increasing') {
      // Stock will run out faster than predicted
      return (daysUntilStockout * 0.8).floor();
    } else if (trend == 'decreasing') {
      // Stock will last longer than predicted
      return (daysUntilStockout * 1.2).floor();
    }

    return daysUntilStockout;
  }

  /// Calculate reorder quantity recommendation
  Future<int> calculateReorderQuantity(
    String productId,
    int currentStock, {
    int leadTimeDays = 3,
    int safetyStockDays = 2,
    Map<String, dynamic>? precalculatedVelocity,
  }) async {
    final velocityData = precalculatedVelocity ?? await calculateSalesVelocityWithTrend(productId);
    final velocity = velocityData['velocity'] as double;

    if (velocity <= 0) {
      return currentStock; // No sales data, maintain current stock
    }

    // Calculate recommended order quantity
    final leadTimeDemand = velocity * leadTimeDays;
    final safetyStock = velocity * safetyStockDays;
    final recommendedQuantity = leadTimeDemand + safetyStock - currentStock;

    // Round up to nearest whole number and ensure minimum order
    final minOrder = (velocity * 7).ceil(); // At least 1 week of stock
    return max(recommendedQuantity.ceil(), minOrder).toInt();
  }

  /// Check all products for low stock and generate alerts
  Future<List<Map<String, dynamic>>> checkLowStock(String shopId) async {
    final alerts = <Map<String, dynamic>>[];
    final now = DateTime.now();

    try {
      // Get all products for this shop
      final snapshot = await _productsCollection(shopId).get();

      for (final doc in snapshot.docs) {
        final product = ProductModel.fromMap(doc.data() as Map<String, dynamic>);

        // Skip unavailable products
        if (!product.isAvailable) continue;

        // Calculate velocity and prediction
        final velocityData = await calculateSalesVelocityWithTrend(product.id);
        final velocity = velocityData['velocity'] as double;
        final trend = velocityData['trend'] as String;
        final confidence = velocityData['confidence'] as double;

        // Calculate days until stockout
        final daysUntilStockout = await predictDaysUntilStockout(
          product.id,
          product.stockQuantity,
          precalculatedVelocity: velocityData,
        );

        // Check if low stock alert needed
        if (daysUntilStockout <= _defaultForecastDays) {
          final alert = {
            'productId': product.id,
            'productName': product.name,
            'currentStock': product.stockQuantity,
            'dailyVelocity': velocity.round(),
            'daysUntilStockout': daysUntilStockout,
            'trend': trend,
            'confidence': confidence,
            'reorderQuantity': await calculateReorderQuantity(
              product.id,
              product.stockQuantity,
              precalculatedVelocity: velocityData,
            ),
            'createdAt': now,
            'severity': _calculateSeverity(daysUntilStockout, confidence),
          };

          alerts.add(alert);

          // Save alert to Firestore
          await _alertsCollection(
            shopId,
          ).doc(product.id).set({...alert, 'createdAt': Timestamp.fromDate(now)});
        }
      }

      // Sort alerts by severity
      alerts.sort((a, b) => a['severity'].compareTo(b['severity']));

      return alerts;
    } catch (e) {
      print('Error checking low stock: $e');
      return [];
    }
  }

  /// Calculate alert severity
  int _calculateSeverity(int daysUntilStockout, double confidence) {
    // Higher severity = more urgent
    if (daysUntilStockout <= 1) return 5; // Critical
    if (daysUntilStockout <= 2) return 4; // High
    if (daysUntilStockout <= 3) return 3; // Medium
    if (daysUntilStockout <= 5) return 2; // Low
    return 1; // Warning
  }

  /// Send low stock notifications to shop owner
  Future<void> sendLowStockNotifications(String shopId) async {
    try {
      final alerts = await checkLowStock(shopId);

      if (alerts.isEmpty) return;

      // Get shop owner info
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      final ownerId = shopDoc.data()?['ownerId'];

      if (ownerId == null) return;

      // Group alerts by severity
      final criticalAlerts = alerts.where((a) => a['severity'] >= 4).toList();
      final warningAlerts = alerts.where((a) => a['severity'] < 4).toList();

      // Send critical alert
      if (criticalAlerts.isNotEmpty) {
        final productNames = criticalAlerts.map((a) => a['productName']).join(', ');
        await _notificationService.sendNotificationToUser(
          userId: ownerId,
          title: '🚨 Critical: Low Stock Alert!',
          body: '$productNames are running out of stock! Order immediately.',
          data: {
            'type': 'low_stock_critical',
            'shopId': shopId,
            'alertCount': criticalAlerts.length.toString(),
          },
        );

        // Track analytics
        _analyticsService.trackEvent('low_stock_critical', {
          'shopId': shopId,
          'productCount': criticalAlerts.length,
          'products': productNames,
        });
      }

      // Send warning alert
      if (warningAlerts.isNotEmpty) {
        final count = warningAlerts.length;
        await _notificationService.sendNotificationToUser(
          userId: ownerId,
          title: '⚠️ Stock Running Low',
          body: '$count items need restocking soon. Check your inventory.',
          data: {'type': 'low_stock_warning', 'shopId': shopId, 'alertCount': count.toString()},
        );
      }

      // Send WhatsApp message if configured
      await _sendWhatsAppAlert(shopId, alerts);
    } catch (e) {
      print('Error sending low stock notifications: $e');
    }
  }

  /// Send WhatsApp alert for low stock
  Future<void> _sendWhatsAppAlert(String shopId, List<Map<String, dynamic>> alerts) async {
    try {
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      final phone = shopDoc.data()?['phoneNumber'];

      if (phone == null) return;

      // This would integrate with WhatsApp service
      // For now, just log
      print('Would send WhatsApp alert to $phone for ${alerts.length} low stock items');
    } catch (e) {
      print('Error sending WhatsApp alert: $e');
    }
  }

  /// Get active alerts for a shop
  Stream<List<Map<String, dynamic>>> getActiveAlerts(String shopId) {
    return _alertsCollection(shopId).orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Dismiss an alert
  Future<void> dismissAlert(String shopId, String productId) async {
    await _alertsCollection(shopId).doc(productId).delete();
  }

  /// Mark alert as actioned
  Future<void> markAlertActioned(String shopId, String productId) async {
    await _alertsCollection(shopId).doc(productId).update({
      'actionedAt': Timestamp.fromDate(DateTime.now()),
      'status': 'actioned',
    });
  }

  /// Record a sale for velocity tracking
  Future<void> recordSale(String productId, int quantity) async {
    try {
      await _salesHistoryCollection(
        productId,
      ).add({'quantity': quantity, 'createdAt': Timestamp.now()});

      // Keep only last 90 days of data
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final oldDocs = await _salesHistoryCollection(
        productId,
      ).where('createdAt', isLessThan: Timestamp.fromDate(cutoff)).get();

      for (final doc in oldDocs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error recording sale: $e');
    }
  }

  /// Get inventory health score for a shop
  Future<Map<String, dynamic>> getInventoryHealthScore(String shopId) async {
    try {
      final snapshot = await _productsCollection(shopId).get();
      final products = snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((p) => p.isAvailable)
          .toList();

      if (products.isEmpty) {
        return {
          'score': 0,
          'status': 'no_products',
          'totalProducts': 0,
          'lowStockCount': 0,
          'outOfStockCount': 0,
          'healthyCount': 0,
        };
      }

      int lowStockCount = 0;
      int outOfStockCount = 0;
      int healthyCount = 0;

      for (final product in products) {
        final daysUntilStockout = await predictDaysUntilStockout(product.id, product.stockQuantity);

        if (product.stockQuantity == 0) {
          outOfStockCount++;
        } else if (daysUntilStockout <= 3) {
          lowStockCount++;
        } else {
          healthyCount++;
        }
      }

      // Calculate health score (0-100)
      final total = products.length;
      final score = ((healthyCount / total) * 100).round();

      String status;
      if (score >= 80) {
        status = 'healthy';
      } else if (score >= 60) {
        status = 'warning';
      } else if (score >= 40) {
        status = 'critical';
      } else {
        status = 'critical';
      }

      return {
        'score': score,
        'status': status,
        'totalProducts': total,
        'lowStockCount': lowStockCount,
        'outOfStockCount': outOfStockCount,
        'healthyCount': healthyCount,
      };
    } catch (e) {
      print('Error calculating inventory health: $e');
      return {
        'score': 0,
        'status': 'error',
        'totalProducts': 0,
        'lowStockCount': 0,
        'outOfStockCount': 0,
        'healthyCount': 0,
      };
    }
  }

  /// Generate restocking report
  Future<Map<String, dynamic>> generateRestockingReport(String shopId) async {
    final alerts = await checkLowStock(shopId);
    final healthScore = await getInventoryHealthScore(shopId);

    final now = DateTime.now();

    // Group by urgency
    final critical = alerts.where((a) => a['severity'] >= 4).toList();
    final important = alerts.where((a) => a['severity'] == 3).toList();
    final warning = alerts.where((a) => a['severity'] <= 2).toList();

    // Calculate total reorder cost (mock calculation)
    final totalReorderCost = alerts.fold<int>(
      0,
      (total, alert) => total + (alert['reorderQuantity'] as int) * 50, // Mock price
    );

    return {
      'generatedAt': now,
      'shopId': shopId,
      'healthScore': healthScore,
      'summary': {
        'criticalCount': critical.length,
        'importantCount': important.length,
        'warningCount': warning.length,
        'totalAlerts': alerts.length,
      },
      'criticalItems': critical,
      'importantItems': important,
      'warningItems': warning,
      'estimatedReorderCost': totalReorderCost,
      'recommendations': _generateRecommendations(alerts, healthScore),
    };
  }

  /// Generate recommendations based on alerts
  List<String> _generateRecommendations(
    List<Map<String, dynamic>> alerts,
    Map<String, dynamic> healthScore,
  ) {
    final recommendations = <String>[];

    if (healthScore['score'] < 50) {
      recommendations.add('⚠️ Your inventory health is critical. Immediate restocking required.');
    }

    final criticalCount = alerts.where((a) => a['severity'] >= 4).length;
    if (criticalCount > 0) {
      recommendations.add('🚨 $criticalCount items are critically low. Order immediately.');
    }

    // Check for trending items
    final trendingUp = alerts.where((a) => a['trend'] == 'increasing').length;
    if (trendingUp > 0) {
      recommendations.add(
        '📈 $trendingUp items have increasing demand. Consider increasing stock.',
      );
    }

    // Check for seasonal patterns
    final decreasing = alerts.where((a) => a['trend'] == 'decreasing').length;
    if (decreasing > alerts.length * 0.5 && alerts.isNotEmpty) {
      recommendations.add('📉 Several items show decreasing demand. Review pricing or promotions.');
    }

    return recommendations;
  }

  // Feature 105: Final AI-driven inventory forecasting engine
  Future<Map<String, dynamic>> getForecastingMetrics(String productId) async {
    // Advanced heuristic: Moving average of daily demand + lead time safety buffer
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final salesSnapshot = await _firestore
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .where('createdAt', isGreaterThan: thirtyDaysAgo)
        .get();

    double totalSold = 0;
    for (var doc in salesSnapshot.docs) {
      final items = (doc.data()['items'] as List?) ?? [];
      for (var item in items) {
        if (item['productId'] == productId) {
          totalSold += (item['quantity'] ?? 0);
        }
      }
    }

    final dailyDemand = totalSold / 30;
    final productDoc = await _firestore.collection('products').doc(productId).get();
    final currentStock = (productDoc.data()?['stockQuantity'] ?? 0).toDouble();

    final daysRemaining = dailyDemand > 0 ? currentStock / dailyDemand : 999.0;

    return {
      'dailyDemand': dailyDemand.toStringAsFixed(2),
      'daysUntilStockout': daysRemaining.toStringAsFixed(1),
      'recommendedRestockDate': now.add(Duration(days: daysRemaining.toInt())),
      'confidenceScore': totalSold > 5 ? 0.85 : 0.40,
    };
  }
}
