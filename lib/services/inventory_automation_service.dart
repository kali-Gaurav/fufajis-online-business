import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/low_stock_alert_model.dart' show LowStockAlert;
import '../models/product_model.dart';
// notification_service imported for FCM queue

/// Smart Inventory Automation Service
///
/// Features:
/// - Predictive reorder-point calculation (demand velocity × lead time)
/// - Multi-tier alert levels: LOW → CRITICAL → OUT_OF_STOCK
/// - FCM push to owner on threshold breach
/// - Expiry-proximity alerts (14-day and 3-day warnings)
/// - Auto-generates suggested Purchase Order quantities (EOQ formula)
/// - Writes alerts to Firestore `inventory_alerts` collection for dashboard widget
class InventoryAutomationService {
  static final InventoryAutomationService _instance =
      InventoryAutomationService._internal();
  factory InventoryAutomationService() => _instance;
  InventoryAutomationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Alert thresholds ─────────────────────────────────────────────────────────
  static const int _criticalThreshold = 2;    // units — bright red badge
  static const int _lowThreshold = 5;         // units — orange warning
  static const int _defaultReorderPoint = 10; // fallback if no sales history

  // ─── Main entry: call from Cloud Function cron or owner dashboard ─────────────
  Future<Map<String, dynamic>> runFullInventoryCheck({
    String shopId = 'shop_001',
  }) async {
    debugPrint('[InvAuto] Starting full inventory check for $shopId…');

    final results = <String, dynamic>{
      'lowStock': <String>[],
      'criticalStock': <String>[],
      'outOfStock': <String>[],
      'expiringItems': <String>[],
      'purchaseOrderSuggestions': <Map<String, dynamic>>[],
      'checkedAt': DateTime.now().toIso8601String(),
    };

    try {
      // 1. Stock level alerts
      await _checkStockLevels(shopId: shopId, results: results);

      // 2. Expiry alerts
      await _checkExpiryDates(shopId: shopId, results: results);

      // 3. Push FCM notification if any alerts triggered
      await _pushAlertsToOwner(shopId: shopId, results: results);

      debugPrint('[InvAuto] Check complete. Alerts: ${results['criticalStock']}');
    } catch (e) {
      debugPrint('[InvAuto] Error during check: $e');
    }

    return results;
  }

  // ─── Stock level check ────────────────────────────────────────────────────────
  Future<void> _checkStockLevels({
    required String shopId,
    required Map<String, dynamic> results,
  }) async {
    final snapshot = await _db
        .collection('products')
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _db.batch();
    final now = Timestamp.now();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final product = ProductModel.fromMap({...data, 'id': doc.id});
      final stock = product.stockQuantity;

      // Compute demand velocity (units sold in last 30 days)
      final velocity = await _getDemandVelocity(doc.id);
      final reorderPoint = _computeReorderPoint(velocity);
      final eoqQty = _economicOrderQuantity(
        velocity: velocity,
        costPrice: product.costPrice ?? (product.price.toDouble() * 0.6),
      );

      String? alertLevel;
      if (stock <= 0) {
        alertLevel = 'out_of_stock';
        (results['outOfStock'] as List<String>).add(product.name);
      } else if (stock <= _criticalThreshold) {
        alertLevel = 'critical';
        (results['criticalStock'] as List<String>).add(product.name);
      } else if (stock <= _lowThreshold || stock <= reorderPoint) {
        alertLevel = 'low';
        (results['lowStock'] as List<String>).add(product.name);
      }

      if (alertLevel != null) {
        // Write to inventory_alerts for dashboard widget
        final alertRef = _db.collection('inventory_alerts').doc(doc.id);
        batch.set(alertRef, {
          'productId': doc.id,
          'productName': product.name,
          'shopId': shopId,
          'currentStock': stock,
          'reorderPoint': reorderPoint,
          'suggestedOrderQty': eoqQty,
          'alertLevel': alertLevel,
          'velocity': velocity,
          'updatedAt': now,
        }, SetOptions(merge: true));

        // Add purchase order suggestion
        (results['purchaseOrderSuggestions'] as List<Map<String, dynamic>>).add({
          'productId': doc.id,
          'productName': product.name,
          'currentStock': stock,
          'suggestedQty': eoqQty,
          'estimatedCost': eoqQty * (product.costPrice ?? (product.price.toDouble() * 0.6)),
        });
      } else {
        // Clear old alert if stock is healthy
        final alertRef = _db.collection('inventory_alerts').doc(doc.id);
        batch.delete(alertRef);
      }
    }

    await batch.commit();
  }

  // ─── Expiry date check ────────────────────────────────────────────────────────
  Future<void> _checkExpiryDates({
    required String shopId,
    required Map<String, dynamic> results,
  }) async {
    final now = DateTime.now();
    final warningDate14 = now.add(const Duration(days: 14));

    final snapshot = await _db
        .collection('product_batches')
        .where('shopId', isEqualTo: shopId)
        .where('expiryDate', isLessThanOrEqualTo: warningDate14)
        .get();

    for (final doc in snapshot.docs) {
      final expiry = (doc['expiryDate'] as Timestamp).toDate();
      final daysLeft = expiry.difference(now).inDays;
      final name = doc['productName'] ?? 'Unknown';

      final isCritical = daysLeft <= 3;
      final label = isCritical ? '⚠️ EXPIRING IN $daysLeft DAYS' : 'Expiring in $daysLeft days';
      (results['expiringItems'] as List<String>).add('$name — $label');

      // Update batch document with alert flag
      await doc.reference.update({
        'expiryAlertLevel': isCritical ? 'critical' : 'warning',
        'daysUntilExpiry': daysLeft,
        'lastCheckedAt': Timestamp.now(),
      });
    }
  }

  // ─── FCM push to owner ────────────────────────────────────────────────────────
  Future<void> _pushAlertsToOwner({
    required String shopId,
    required Map<String, dynamic> results,
  }) async {
    final critical = (results['criticalStock'] as List<String>);
    final low = (results['lowStock'] as List<String>);
    final outOfStock = (results['outOfStock'] as List<String>);
    final expiring = (results['expiringItems'] as List<String>);

    if (critical.isEmpty && low.isEmpty && outOfStock.isEmpty && expiring.isEmpty) {
      return; // Nothing to alert
    }

    // Build human-readable message
    final parts = <String>[];
    if (outOfStock.isNotEmpty) {
      parts.add('🚫 Out of stock: ${outOfStock.take(3).join(", ")}');
    }
    if (critical.isNotEmpty) {
      parts.add('🔴 Critical: ${critical.take(3).join(", ")}');
    }
    if (low.isNotEmpty) {
      parts.add('🟡 Low stock: ${low.take(3).join(", ")}');
    }
    if (expiring.isNotEmpty) {
      parts.add('⏰ Expiring: ${expiring.take(2).join(", ")}');
    }

    final body = parts.join(' | ');

    // Get owner FCM tokens
    final ownerQuery = await _db
        .collection('users')
        .where('role', isEqualTo: 'UserRole.owner')
        .where('shopId', isEqualTo: shopId)
        .get();

    for (final ownerDoc in ownerQuery.docs) {
      final fcmToken = ownerDoc.data()['fcmToken'] as String?;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        // Queue FCM notification for Cloud Function delivery
        await _db.collection('notification_queue').add({
          'userId': ownerDoc.id,
          'fcmToken': fcmToken,
          'title': '📦 Inventory Alert — Fufaji\'s',
          'body': body,
          'data': {
            'type': 'inventory_alert',
            'shopId': shopId,
            'route': '/owner/inventory-alerts',
          },
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Also write a notification document for in-app notification center
    await _db.collection('notifications').add({
      'shopId': shopId,
      'type': 'inventory_alert',
      'title': '📦 Inventory Alert',
      'body': body,
      'isRead': false,
      'createdAt': Timestamp.now(),
      'data': {
        'criticalCount': critical.length,
        'lowCount': low.length,
        'outOfStockCount': outOfStock.length,
        'expiringCount': expiring.length,
      },
    });
  }

  // ─── Demand velocity (units sold / 30 days) ───────────────────────────────────
  Future<double> _getDemandVelocity(String productId) async {
    try {
      final thirtyDaysAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30)),
      );
      final snapshot = await _db
          .collection('order_items')
          .where('productId', isEqualTo: productId)
          .where('createdAt', isGreaterThan: thirtyDaysAgo)
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        total += (doc['quantity'] as num? ?? 1).toDouble();
      }
      return total / 30; // avg units/day
    } catch (_) {
      return 1.0; // fallback: assume 1 unit/day
    }
  }

  // ─── Reorder point = velocity × lead time days ────────────────────────────────
  int _computeReorderPoint(double velocityPerDay, {int leadTimeDays = 3}) {
    final rp = (velocityPerDay * leadTimeDays).ceil();
    return rp.clamp(_defaultReorderPoint, 100);
  }

  // ─── Economic Order Quantity (EOQ) = √(2DS/H) ────────────────────────────────
  int _economicOrderQuantity({
    required double velocity,
    required double costPrice,
    double holdingCostPct = 0.20,
    double orderingCost = 50.0,
  }) {
    if (velocity <= 0 || costPrice <= 0) return 10;
    final annual = velocity * 365;
    final holding = costPrice * holdingCostPct;
    final eoq = (2 * annual * orderingCost / holding);
    return eoq.isFinite ? eoq.ceil().clamp(5, 500) : 10;
  }

  // ─── Public: get active alerts stream for dashboard widget ───────────────────
  Stream<List<LowStockAlert>> watchActiveAlerts({
    String shopId = 'shop_001',
  }) {
    return _db
        .collection('inventory_alerts')
        .where('shopId', isEqualTo: shopId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LowStockAlert.fromMap(d.data()))
            .toList());
  }

  // ─── Public: quick check single product ──────────────────────────────────────
  Future<String?> getAlertLevel(String productId) async {
    final doc =
        await _db.collection('inventory_alerts').doc(productId).get();
    return doc.exists ? doc['alertLevel'] as String? : null;
  }
}
