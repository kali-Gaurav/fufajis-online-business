import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';

// Data Models

class SupplierProfile {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? gstNumber;
  final String status; // pending, approved, rejected, suspended
  final bool isVerified;
  final double rating; // 0-5
  final int totalOrders;
  final int completedOrders;
  final double onTimeDeliveryRate;
  final double qualityScore;
  final double responseRate;
  final bool autoOrderEnabled;
  final String? preferredDeliveryDay;
  final double minOrderValue;
  final double totalRevenue;
  final double totalPaid;
  final double totalPending;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstNumber,
    required this.status,
    required this.isVerified,
    required this.rating,
    required this.totalOrders,
    required this.completedOrders,
    required this.onTimeDeliveryRate,
    required this.qualityScore,
    required this.responseRate,
    required this.autoOrderEnabled,
    this.preferredDeliveryDay,
    required this.minOrderValue,
    required this.totalRevenue,
    required this.totalPaid,
    required this.totalPending,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierProfile.fromJson(Map<String, dynamic> json) {
    return SupplierProfile(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'],
      city: json['city'],
      state: json['state'],
      pincode: json['pincode'],
      gstNumber: json['gst_number'],
      status: json['status'] ?? 'pending',
      isVerified: json['is_verified'] ?? false,
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalOrders: json['total_orders'] ?? 0,
      completedOrders: json['completed_orders'] ?? 0,
      onTimeDeliveryRate: (json['on_time_delivery_rate'] ?? 0.0).toDouble(),
      qualityScore: (json['quality_score'] ?? 0.0).toDouble(),
      responseRate: (json['response_rate'] ?? 0.0).toDouble(),
      autoOrderEnabled: json['auto_order_enabled'] ?? false,
      preferredDeliveryDay: json['preferred_delivery_day'],
      minOrderValue: (json['min_order_value'] ?? 0.0).toDouble(),
      totalRevenue: (json['total_revenue'] ?? 0.0).toDouble(),
      totalPaid: (json['total_paid'] ?? 0.0).toDouble(),
      totalPending: (json['total_pending'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class SupplierOrder {
  final String id;
  final String poNumber;
  final String supplierId;
  final String shopId;
  final List<OrderItem> items;
  final double totalAmount;
  final double taxAmount;
  final double discountAmount;
  final double finalAmount;
  final DateTime expectedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final String? deliveryNotes;
  final String status; // draft, confirmed, dispatched, received, cancelled
  final String? createdBy;
  final String? confirmedBy;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? receivedAt;
  final DateTime? cancelledAt;
  final DateTime updatedAt;

  SupplierOrder({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.shopId,
    required this.items,
    required this.totalAmount,
    required this.taxAmount,
    required this.discountAmount,
    required this.finalAmount,
    required this.expectedDeliveryDate,
    this.actualDeliveryDate,
    this.deliveryNotes,
    required this.status,
    this.createdBy,
    this.confirmedBy,
    required this.createdAt,
    this.confirmedAt,
    this.receivedAt,
    this.cancelledAt,
    required this.updatedAt,
  });

  factory SupplierOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return SupplierOrder(
      id: json['id'] ?? '',
      poNumber: json['po_number'] ?? '',
      supplierId: json['supplier_id'] ?? '',
      shopId: json['shop_id'] ?? '',
      items: itemsJson.map((item) => OrderItem.fromJson(item)).toList(),
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      taxAmount: (json['tax_amount'] ?? 0.0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0.0).toDouble(),
      finalAmount: (json['final_amount'] ?? 0.0).toDouble(),
      expectedDeliveryDate: DateTime.parse(json['expected_delivery_date'] ?? DateTime.now().toIso8601String()),
      actualDeliveryDate: json['actual_delivery_date'] != null ? DateTime.parse(json['actual_delivery_date']) : null,
      deliveryNotes: json['delivery_notes'],
      status: json['status'] ?? 'draft',
      createdBy: json['created_by'],
      confirmedBy: json['confirmed_by'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at']) : null,
      receivedAt: json['received_at'] != null ? DateTime.parse(json['received_at']) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class OrderItem {
  final String productId;
  final int quantity;
  final double unitPrice;
  final double amount;

  OrderItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'amount': amount,
    };
  }
}

class SupplierPayment {
  final String id;
  final String supplierId;
  final String? supplierOrderId;
  final double amount;
  final String currency;
  final String? description;
  final String? razorpayPaymentId;
  final String? razorpayTransferId;
  final String? razorpaySettlementId;
  final String status; // pending, processing, success, failed
  final String? failureReason;
  final DateTime initiatedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierPayment({
    required this.id,
    required this.supplierId,
    this.supplierOrderId,
    required this.amount,
    required this.currency,
    this.description,
    this.razorpayPaymentId,
    this.razorpayTransferId,
    this.razorpaySettlementId,
    required this.status,
    this.failureReason,
    required this.initiatedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierPayment.fromJson(Map<String, dynamic> json) {
    return SupplierPayment(
      id: json['id'] ?? '',
      supplierId: json['supplier_id'] ?? '',
      supplierOrderId: json['supplier_order_id'],
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'INR',
      description: json['description'],
      razorpayPaymentId: json['razorpay_payment_id'],
      razorpayTransferId: json['razorpay_transfer_id'],
      razorpaySettlementId: json['razorpay_settlement_id'],
      status: json['status'] ?? 'pending',
      failureReason: json['failure_reason'],
      initiatedAt: DateTime.parse(json['initiated_at'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class SupplierMetrics {
  final String id;
  final String supplierId;
  final String shopId;
  final DateTime metricMonth;
  final int totalOrders;
  final int completedOrders;
  final int onTimeOrders;
  final int lateOrders;
  final int cancelledOrders;
  final int damagedItems;
  final int returnedItems;
  final int qualityIssues;
  final double onTimeRate;
  final double qualityScore;
  final double reliabilityScore;
  final double totalAmount;
  final double totalPaid;

  SupplierMetrics({
    required this.id,
    required this.supplierId,
    required this.shopId,
    required this.metricMonth,
    required this.totalOrders,
    required this.completedOrders,
    required this.onTimeOrders,
    required this.lateOrders,
    required this.cancelledOrders,
    required this.damagedItems,
    required this.returnedItems,
    required this.qualityIssues,
    required this.onTimeRate,
    required this.qualityScore,
    required this.reliabilityScore,
    required this.totalAmount,
    required this.totalPaid,
  });

  factory SupplierMetrics.fromJson(Map<String, dynamic> json) {
    return SupplierMetrics(
      id: json['id'] ?? '',
      supplierId: json['supplier_id'] ?? '',
      shopId: json['shop_id'] ?? '',
      metricMonth: DateTime.parse(json['metric_month'] ?? DateTime.now().toIso8601String()),
      totalOrders: json['total_orders'] ?? 0,
      completedOrders: json['completed_orders'] ?? 0,
      onTimeOrders: json['on_time_orders'] ?? 0,
      lateOrders: json['late_orders'] ?? 0,
      cancelledOrders: json['cancelled_orders'] ?? 0,
      damagedItems: json['damaged_items'] ?? 0,
      returnedItems: json['returned_items'] ?? 0,
      qualityIssues: json['quality_issues'] ?? 0,
      onTimeRate: (json['on_time_rate'] ?? 0.0).toDouble(),
      qualityScore: (json['quality_score'] ?? 0.0).toDouble(),
      reliabilityScore: (json['reliability_score'] ?? 0.0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      totalPaid: (json['total_paid'] ?? 0.0).toDouble(),
    );
  }
}

// Supplier Service

class SupplierService {
  static final SupplierService _instance = SupplierService._internal();

  factory SupplierService() {
    return _instance;
  }

  SupplierService._internal();

  final Supabase _supabase = Supabase.instance;

  // Get current supplier's profile
  Future<SupplierProfile?> getMySupplierProfile() async {
    try {
      debugPrint('[SupplierService] Fetching current supplier profile');
      final response = await _supabase.client
          .from('suppliers')
          .select()
          .eq('user_id', _supabase.client.auth.currentUser?.id ?? '')
          .maybeSingle();

      if (response == null) {
        debugPrint('[SupplierService] No supplier profile found');
        return null;
      }

      debugPrint('[SupplierService] Supplier profile loaded');
      return SupplierProfile.fromJson(response);
    } catch (e) {
      debugPrint('[SupplierService] Error fetching supplier profile: $e');
      rethrow;
    }
  }

  // Get supplier dashboard data
  Future<Map<String, dynamic>> getSupplierDashboard(String supplierId) async {
    try {
      debugPrint('[SupplierService] Fetching dashboard for supplier $supplierId');

      // Fetch profile
      final profileResponse = await _supabase.client
          .from('suppliers')
          .select()
          .eq('id', supplierId)
          .maybeSingle();

      // Fetch pending orders count
      final ordersResponse = await _supabase.client
          .from('supplier_orders')
          .select()
          .eq('supplier_id', supplierId)
          .in_('status', ['confirmed', 'processing'])
          .count();

      // Fetch this month's metrics
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final metricsResponse = await _supabase.client
          .from('supplier_metrics')
          .select()
          .eq('supplier_id', supplierId)
          .eq('metric_month', firstDayOfMonth.toIso8601String().split('T')[0])
          .maybeSingle();

      // Fetch pending payments
      final paymentsResponse = await _supabase.client
          .from('supplier_payments')
          .select()
          .eq('supplier_id', supplierId)
          .in_('status', ['pending', 'processing'])
          .order('created_at', ascending: false);

      debugPrint('[SupplierService] Dashboard data loaded');

      return {
        'profile': profileResponse != null ? SupplierProfile.fromJson(profileResponse) : null,
        'pendingOrders': ordersResponse.count,
        'metrics': metricsResponse != null ? SupplierMetrics.fromJson(metricsResponse) : null,
        'pendingPayments': paymentsResponse.map((p) => SupplierPayment.fromJson(p)).toList(),
      };
    } catch (e) {
      debugPrint('[SupplierService] Error fetching dashboard: $e');
      rethrow;
    }
  }

  // Get auto-order suggestions for a supplier
  Future<List<Map<String, dynamic>>> getAutoOrderSuggestions(String supplierId) async {
    try {
      debugPrint('[SupplierService] Fetching auto-order suggestions for $supplierId');

      final response = await ApiClient.instance.get(
        '/suppliers/$supplierId/auto-order-suggestions',
      );

      debugPrint('[SupplierService] Auto-order suggestions loaded');
      return List<Map<String, dynamic>>.from(response.data['suggestions'] ?? []);
    } catch (e) {
      debugPrint('[SupplierService] Error fetching auto-order suggestions: $e');
      return [];
    }
  }

  // Accept a supplier order
  Future<void> acceptSupplierOrder(String orderId) async {
    try {
      debugPrint('[SupplierService] Accepting order $orderId');

      await _supabase.client
          .from('supplier_orders')
          .update({'status': 'confirmed'})
          .eq('id', orderId);

      debugPrint('[SupplierService] Order accepted');
    } catch (e) {
      debugPrint('[SupplierService] Error accepting order: $e');
      rethrow;
    }
  }

  // Reject a supplier order
  Future<void> rejectSupplierOrder(String orderId, String reason) async {
    try {
      debugPrint('[SupplierService] Rejecting order $orderId: $reason');

      await _supabase.client
          .from('supplier_orders')
          .update({
            'status': 'cancelled',
            'delivery_notes': 'Rejected by supplier: $reason',
          })
          .eq('id', orderId);

      debugPrint('[SupplierService] Order rejected');
    } catch (e) {
      debugPrint('[SupplierService] Error rejecting order: $e');
      rethrow;
    }
  }

  // Mark order as dispatched
  Future<void> markOrderDispatched(String orderId) async {
    try {
      debugPrint('[SupplierService] Marking order $orderId as dispatched');

      await _supabase.client
          .from('supplier_orders')
          .update({'status': 'dispatched'})
          .eq('id', orderId);

      debugPrint('[SupplierService] Order marked dispatched');
    } catch (e) {
      debugPrint('[SupplierService] Error marking order dispatched: $e');
      rethrow;
    }
  }

  // Request payment from owner
  Future<String> requestPayment({
    required String supplierId,
    required String? orderId,
    required double amount,
    required String description,
  }) async {
    try {
      debugPrint('[SupplierService] Requesting payment: amount=$amount, orderId=$orderId');

      final response = await ApiClient.instance.post(
        '/suppliers/$supplierId/request-payment',
        {
          'supplier_order_id': orderId,
          'amount': amount,
          'description': description,
        },
      );

      final paymentId = response.data['payment_id'] ?? '';
      debugPrint('[SupplierService] Payment requested: $paymentId');
      return paymentId;
    } catch (e) {
      debugPrint('[SupplierService] Error requesting payment: $e');
      rethrow;
    }
  }

  // Get payment history
  Future<List<SupplierPayment>> getPaymentHistory(String supplierId) async {
    try {
      debugPrint('[SupplierService] Fetching payment history for $supplierId');

      final response = await _supabase.client
          .from('supplier_payments')
          .select()
          .eq('supplier_id', supplierId)
          .order('created_at', ascending: false);

      final payments = response.map((p) => SupplierPayment.fromJson(p)).toList();
      debugPrint('[SupplierService] Payment history loaded: ${payments.length} payments');
      return payments;
    } catch (e) {
      debugPrint('[SupplierService] Error fetching payment history: $e');
      rethrow;
    }
  }

  // Get supplier metrics
  Future<SupplierMetrics?> getSupplierMetrics(String supplierId) async {
    try {
      debugPrint('[SupplierService] Fetching metrics for $supplierId');

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final response = await _supabase.client
          .from('supplier_metrics')
          .select()
          .eq('supplier_id', supplierId)
          .eq('metric_month', firstDayOfMonth.toIso8601String().split('T')[0])
          .maybeSingle();

      if (response == null) {
        debugPrint('[SupplierService] No metrics found for current month');
        return null;
      }

      debugPrint('[SupplierService] Metrics loaded');
      return SupplierMetrics.fromJson(response);
    } catch (e) {
      debugPrint('[SupplierService] Error fetching metrics: $e');
      rethrow;
    }
  }

  // Create/register a new supplier (admin/owner only)
  Future<SupplierProfile?> createSupplier({
    required String name,
    required String email,
    required String phone,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstNumber,
    String? contactPerson,
    String? paymentTerms,
  }) async {
    try {
      debugPrint('[SupplierService] Creating new supplier: $name');

      // Create the supplier profile in Supabase
      final response = await _supabase.client
          .from('suppliers')
          .insert({
            'name': name,
            'email': email,
            'phone': phone,
            'address': address,
            'city': city,
            'state': state,
            'pincode': pincode,
            'gst_number': gstNumber,
            'contact_person': contactPerson,
            'payment_terms': paymentTerms,
            'status': 'pending', // Requires approval
            'is_verified': false,
            'rating': 0.0,
            'total_orders': 0,
            'completed_orders': 0,
            'on_time_delivery_rate': 0.0,
            'quality_score': 0.0,
            'response_rate': 0.0,
            'auto_order_enabled': false,
            'min_order_value': 0.0,
            'total_revenue': 0.0,
            'total_paid': 0.0,
            'total_pending': 0.0,
          })
          .select()
          .single();

      debugPrint('[SupplierService] Supplier created successfully');

      // TODO: Send invitation email/WhatsApp to supplier
      // await _sendSupplierInvitation(email, name);

      return SupplierProfile.fromJson(response);
    } catch (e) {
      debugPrint('[SupplierService] Error creating supplier: $e');
      rethrow;
    }
  }

  // Real-time stream of supplier orders
  Stream<List<SupplierOrder>> watchSupplierOrders(String supplierId) {
    debugPrint('[SupplierService] Watching orders for supplier $supplierId');

    return _supabase.client
        .from('supplier_orders')
        .stream(primaryKey: ['id'])
        .eq('supplier_id', supplierId)
        .order('created_at', ascending: false)
        .map((orders) => orders.map((o) => SupplierOrder.fromJson(o)).toList());
  }

  // Real-time stream of pending payments
  Stream<List<SupplierPayment>> watchPendingPayments(String supplierId) {
    debugPrint('[SupplierService] Watching pending payments for supplier $supplierId');

    return _supabase.client
        .from('supplier_payments')
        .stream(primaryKey: ['id'])
        .eq('supplier_id', supplierId)
        .in_('status', ['pending', 'processing'])
        .order('created_at', ascending: false)
        .map((payments) => payments.map((p) => SupplierPayment.fromJson(p)).toList());
  }
}
