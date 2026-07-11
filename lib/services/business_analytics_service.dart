import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_models.dart';

/// Business Analytics Service (Iteration 7)
/// Handles business intelligence and dashboard metrics
class BusinessAnalyticsService {
  static final BusinessAnalyticsService _instance =
      BusinessAnalyticsService._internal();

  factory BusinessAnalyticsService() {
    return _instance;
  }

  BusinessAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream today's analytics in real-time from Firestore
  Stream<DailyAnalytics?> streamDailyAnalytics() {
    return _firestore
        .collection('analytics')
        .doc('daily_summary')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      final data = snapshot.data() as Map<String, dynamic>;

      try {
        return DailyAnalytics(
          id: data['id'] as String? ??
              'daily_${DateTime.now().toString().split(' ')[0]}',
          date: DateTime.now(),
          totalRevenue: (data['revenue'] as num?)?.toDouble() ?? 0.0,
          totalOrders: data['orders'] as int? ?? 0,
          totalCustomers: data['customers'] as int? ?? 0,
          newCustomers: data['new_customers'] as int? ?? 0,
          returningCustomers: data['returning_customers'] as int? ?? 0,
          avgOrderValue: (data['avg_order_value'] as num?)?.toDouble() ?? 0.0,
          deliverySuccessRate:
              (data['delivery_success_rate'] as num?)?.toDouble() ?? 0.0,
          customerSatisfaction:
              (data['rating'] as num?)?.toDouble() ?? 0.0,
          peakHour: data['peak_hour'] as int?,
          peakHourOrders: data['peak_hour_orders'] as int?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } catch (e) {
        print('Error parsing daily analytics: $e');
        return null;
      }
    });
  }

  // Get revenue breakdown by category and payment method
  Future<RevenueBreakdown?> getRevenueBreakdown(DateTime date) async {
    try {
      final dateString = date.toString().split(' ')[0];

      final response = await _supabase
          .from('revenue_summary')
          .select('*, product_categories(name)')
          .eq('date', dateString)
          .order('total_revenue', ascending: false);

      if ((response as List).isEmpty) {
        return RevenueBreakdown(
          id: 'revenue_$dateString',
          date: date,
          byCategory: {},
          byPaymentMethod: {},
          timestamp: DateTime.now(),
        );
      }

      final Map<String, double> byCategory = {};
      final Map<String, double> byPaymentMethod = {};

      for (final item in response as List) {
        final categoryName =
            item['product_categories']?['name'] as String? ?? 'Other';
        final paymentMethod =
            item['payment_method'] as String? ?? 'Unknown';
        final revenue = (item['total_revenue'] as num).toDouble();

        byCategory[categoryName] =
            (byCategory[categoryName] ?? 0) + revenue;
        byPaymentMethod[paymentMethod] =
            (byPaymentMethod[paymentMethod] ?? 0) + revenue;
      }

      return RevenueBreakdown(
        id: 'revenue_$dateString',
        date: date,
        byCategory: byCategory,
        byPaymentMethod: byPaymentMethod,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Error fetching revenue breakdown: $e');
      return null;
    }
  }

  // Stream alerts in real-time from Firestore
  Stream<List<Alert>> streamAlerts() {
    return _firestore
        .collection('analytics')
        .doc('alerts')
        .collection('items')
        .where('dismissed', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return Alert(
              id: doc.id,
              type: data['type'] as String? ?? '',
              severity: data['severity'] as String? ?? 'medium',
              message: data['message'] as String? ?? '',
              affectedEntity: data['affected_entity'] as String?,
              actionUrl: data['action_url'] as String?,
              createdAt: (data['created_at'] as Timestamp).toDate(),
              dismissed: data['dismissed'] as bool? ?? false,
            );
          })
          .toList();
    });
  }

  // Dismiss an alert
  Future<void> dismissAlert(String alertId) async {
    try {
      await _firestore
          .collection('analytics')
          .doc('alerts')
          .collection('items')
          .doc(alertId)
          .update({'dismissed': true});
    } catch (e) {
      print('Error dismissing alert: $e');
      throw Exception('Failed to dismiss alert: $e');
    }
  }

  // Check if service is healthy
  Future<bool> healthCheck() async {
    try {
      final firestoreTest =
          await _firestore
          .collection('analytics')
          .doc('daily_summary')
          .get();

      final postgresTest = await _supabase
          .from('analytics_daily')
          .select()
          .limit(1);

      return firestoreTest.exists && (postgresTest as List).isNotEmpty;
    } catch (e) {
      print('Business analytics service health check failed: $e');
      return false;
    }
  }
}
