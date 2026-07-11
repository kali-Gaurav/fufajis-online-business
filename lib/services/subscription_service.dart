import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

class Subscription {
  final String id;
  final String customerId;
  final String shopId;
  final List<SubscriptionItem> items;
  final String frequency; // 'weekly', 'biweekly', 'monthly'
  final DateTime? nextDeliveryDate;
  final double baseAmount;
  final double discountPercentage;
  final double discountAmount;
  final double totalAmount;
  final String? paymentMethodId;
  final String status; // 'active', 'paused', 'cancelled'
  final String? cancellationReason;
  final DateTime? pausedUntil;
  final int totalOrders;
  final double totalSpent;
  final double churnRisk;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? cancelledAt;

  Subscription({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.items,
    required this.frequency,
    this.nextDeliveryDate,
    required this.baseAmount,
    required this.discountPercentage,
    required this.discountAmount,
    required this.totalAmount,
    this.paymentMethodId,
    required this.status,
    this.cancellationReason,
    this.pausedUntil,
    required this.totalOrders,
    required this.totalSpent,
    required this.churnRisk,
    required this.createdAt,
    required this.updatedAt,
    this.cancelledAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Subscription(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      shopId: json['shop_id'] ?? '',
      items: itemsJson.map((i) => SubscriptionItem.fromJson(i)).toList(),
      frequency: json['frequency'] ?? 'monthly',
      nextDeliveryDate: json['next_delivery_date'] != null ? DateTime.parse(json['next_delivery_date']) : null,
      baseAmount: (json['base_amount'] ?? 0.0).toDouble(),
      discountPercentage: (json['discount_percentage'] ?? 0.0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0.0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      paymentMethodId: json['payment_method_id'],
      status: json['status'] ?? 'active',
      cancellationReason: json['cancellation_reason'],
      pausedUntil: json['paused_until'] != null ? DateTime.parse(json['paused_until']) : null,
      totalOrders: json['total_orders'] ?? 0,
      totalSpent: (json['total_spent'] ?? 0.0).toDouble(),
      churnRisk: (json['churn_risk'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()).toList(),
      'frequency': frequency,
      'next_delivery_date': nextDeliveryDate?.toIso8601String(),
      'base_amount': baseAmount,
      'discount_percentage': discountPercentage,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'payment_method_id': paymentMethodId,
      'status': status,
      'cancellation_reason': cancellationReason,
      'paused_until': pausedUntil?.toIso8601String(),
    };
  }
}

class SubscriptionItem {
  final String productId;
  final int quantity;
  final double unitPrice;

  SubscriptionItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) {
    return SubscriptionItem(
      productId: json['product_id'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}

class SubscriptionAnalytics {
  final String id;
  final String subscriptionId;
  final double churnRiskScore;
  final int daysSinceLastOrder;
  final int orderSkipCount;
  final int paymentFailureCount;
  final double retentionScore;
  final double satisfactionScore;
  final bool retentionOfferGiven;
  final bool retentionOfferAccepted;
  final double? retentionOfferAmount;
  final double predictedLifetimeValue;
  final double predictedMonthlyValue;
  final double confidenceScore;

  SubscriptionAnalytics({
    required this.id,
    required this.subscriptionId,
    required this.churnRiskScore,
    required this.daysSinceLastOrder,
    required this.orderSkipCount,
    required this.paymentFailureCount,
    required this.retentionScore,
    required this.satisfactionScore,
    required this.retentionOfferGiven,
    required this.retentionOfferAccepted,
    this.retentionOfferAmount,
    required this.predictedLifetimeValue,
    required this.predictedMonthlyValue,
    required this.confidenceScore,
  });

  factory SubscriptionAnalytics.fromJson(Map<String, dynamic> json) {
    return SubscriptionAnalytics(
      id: json['id'] ?? '',
      subscriptionId: json['subscription_id'] ?? '',
      churnRiskScore: (json['churn_risk_score'] ?? 0.0).toDouble(),
      daysSinceLastOrder: json['days_since_last_order'] ?? 0,
      orderSkipCount: json['order_skip_count'] ?? 0,
      paymentFailureCount: json['payment_failure_count'] ?? 0,
      retentionScore: (json['retention_score'] ?? 0.0).toDouble(),
      satisfactionScore: (json['satisfaction_score'] ?? 0.0).toDouble(),
      retentionOfferGiven: json['retention_offer_given'] ?? false,
      retentionOfferAccepted: json['retention_offer_accepted'] ?? false,
      retentionOfferAmount: json['retention_offer_amount'] != null
          ? (json['retention_offer_amount']).toDouble()
          : null,
      predictedLifetimeValue: (json['predicted_lifetime_value'] ?? 0.0).toDouble(),
      predictedMonthlyValue: (json['predicted_monthly_value'] ?? 0.0).toDouble(),
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
    );
  }
}

class RetentionOffer {
  final String id;
  final String subscriptionId;
  final String offerType; // 'discount', 'free_delivery', 'extended_pause', 'gift'
  final double? discountPercentage;
  final double? discountAmount;
  final String? description;
  final String status; // 'pending', 'sent', 'accepted', 'rejected', 'expired'
  final DateTime? sentAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;

  RetentionOffer({
    required this.id,
    required this.subscriptionId,
    required this.offerType,
    this.discountPercentage,
    this.discountAmount,
    this.description,
    required this.status,
    this.sentAt,
    this.expiresAt,
    this.acceptedAt,
  });

  factory RetentionOffer.fromJson(Map<String, dynamic> json) {
    return RetentionOffer(
      id: json['id'] ?? '',
      subscriptionId: json['subscription_id'] ?? '',
      offerType: json['offer_type'] ?? 'discount',
      discountPercentage: json['discount_percentage'] != null
          ? (json['discount_percentage']).toDouble()
          : null,
      discountAmount: json['discount_amount'] != null
          ? (json['discount_amount']).toDouble()
          : null,
      description: json['description'],
      status: json['status'] ?? 'pending',
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
    );
  }
}

// ============================================================================
// SUBSCRIPTION SERVICE
// ============================================================================

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() {
    return _instance;
  }

  SubscriptionService._internal();

  final Supabase _supabase = Supabase.instance;

  // ──────────────────────────────────────────────────────────────────────
  // CRUD OPERATIONS
  // ──────────────────────────────────────────────────────────────────────

  Future<String> createSubscription({
    required String customerId,
    required String shopId,
    required List<SubscriptionItem> items,
    required String frequency,
    required double baseAmount,
    required double discountPercentage,
    String? paymentMethodId,
  }) async {
    try {
      debugPrint('[SubscriptionService] Creating subscription for customer $customerId');

      final discountAmount = baseAmount * (discountPercentage / 100);
      final totalAmount = baseAmount - discountAmount;
      final nextDeliveryDate = _calculateNextDeliveryDate(frequency);

      final response = await _supabase.client.from('subscriptions').insert({
        'customer_id': customerId,
        'shop_id': shopId,
        'items': items.map((i) => i.toJson()).toList(),
        'frequency': frequency,
        'next_delivery_date': nextDeliveryDate.toIso8601String().split('T')[0],
        'base_amount': baseAmount,
        'discount_percentage': discountPercentage,
        'discount_amount': discountAmount,
        'total_amount': totalAmount,
        'payment_method_id': paymentMethodId,
        'status': 'active',
      }).select().single();

      final subscriptionId = response['id'] as String;
      debugPrint('[SubscriptionService] Subscription created: $subscriptionId');

      return subscriptionId;
    } catch (e) {
      debugPrint('[SubscriptionService] Error creating subscription: $e');
      rethrow;
    }
  }

  Future<Subscription?> getSubscription(String subscriptionId) async {
    try {
      debugPrint('[SubscriptionService] Fetching subscription $subscriptionId');

      final response = await _supabase.client
          .from('subscriptions')
          .select()
          .eq('id', subscriptionId)
          .maybeSingle();

      if (response == null) {
        debugPrint('[SubscriptionService] Subscription not found');
        return null;
      }

      return Subscription.fromJson(response);
    } catch (e) {
      debugPrint('[SubscriptionService] Error fetching subscription: $e');
      rethrow;
    }
  }

  Future<List<Subscription>> getCustomerSubscriptions(String customerId) async {
    try {
      debugPrint('[SubscriptionService] Fetching subscriptions for customer $customerId');

      final response = await _supabase.client
          .from('subscriptions')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return response.map((s) => Subscription.fromJson(s)).toList();
    } catch (e) {
      debugPrint('[SubscriptionService] Error fetching customer subscriptions: $e');
      rethrow;
    }
  }

  Future<void> updateSubscription(
    String subscriptionId, {
    List<SubscriptionItem>? items,
    String? frequency,
    double? discountPercentage,
  }) async {
    try {
      debugPrint('[SubscriptionService] Updating subscription $subscriptionId');

      final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};

      if (items != null) {
        updates['items'] = items.map((i) => i.toJson()).toList();
      }
      if (frequency != null) {
        updates['frequency'] = frequency;
        updates['next_delivery_date'] = _calculateNextDeliveryDate(frequency).toIso8601String().split('T')[0];
      }
      if (discountPercentage != null) {
        updates['discount_percentage'] = discountPercentage;
        final sub = await getSubscription(subscriptionId);
        if (sub != null) {
          final newDiscountAmount = sub.baseAmount * (discountPercentage / 100);
          updates['discount_amount'] = newDiscountAmount;
          updates['total_amount'] = sub.baseAmount - newDiscountAmount;
        }
      }

      await _supabase.client
          .from('subscriptions')
          .update(updates)
          .eq('id', subscriptionId);

      debugPrint('[SubscriptionService] Subscription updated');
    } catch (e) {
      debugPrint('[SubscriptionService] Error updating subscription: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // SUBSCRIPTION STATE MANAGEMENT
  // ──────────────────────────────────────────────────────────────────────

  Future<void> pauseSubscription(String subscriptionId, {int pauseDays = 30}) async {
    try {
      debugPrint('[SubscriptionService] Pausing subscription $subscriptionId for $pauseDays days');

      final pausedUntil = DateTime.now().add(Duration(days: pauseDays));

      await _supabase.client.from('subscriptions').update({
        'status': 'paused',
        'paused_until': pausedUntil.toIso8601String().split('T')[0],
      }).eq('id', subscriptionId);

      await _logSubscriptionHistory(subscriptionId, 'paused', reason: 'Paused until $pausedUntil');
      debugPrint('[SubscriptionService] Subscription paused');
    } catch (e) {
      debugPrint('[SubscriptionService] Error pausing subscription: $e');
      rethrow;
    }
  }

  Future<void> resumeSubscription(String subscriptionId) async {
    try {
      debugPrint('[SubscriptionService] Resuming subscription $subscriptionId');

      await _supabase.client.from('subscriptions').update({
        'status': 'active',
        'paused_until': null,
      }).eq('id', subscriptionId);

      await _logSubscriptionHistory(subscriptionId, 'resumed');
      debugPrint('[SubscriptionService] Subscription resumed');
    } catch (e) {
      debugPrint('[SubscriptionService] Error resuming subscription: $e');
      rethrow;
    }
  }

  Future<void> cancelSubscription(String subscriptionId, String reason) async {
    try {
      debugPrint('[SubscriptionService] Cancelling subscription $subscriptionId: $reason');

      await _supabase.client.from('subscriptions').update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', subscriptionId);

      await _logSubscriptionHistory(subscriptionId, 'cancelled', reason: reason);
      debugPrint('[SubscriptionService] Subscription cancelled');
    } catch (e) {
      debugPrint('[SubscriptionService] Error cancelling subscription: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // ANALYTICS & CHURN PREDICTION
  // ──────────────────────────────────────────────────────────────────────

  Future<SubscriptionAnalytics?> getSubscriptionAnalytics(String subscriptionId) async {
    try {
      debugPrint('[SubscriptionService] Fetching analytics for $subscriptionId');

      final response = await _supabase.client
          .from('subscription_analytics')
          .select()
          .eq('subscription_id', subscriptionId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return SubscriptionAnalytics.fromJson(response);
    } catch (e) {
      debugPrint('[SubscriptionService] Error fetching analytics: $e');
      rethrow;
    }
  }

  // Get high-risk subscriptions (churn_risk > 0.7)
  Future<List<Subscription>> getHighRiskSubscriptions({int limit = 50}) async {
    try {
      debugPrint('[SubscriptionService] Fetching high-risk subscriptions');

      final response = await _supabase.client
          .from('subscriptions')
          .select()
          .eq('status', 'active')
          .gt('churn_risk', 0.7)
          .order('churn_risk', ascending: false)
          .limit(limit);

      return response.map((s) => Subscription.fromJson(s)).toList();
    } catch (e) {
      debugPrint('[SubscriptionService] Error fetching high-risk subscriptions: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // RETENTION OFFERS
  // ──────────────────────────────────────────────────────────────────────

  Future<String> createRetentionOffer({
    required String subscriptionId,
    required String offerType, // 'discount', 'free_delivery', 'extended_pause', 'gift'
    double? discountPercentage,
    String? description,
  }) async {
    try {
      debugPrint('[SubscriptionService] Creating retention offer for $subscriptionId');

      final expiresAt = DateTime.now().add(const Duration(days: 7));
      double? discountAmount;

      if (discountPercentage != null) {
        final sub = await getSubscription(subscriptionId);
        if (sub != null) {
          discountAmount = sub.baseAmount * (discountPercentage / 100);
        }
      }

      final response = await _supabase.client.from('retention_offers').insert({
        'subscription_id': subscriptionId,
        'offer_type': offerType,
        'discount_percentage': discountPercentage,
        'discount_amount': discountAmount,
        'description': description,
        'status': 'pending',
        'expires_at': expiresAt.toIso8601String(),
      }).select().single();

      final offerId = response['id'] as String;
      debugPrint('[SubscriptionService] Retention offer created: $offerId');

      return offerId;
    } catch (e) {
      debugPrint('[SubscriptionService] Error creating retention offer: $e');
      rethrow;
    }
  }

  Future<void> acceptRetentionOffer(String offerId) async {
    try {
      debugPrint('[SubscriptionService] Accepting retention offer $offerId');

      await _supabase.client.from('retention_offers').update({
        'status': 'accepted',
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('id', offerId);

      debugPrint('[SubscriptionService] Retention offer accepted');
    } catch (e) {
      debugPrint('[SubscriptionService] Error accepting retention offer: $e');
      rethrow;
    }
  }

  Future<void> rejectRetentionOffer(String offerId) async {
    try {
      debugPrint('[SubscriptionService] Rejecting retention offer $offerId');

      await _supabase.client.from('retention_offers').update({
        'status': 'rejected',
      }).eq('id', offerId);

      debugPrint('[SubscriptionService] Retention offer rejected');
    } catch (e) {
      debugPrint('[SubscriptionService] Error rejecting retention offer: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // REAL-TIME STREAMS
  // ──────────────────────────────────────────────────────────────────────

  Stream<List<Subscription>> watchCustomerSubscriptions(String customerId) {
    debugPrint('[SubscriptionService] Watching subscriptions for customer $customerId');

    return _supabase.client
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .map((subscriptions) => subscriptions.map((s) => Subscription.fromJson(s)).toList());
  }

  // ──────────────────────────────────────────────────────────────────────
  // HELPER METHODS
  // ──────────────────────────────────────────────────────────────────────

  DateTime _calculateNextDeliveryDate(String frequency) {
    final now = DateTime.now();
    switch (frequency) {
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'biweekly':
        return now.add(const Duration(days: 14));
      case 'monthly':
        return DateTime(now.year, now.month + 1, now.day);
      default:
        return now.add(const Duration(days: 30));
    }
  }

  Future<void> _logSubscriptionHistory(
    String subscriptionId,
    String action, {
    String? reason,
  }) async {
    try {
      await _supabase.client.from('subscription_history').insert({
        'subscription_id': subscriptionId,
        'action': action,
        'reason': reason,
        'performed_by': _supabase.client.auth.currentUser?.id,
      });
    } catch (e) {
      debugPrint('[SubscriptionService] Error logging subscription history: $e');
    }
  }
}
