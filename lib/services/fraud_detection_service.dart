import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/order_model.dart';
import '../models/payment_method.dart';
import 'alert_service.dart';
import '../constants/order_status.dart';
import '../utils/monetary_value.dart';

/// Fraud Detection Service
///
/// Monitors transactions, refunds, cancellations, and payment patterns to detect anomalies.
/// Raises operational alerts in Postgres and Firestore on critical risk detection.
class FraudDetectionService {
  static final FraudDetectionService _instance = FraudDetectionService._internal();
  factory FraudDetectionService() => _instance;
  FraudDetectionService._internal();

  SupabaseClient? _customClient;
  SupabaseClient get _client => _customClient ?? SupabaseConfig.client;
  set client(SupabaseClient c) => _customClient = c;

  AlertService? _customAlertService;
  AlertService get _alertService => _customAlertService ?? AlertService();
  set alertService(AlertService s) => _customAlertService = s;

  /// Analyzes an order for fraudulent parameters and returns a risk score between 0.0 and 1.0.
  Future<double> analyzeOrderRisk(OrderModel order) async {
    try {
      debugPrint(
        '[FraudDetection] Analyzing fraud risk for order: #${order.orderNumber} (ID: ${order.id})',
      );

      double riskScore = 0.0;
      final List<String> reasons = [];

      // 1. Geolocation Mismatch screening (GeoPoint coordinates check)
      final geo = order.liveLocation;
      if (geo != null) {
        // Compare with branch coordinate boundaries (e.g. Jaipur central coords 26.9124, 75.7873)
        final double latDiff = (geo.latitude - 26.9124).abs();
        final double lngDiff = (geo.longitude - 75.7873).abs();
        if (latDiff > 0.45 || lngDiff > 0.45) {
          riskScore += 0.35;
          reasons.add('Customer delivery coordinates are far outside branch boundaries.');
        }
      }

      // 2. High Value First Order check
      // Query historical orders for this customer from Postgres
      final prevOrdersResponse = await _client
          .from('orders')
          .select('order_id')
          .eq('user_id', order.customerId)
          .limit(5);

      final List<dynamic> prevOrders = prevOrdersResponse as List<dynamic>;
      if (prevOrders.isEmpty && order.totalAmount > MonetaryValue(5000)) {
        riskScore += 0.25;
        reasons.add('First-time order exceeds ₹5,000 threshold.');
      }

      // 3. Payment Method anomaly (e.g. high-value COD orders)
      if (order.paymentMethod == PaymentMethod.cod && order.totalAmount > MonetaryValue(3000)) {
        riskScore += 0.20;
        reasons.add('High value cash-on-delivery order.');
      }

      // 4. Mismatch between payment ledger status and local order payment status
      if (order.paymentStatus == 'failed' && order.status != OrderStatus.cancelled) {
        riskScore += 0.40;
        reasons.add('Order state marked active but transactional payment status is failed.');
      }

      riskScore = riskScore.clamp(0.0, 1.0);

      // Log results to Postgres ai_alerts if risk is critical (> 0.8) or high (> 0.6)
      if (riskScore >= 0.7) {
        final alertId = 'fraud_${order.id}';
        final severity = riskScore >= 0.85 ? 'critical' : 'high';
        final title = 'Potential Fraud Detected: Order #${order.orderNumber}';
        final desc = 'Risk Score: ${riskScore.toStringAsFixed(2)}. Reasons: ${reasons.join(" ")}';

        // Write to Postgres physical analytics table
        await _client.from('ai_alerts').upsert({
          'alert_id': alertId,
          'alert_type': 'fraud',
          'severity': severity,
          'title': title,
          'description': desc,
          'resolved': false,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Write to Firestore active alerts (this propagates to NOC dashboards in real-time)
        await _alertService.generateSecurityAlert(
          securityEvent: 'POTENTIAL_FRAUD',
          details: 'Order #${order.orderNumber} flagged as $severity risk ($riskScore). $desc',
          userId: order.customerId,
        );

        debugPrint('[FraudDetection] Alert generated: $title');
      }

      debugPrint('[FraudDetection] Risk analysis complete: Risk score: $riskScore');
      return riskScore;
    } catch (e) {
      debugPrint('[FraudDetection] Error analyzing order risk: $e');
      return 0.0;
    }
  }

  /// Evaluates rider performance for cancellation and refund anomalies
  Future<void> monitorRiderAnomalies(String riderId) async {
    try {
      debugPrint('[FraudDetection] Monitoring delivery anomalies for rider: $riderId');

      // Query rider shifts and delivery exceptions for this rider in last 7 days
      final exceptionsResponse = await _client
          .from('delivery_exceptions')
          .select('id, type')
          .eq('rider_id', riderId);

      final List<dynamic> exceptions = exceptionsResponse as List<dynamic>;
      int totalExceptions = exceptions.length;
      int paymentFailures = exceptions.where((ex) => ex['type'] == 'payment_failure').length;

      if (totalExceptions > 5 || paymentFailures > 2) {
        final alertId = 'rider_anomaly_$riderId';
        final desc =
            'Rider $riderId flagged with $totalExceptions delivery exceptions ($paymentFailures payment failures) in last 7 days.';

        await _client.from('ai_alerts').upsert({
          'alert_id': alertId,
          'alert_type': 'anomaly',
          'severity': 'high',
          'title': 'Rider Exception Threshold Breached',
          'description': desc,
          'resolved': false,
          'created_at': DateTime.now().toIso8601String(),
        });

        await _alertService.generateSecurityAlert(
          securityEvent: 'RIDER_DELIVERY_EXCEPTION',
          details: desc,
          userId: riderId,
        );
      }
    } catch (e) {
      debugPrint('[FraudDetection] Error monitoring rider anomalies: $e');
    }
  }
}
