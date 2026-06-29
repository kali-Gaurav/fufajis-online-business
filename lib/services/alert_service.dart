import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/alert_model.dart';

/// Service for managing dashboard alerts
/// Handles creation, retrieval, and resolution of alerts
class AlertService {
  static final AlertService _instance = AlertService._internal();

  factory AlertService() => _instance;

  AlertService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all active (unresolved) alerts
  Future<List<AlertModel>> getActiveAlerts() async {
    try {
      debugPrint('[AlertService] Fetching active alerts');

      final snapshot = await _firestore
          .collection('alerts')
          .where('resolved', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      final alerts = snapshot.docs
          .map((doc) => AlertModel.fromJson({
                ...doc.data(),
                'alertId': doc.id,
              }))
          .toList();

      debugPrint('[AlertService] Found ${alerts.length} active alerts');
      return alerts;
    } catch (e) {
      debugPrint('[AlertService] Error fetching active alerts: $e');
      rethrow;
    }
  }

  /// Listen to active alerts in real-time
  Stream<List<AlertModel>> listenToActiveAlerts() {
    return _firestore
        .collection('alerts')
        .where('resolved', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AlertModel.fromJson({
                ...doc.data(),
                'alertId': doc.id,
              }))
          .toList();
    });
  }

  /// Get all alerts (including resolved)
  Future<List<AlertModel>> getAllAlerts({int limit = 100}) async {
    try {
      debugPrint('[AlertService] Fetching all alerts (limit: $limit)');

      final snapshot = await _firestore
          .collection('alerts')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AlertModel.fromJson({
                ...doc.data(),
                'alertId': doc.id,
              }))
          .toList();
    } catch (e) {
      debugPrint('[AlertService] Error fetching all alerts: $e');
      rethrow;
    }
  }

  /// Generate a low stock alert
  Future<void> generateLowStockAlert({
    required String productId,
    required String productName,
    required int currentStock,
    required int minStock,
  }) async {
    try {
      if (currentStock < minStock) {
        final alert = AlertModel(
          alertId: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.lowStock,
          severity: currentStock == 0 ? AlertSeverity.critical : AlertSeverity.warning,
          title: 'Low Stock: $productName',
          message:
              'Product stock is at $currentStock units (min: $minStock). Consider restocking.',
          action: 'Restock',
          timestamp: DateTime.now(),
          metadata: {
            'productId': productId,
            'productName': productName,
            'currentStock': currentStock,
            'minStock': minStock,
          },
        );

        await _firestore
            .collection('alerts')
            .doc(alert.alertId)
            .set(alert.toJson());

        debugPrint(
            '[AlertService] Low stock alert created for $productName ($currentStock/$minStock)');
      }
    } catch (e) {
      debugPrint('[AlertService] Error generating low stock alert: $e');
      rethrow;
    }
  }

  /// Generate an order stuck alert
  Future<void> generateOrderStuckAlert({
    required String orderId,
    required String status,
    required int hoursWaiting,
  }) async {
    try {
      if (hoursWaiting > 2) {
        final alert = AlertModel(
          alertId: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.orderStuck,
          severity: hoursWaiting > 6 ? AlertSeverity.critical : AlertSeverity.warning,
          title: 'Order Stuck: #$orderId',
          message: 'Order #$orderId has been in $status status for $hoursWaiting hours.',
          action: 'View Order',
          timestamp: DateTime.now(),
          metadata: {
            'orderId': orderId,
            'status': status,
            'hoursWaiting': hoursWaiting,
          },
        );

        await _firestore
            .collection('alerts')
            .doc(alert.alertId)
            .set(alert.toJson());

        debugPrint(
            '[AlertService] Order stuck alert created for order $orderId');
      }
    } catch (e) {
      debugPrint('[AlertService] Error generating order stuck alert: $e');
      rethrow;
    }
  }

  /// Generate a payment failed alert
  Future<void> generatePaymentFailedAlert({
    required String orderId,
    required String customerName,
    required double amount,
    required String failureReason,
  }) async {
    try {
      final alert = AlertModel(
        alertId: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        type: AlertType.paymentFailed,
        severity: AlertSeverity.critical,
        title: 'Payment Failed: Order #$orderId',
        message:
            'Payment of ₹${amount.toStringAsFixed(2)} from $customerName failed due to $failureReason.',
        action: 'Retry Payment',
        timestamp: DateTime.now(),
        metadata: {
          'orderId': orderId,
          'customerName': customerName,
          'amount': amount,
          'failureReason': failureReason,
        },
      );

      await _firestore
          .collection('alerts')
          .doc(alert.alertId)
          .set(alert.toJson());

      debugPrint(
          '[AlertService] Payment failed alert created for order $orderId');
    } catch (e) {
      debugPrint('[AlertService] Error generating payment failed alert: $e');
      rethrow;
    }
  }

  /// Generate a delivery failed alert
  Future<void> generateDeliveryFailedAlert({
    required String deliveryId,
    required String orderId,
    required String deliveryAgentName,
    required String reason,
  }) async {
    try {
      final alert = AlertModel(
        alertId: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        type: AlertType.deliveryFailed,
        severity: AlertSeverity.critical,
        title: 'Delivery Failed: Order #$orderId',
        message:
            'Delivery by $deliveryAgentName failed. Reason: $reason',
        action: 'Reschedule',
        timestamp: DateTime.now(),
        metadata: {
          'deliveryId': deliveryId,
          'orderId': orderId,
          'deliveryAgentName': deliveryAgentName,
          'reason': reason,
        },
      );

      await _firestore
          .collection('alerts')
          .doc(alert.alertId)
          .set(alert.toJson());

      debugPrint(
          '[AlertService] Delivery failed alert created for delivery $deliveryId');
    } catch (e) {
      debugPrint('[AlertService] Error generating delivery failed alert: $e');
      rethrow;
    }
  }

  /// Generate a customer churn alert
  Future<void> generateCustomerChurnAlert({
    required String customerId,
    required String customerName,
    required int daysSinceLastOrder,
  }) async {
    try {
      if (daysSinceLastOrder > 30) {
        final alert = AlertModel(
          alertId: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.customerChurn,
          severity: daysSinceLastOrder > 90 ? AlertSeverity.critical : AlertSeverity.warning,
          title: 'Inactive Customer: $customerName',
          message:
              '$customerName hasn\'t placed an order in $daysSinceLastOrder days.',
          action: 'Send Offer',
          timestamp: DateTime.now(),
          metadata: {
            'customerId': customerId,
            'customerName': customerName,
            'daysSinceLastOrder': daysSinceLastOrder,
          },
        );

        await _firestore
            .collection('alerts')
            .doc(alert.alertId)
            .set(alert.toJson());

        debugPrint(
            '[AlertService] Customer churn alert created for $customerName');
      }
    } catch (e) {
      debugPrint('[AlertService] Error generating customer churn alert: $e');
      rethrow;
    }
  }

  /// Generate a low sales alert
  Future<void> generateLowSalesAlert({
    required String periodName,
    required double currentSales,
    required double expectedSales,
  }) async {
    try {
      final percentageOfExpected = (currentSales / expectedSales) * 100;

      if (percentageOfExpected < 80) {
        final alert = AlertModel(
          alertId: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.lowSales,
          severity: percentageOfExpected < 50 ? AlertSeverity.critical : AlertSeverity.warning,
          title: 'Low Sales Alert',
          message:
              'Sales for $periodName are ₹${currentSales.toStringAsFixed(0)} (${percentageOfExpected.toStringAsFixed(1)}% of expected ₹${expectedSales.toStringAsFixed(0)})',
          action: 'Review',
          timestamp: DateTime.now(),
          metadata: {
            'periodName': periodName,
            'currentSales': currentSales,
            'expectedSales': expectedSales,
            'percentage': percentageOfExpected,
          },
        );

        await _firestore
            .collection('alerts')
            .doc(alert.alertId)
            .set(alert.toJson());

        debugPrint(
            '[AlertService] Low sales alert created for $periodName');
      }
    } catch (e) {
      debugPrint('[AlertService] Error generating low sales alert: $e');
      rethrow;
    }
  }

  /// Generate a system failure alert
  Future<void> generateSystemFailureAlert({
    required String componentName,
    required String errorMessage,
  }) async {
    try {
      final alert = AlertModel(
        alertId: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        type: AlertType.systemFailure,
        severity: AlertSeverity.critical,
        title: 'System Failure: $componentName',
        message: 'Critical failure detected in $componentName: $errorMessage',
        action: 'View Logs',
        timestamp: DateTime.now(),
        metadata: {
          'component': componentName,
          'error': errorMessage,
        },
      );

      await _firestore.collection('alerts').doc(alert.alertId).set(alert.toJson());
      debugPrint('[AlertService] System failure alert created for $componentName');
    } catch (e) {
      debugPrint('[AlertService] Error generating system failure alert: $e');
    }
  }

  /// Generate a security alert
  Future<void> generateSecurityAlert({
    required String securityEvent,
    required String details,
    String? userId,
  }) async {
    try {
      final alert = AlertModel(
        alertId: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        type: AlertType.securityAlert,
        severity: AlertSeverity.critical,
        title: 'Security Alert: $securityEvent',
        message: details,
        action: 'Review Audit Logs',
        timestamp: DateTime.now(),
        metadata: {
          'event': securityEvent,
          'userId': userId,
        },
      );

      await _firestore.collection('alerts').doc(alert.alertId).set(alert.toJson());
      debugPrint('[AlertService] Security alert created for $securityEvent');
    } catch (e) {
      debugPrint('[AlertService] Error generating security alert: $e');
    }
  }

  /// Resolve an alert (mark as resolved)
  Future<void> resolveAlert({
    required String alertId,
    required String resolvedBy,
  }) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update({
        'resolved': true,
        'resolvedBy': resolvedBy,
        'resolvedAt': DateTime.now().toIso8601String(),
      });

      debugPrint('[AlertService] Alert $alertId resolved');
    } catch (e) {
      debugPrint('[AlertService] Error resolving alert: $e');
      rethrow;
    }
  }

  /// Dismiss an alert (same as resolve for now)
  Future<void> dismissAlert({required String alertId}) async {
    try {
      await resolveAlert(
        alertId: alertId,
        resolvedBy: 'owner_dismiss',
      );
      debugPrint('[AlertService] Alert $alertId dismissed');
    } catch (e) {
      debugPrint('[AlertService] Error dismissing alert: $e');
      rethrow;
    }
  }

  /// Delete an alert
  Future<void> deleteAlert({required String alertId}) async {
    try {
      await _firestore.collection('alerts').doc(alertId).delete();
      debugPrint('[AlertService] Alert $alertId deleted');
    } catch (e) {
      debugPrint('[AlertService] Error deleting alert: $e');
      rethrow;
    }
  }

  /// Get alerts by type
  Future<List<AlertModel>> getAlertsByType(AlertType type) async {
    try {
      final typeString = type.toString().split('.').last;
      final snapshot = await _firestore
          .collection('alerts')
          .where('type', isEqualTo: typeString)
          .where('resolved', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AlertModel.fromJson({
                ...doc.data(),
                'alertId': doc.id,
              }))
          .toList();
    } catch (e) {
      debugPrint('[AlertService] Error fetching alerts by type: $e');
      rethrow;
    }
  }

  /// Get alerts by severity
  Future<List<AlertModel>> getAlertsBySeverity(AlertSeverity severity) async {
    try {
      final severityString = severity.toString().split('.').last;
      final snapshot = await _firestore
          .collection('alerts')
          .where('severity', isEqualTo: severityString)
          .where('resolved', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AlertModel.fromJson({
                ...doc.data(),
                'alertId': doc.id,
              }))
          .toList();
    } catch (e) {
      debugPrint('[AlertService] Error fetching alerts by severity: $e');
      rethrow;
    }
  }
}
